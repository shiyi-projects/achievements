import 'package:achievements/core/constants.dart';
import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'focus_session_repository.g.dart';

class FocusSessionRepository {
  FocusSessionRepository(this._db);

  final AppDatabase _db;

  /// 保存一次专注会话。返回生成的 id。
  Future<String> save({
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required String mode,
    required bool completed,
    String? taskId,
  }) async {
    final id = newId();
    await _db.into(_db.focusSessions).insert(
      FocusSessionsCompanion.insert(
        id: id,
        userId: kLocalUserId,
        taskId: Value(taskId),
        startedAt: startedAt,
        endedAt: Value(endedAt),
        durationSeconds: Value(durationSeconds),
        mode: Value(mode),
        completed: Value(completed),
      ),
    );
    return id;
  }

  /// 今日累计专注时长(秒)。
  Future<int> todayTotalSeconds() async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.focusSessions)
          ..where(
            (s) =>
                s.startedAt.isBetweenValues(start, end) &
                s.durationSeconds.isNotNull(),
          ))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + (r.durationSeconds ?? 0));
  }

  /// 最近 [limit] 条会话,按开始时间倒序。
  Stream<List<FocusSession>> watchRecent({int limit = 10}) {
    return (_db.select(_db.focusSessions)
          ..orderBy([
            (s) => OrderingTerm(
              expression: s.startedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .watch();
  }

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 今日完成的番茄数（completed = true 的会话条数）。
  Future<int> todayCompletedCount() async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.focusSessions)
          ..where(
            (s) =>
                s.startedAt.isBetweenValues(start, end) &
                s.completed.equals(true),
          ))
        .get();
    return rows.length;
  }

  /// 今日最长单次专注时长（秒）。无记录时返回 0。
  Future<int> todayLongestSession() async {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.focusSessions)
          ..where(
            (s) =>
                s.startedAt.isBetweenValues(start, end) &
                s.durationSeconds.isNotNull(),
          ))
        .get();
    if (rows.isEmpty) return 0;
    return rows
        .map((r) => r.durationSeconds ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }

  /// 流式监听今日会话列表，按开始时间倒序。
  Stream<List<FocusSession>> watchTodaySessions() {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.focusSessions)
          ..where((s) => s.startedAt.isBetweenValues(start, end))
          ..orderBy([
            (s) => OrderingTerm(
                  expression: s.startedAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }
}

@Riverpod(keepAlive: true)
FocusSessionRepository focusSessionRepository(Ref ref) {
  return FocusSessionRepository(ref.watch(appDatabaseProvider));
}
