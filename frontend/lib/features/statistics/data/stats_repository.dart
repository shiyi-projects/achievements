import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_repository.g.dart';

class StatsRepository {
  StatsRepository(this._db, this._userId);

  final AppDatabase _db;
  final String _userId;

  // ─── Overview ───────────────────────────────────────────────────────────────

  Future<int> totalCompletedTasks() async {
    final q = _db.select(_db.tasks)
      ..where(
        (t) =>
            t.userId.equals(_userId) &
            t.completedAt.isNotNull() &
            t.deletedAt.isNull(),
      );
    final rows = await q.get();
    return rows.length;
  }

  Future<int> todayCompletedTasks() async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));
    final q = _db.select(_db.tasks)
      ..where(
        (t) =>
            t.userId.equals(_userId) &
            t.completedAt.isBetweenValues(start, end) &
            t.deletedAt.isNull(),
      );
    return (await q.get()).length;
  }

  Future<int> streakDays() async {
    final rows = await _db
        .customSelect(
          "SELECT DISTINCT date(completed_at, 'localtime') AS day "
          'FROM tasks '
          'WHERE user_id = ? AND completed_at IS NOT NULL AND deleted_at IS NULL '
          'ORDER BY day DESC',
          variables: [Variable.withString(_userId)],
        )
        .get();
    if (rows.isEmpty) return 0;

    final today = _dateOnly(DateTime.now());
    var streak = 0;
    var cursor = today;
    for (final row in rows) {
      final dayStr = row.read<String>('day');
      final d = DateTime.parse(dayStr);
      if (d.isAtSameMomentAs(cursor) ||
          d.isAtSameMomentAs(cursor.subtract(const Duration(days: 1)))) {
        if (d.isBefore(cursor)) cursor = d;
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<int> totalFocusMinutes() async {
    final rows =
        await (_db.select(_db.focusSessions)..where(
              (s) => s.userId.equals(_userId) & s.durationSeconds.isNotNull(),
            ))
            .get();
    final totalSeconds = rows.fold<int>(
      0,
      (sum, r) => sum + (r.durationSeconds ?? 0),
    );
    return totalSeconds ~/ 60;
  }

  // ─── Heatmap (last N days) ──────────────────────────────────────────────────

  Future<Map<String, int>> completionHeatmap({int days = 365}) async {
    final since = _startOfToday().subtract(Duration(days: days - 1));
    final rows = await _db
        .customSelect(
          "SELECT date(completed_at, 'localtime') AS day, COUNT(*) AS cnt "
          'FROM tasks '
          'WHERE user_id = ? AND completed_at >= ? '
          'AND completed_at IS NOT NULL AND deleted_at IS NULL '
          'GROUP BY day',
          variables: [
            Variable.withString(_userId),
            Variable.withDateTime(since),
          ],
        )
        .get();
    return {for (final r in rows) r.read<String>('day'): r.read<int>('cnt')};
  }

  // ─── Focus stats (last N days) ──────────────────────────────────────────────

  Future<List<({String date, int sessions, int minutes})>> focusStats({
    int days = 30,
  }) async {
    final since = _startOfToday().subtract(Duration(days: days - 1));
    final rows = await _db
        .customSelect(
          "SELECT date(started_at, 'localtime') AS day, "
          'COUNT(*) AS sessions, '
          'COALESCE(SUM(duration_seconds), 0) AS total_secs '
          'FROM focus_sessions '
          'WHERE user_id = ? AND started_at >= ? AND duration_seconds IS NOT NULL '
          'GROUP BY day ORDER BY day',
          variables: [
            Variable.withString(_userId),
            Variable.withDateTime(since),
          ],
        )
        .get();
    return [
      for (final r in rows)
        (
          date: r.read<String>('day'),
          sessions: r.read<int>('sessions'),
          minutes: r.read<int>('total_secs') ~/ 60,
        ),
    ];
  }

  // ─── Completion trends (last N days) ────────────────────────────────────────

  Future<List<({String date, int completed, int created})>> completionTrends({
    int days = 30,
  }) async {
    final since = _startOfToday().subtract(Duration(days: days - 1));

    final completedRows = await _db
        .customSelect(
          "SELECT date(completed_at, 'localtime') AS day, COUNT(*) AS cnt "
          'FROM tasks '
          'WHERE user_id = ? AND completed_at >= ? '
          'AND completed_at IS NOT NULL AND deleted_at IS NULL '
          'GROUP BY day',
          variables: [
            Variable.withString(_userId),
            Variable.withDateTime(since),
          ],
        )
        .get();
    final completedByDay = {
      for (final r in completedRows) r.read<String>('day'): r.read<int>('cnt'),
    };

    final createdRows = await _db
        .customSelect(
          "SELECT date(created_at, 'localtime') AS day, COUNT(*) AS cnt "
          'FROM tasks '
          'WHERE user_id = ? AND created_at >= ? AND deleted_at IS NULL '
          'GROUP BY day',
          variables: [
            Variable.withString(_userId),
            Variable.withDateTime(since),
          ],
        )
        .get();
    final createdByDay = {
      for (final r in createdRows) r.read<String>('day'): r.read<int>('cnt'),
    };

    return [
      for (var i = 0; i < days; i++)
        () {
          final d = since.add(Duration(days: i));
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          return (
            date: key,
            completed: completedByDay[key] ?? 0,
            created: createdByDay[key] ?? 0,
          );
        }(),
    ];
  }

  // ─── Achievement metrics ────────────────────────────────────────────────────

  Future<int> completedFocusSessions() async {
    return (await (_db.select(_db.focusSessions)..where(
              (s) => s.userId.equals(_userId) & s.completed.equals(true),
            ))
            .get())
        .length;
  }

  Future<int> todayFocusMinutes() async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));
    final rows =
        await (_db.select(_db.focusSessions)..where(
              (s) =>
                  s.userId.equals(_userId) &
                  s.startedAt.isBetweenValues(start, end) &
                  s.durationSeconds.isNotNull(),
            ))
            .get();
    final totalSecs = rows.fold<int>(0, (s, r) => s + (r.durationSeconds ?? 0));
    return totalSecs ~/ 60;
  }

  // ─── Achievement: daily task max ─────────────────────────────────────────────

  /// Returns the maximum number of tasks completed in a single day (ever).
  Future<int> maxDailyCompletedTasks() async {
    final rows = await _db
        .customSelect(
          'SELECT COUNT(*) AS cnt '
          'FROM tasks '
          'WHERE user_id = ? AND completed_at IS NOT NULL AND deleted_at IS NULL '
          "GROUP BY date(completed_at, 'localtime') "
          'ORDER BY cnt DESC LIMIT 1',
          variables: [Variable.withString(_userId)],
        )
        .get();
    if (rows.isEmpty) return 0;
    return rows.first.read<int>('cnt');
  }

  /// Whether any task was ever completed before 07:00 local time.
  Future<bool> hasEarlyCompletion() async {
    final rows = await _db
        .customSelect(
          'SELECT 1 FROM tasks '
          'WHERE user_id = ? AND completed_at IS NOT NULL AND deleted_at IS NULL '
          "AND time(completed_at, 'localtime') < '07:00:00' "
          'LIMIT 1',
          variables: [Variable.withString(_userId)],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Whether any task was ever completed at or after 23:00 local time.
  Future<bool> hasLateCompletion() async {
    final rows = await _db
        .customSelect(
          'SELECT 1 FROM tasks '
          'WHERE user_id = ? AND completed_at IS NOT NULL AND deleted_at IS NULL '
          "AND time(completed_at, 'localtime') >= '23:00:00' "
          'LIMIT 1',
          variables: [Variable.withString(_userId)],
        )
        .get();
    return rows.isNotEmpty;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}

@Riverpod(keepAlive: true)
StatsRepository statsRepository(Ref ref) => StatsRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(currentUserIdProvider),
);
