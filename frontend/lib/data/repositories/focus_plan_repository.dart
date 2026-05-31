import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'focus_plan_repository.g.dart';

class FocusPlanRepository {
  FocusPlanRepository(this._db, this._userId);

  final AppDatabase _db;
  final String _userId;

  /// 流式监听某日的所有计划，按 sortOrder 排序。
  Stream<List<FocusPlan>> watchPlansForDate(DateTime date) {
    final dayStart = _startOfDay(date);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final query =
        _db.select(_db.focusPlans).join([
            innerJoin(_db.tasks, _db.tasks.id.equalsExp(_db.focusPlans.taskId)),
          ])
          ..where(
            _db.tasks.userId.equals(_userId) &
                _db.focusPlans.date.isBetweenValues(dayStart, dayEnd),
          )
          ..orderBy([OrderingTerm(expression: _db.focusPlans.sortOrder)]);
    return query.map((row) => row.readTable(_db.focusPlans)).watch();
  }

  /// 获取今日所有计划。
  Stream<List<FocusPlan>> watchTodayPlans() =>
      watchPlansForDate(DateTime.now());

  /// 获取近 N 天内的过期未完成计划（date < today 且 actual < planned）。
  Stream<List<FocusPlan>> watchOverduePlans({int lookbackDays = 7}) {
    final today = _startOfDay(DateTime.now());
    final cutoff = today.subtract(Duration(days: lookbackDays));
    final query =
        _db.select(_db.focusPlans).join([
            innerJoin(_db.tasks, _db.tasks.id.equalsExp(_db.focusPlans.taskId)),
          ])
          ..where(
            _db.tasks.userId.equals(_userId) &
                _db.focusPlans.date.isBiggerOrEqualValue(cutoff) &
                _db.focusPlans.date.isSmallerThanValue(today) &
                _db.focusPlans.actualSeconds.isSmallerThan(
                  _db.focusPlans.plannedMinutes * const Constant(60),
                ),
          )
          ..orderBy([
            OrderingTerm(
              expression: _db.focusPlans.date,
              mode: OrderingMode.desc,
            ),
          ]);
    return query.map((row) => row.readTable(_db.focusPlans)).watch();
  }

  /// 创建或更新计划（同一 taskId + date 唯一）。
  Future<String> upsertPlan({
    required String taskId,
    required DateTime date,
    required int plannedMinutes,
    int? sortOrder,
  }) async {
    if (!await _ownsTask(taskId)) return '';
    final dayStart = _startOfDay(date);

    // 查找是否已存在
    final existing =
        await (_db.select(_db.focusPlans)
              ..where((p) => p.taskId.equals(taskId) & p.date.equals(dayStart))
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      await (_db.update(
        _db.focusPlans,
      )..where((p) => p.id.equals(existing.id))).write(
        FocusPlansCompanion(
          plannedMinutes: Value(plannedMinutes),
          sortOrder: sortOrder != null
              ? Value(sortOrder)
              : const Value.absent(),
        ),
      );
      return existing.id;
    }

    final id = newId();
    // 获取当日最大 sortOrder
    final maxSort = sortOrder ?? await _maxSortOrderForDate(dayStart) + 1;

    await _db
        .into(_db.focusPlans)
        .insert(
          FocusPlansCompanion.insert(
            id: id,
            taskId: taskId,
            date: dayStart,
            plannedMinutes: plannedMinutes,
            sortOrder: Value(maxSort),
          ),
        );
    return id;
  }

  /// 累加实际完成时长（秒）。
  Future<void> addActualSeconds(String planId, int seconds) async {
    final plan = await _planIfOwned(planId);
    if (plan == null) return;

    await (_db.update(_db.focusPlans)..where((p) => p.id.equals(planId))).write(
      FocusPlansCompanion(actualSeconds: Value(plan.actualSeconds + seconds)),
    );
  }

  /// 根据 taskId 和 date 累加实际时长（秒）。找不到计划则忽略。
  Future<void> addActualSecondsByTaskDate(
    String taskId,
    DateTime date,
    int seconds,
  ) async {
    if (!await _ownsTask(taskId)) return;
    final dayStart = _startOfDay(date);
    final plan =
        await (_db.select(_db.focusPlans)
              ..where((p) => p.taskId.equals(taskId) & p.date.equals(dayStart))
              ..limit(1))
            .getSingleOrNull();
    if (plan == null) return;

    await (_db.update(
      _db.focusPlans,
    )..where((p) => p.id.equals(plan.id))).write(
      FocusPlansCompanion(actualSeconds: Value(plan.actualSeconds + seconds)),
    );
  }

  /// 删除计划。
  Future<void> deletePlan(String id) async {
    if (await _planIfOwned(id) == null) return;
    await (_db.delete(_db.focusPlans)..where((p) => p.id.equals(id))).go();
  }

  /// 删除任务的所有未来计划（任务完成时调用）。
  Future<void> deleteFuturePlansForTask(String taskId) async {
    if (!await _ownsTask(taskId)) return;
    final today = _startOfDay(DateTime.now());
    await (_db.delete(_db.focusPlans)..where(
          (p) => p.taskId.equals(taskId) & p.date.isBiggerOrEqualValue(today),
        ))
        .go();
  }

  /// 批量更新排序。
  Future<void> reorderPlans(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        final plan = await _planIfOwned(orderedIds[i]);
        if (plan == null) continue;
        await (_db.update(_db.focusPlans)..where((p) => p.id.equals(plan.id)))
            .write(FocusPlansCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// 查询某任务已有的所有计划（用于规划引擎检查）。
  Future<List<FocusPlan>> plansForTask(String taskId) async {
    if (!await _ownsTask(taskId)) return const <FocusPlan>[];
    return (_db.select(_db.focusPlans)
          ..where((p) => p.taskId.equals(taskId))
          ..orderBy([(p) => OrderingTerm(expression: p.date)]))
        .get();
  }

  Future<bool> _ownsTask(String taskId) async {
    final task =
        await (_db.select(_db.tasks)
              ..where((t) => t.id.equals(taskId) & t.userId.equals(_userId))
              ..limit(1))
            .getSingleOrNull();
    return task != null;
  }

  Future<FocusPlan?> _planIfOwned(String planId) async {
    final query =
        _db.select(_db.focusPlans).join([
            innerJoin(_db.tasks, _db.tasks.id.equalsExp(_db.focusPlans.taskId)),
          ])
          ..where(
            _db.focusPlans.id.equals(planId) & _db.tasks.userId.equals(_userId),
          )
          ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.readTable(_db.focusPlans);
  }

  Future<int> _maxSortOrderForDate(DateTime dayStart) async {
    final dayEnd = dayStart.add(const Duration(days: 1));
    final expr = _db.focusPlans.sortOrder.max();
    final query = _db.selectOnly(_db.focusPlans)
      ..addColumns([expr])
      ..where(
        _db.focusPlans.date.isBetweenValues(dayStart, dayEnd) &
            _db.focusPlans.taskId.isInQuery(
              _db.selectOnly(_db.tasks)
                ..addColumns([_db.tasks.id])
                ..where(_db.tasks.userId.equals(_userId)),
            ),
      );
    final row = await query.getSingle();
    return row.read(expr) ?? -1;
  }

  static DateTime _startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}

@Riverpod(keepAlive: true)
FocusPlanRepository focusPlanRepository(Ref ref) {
  return FocusPlanRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(currentUserIdProvider),
  );
}
