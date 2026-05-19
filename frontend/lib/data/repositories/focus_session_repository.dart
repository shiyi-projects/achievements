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
}

@Riverpod(keepAlive: true)
FocusSessionRepository focusSessionRepository(Ref ref) {
  return FocusSessionRepository(ref.watch(appDatabaseProvider));
}
