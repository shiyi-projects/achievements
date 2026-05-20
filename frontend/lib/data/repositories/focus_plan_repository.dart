import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'focus_plan_repository.g.dart';

class FocusPlanRepository {
  FocusPlanRepository(this._db);

  final AppDatabase _db;

  /// 流式监听某日的所有计划，按 sortOrder 排序。
  Stream<List<FocusPlan>> watchPlansForDate(DateTime date) {
    final dayStart = _startOfDay(date);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (_db.select(_db.focusPlans)
          ..where((p) => p.date.isBetweenValues(dayStart, dayEnd))
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .watch();
  }

  /// 获取今日所有计划。
  Stream<List<FocusPlan>> watchTodayPlans() => watchPlansForDate(DateTime.now());

  /// 获取近 N 天内的过期未完成计划（date < today 且 actual < planned）。
  Stream<List<FocusPlan>> watchOverduePlans({int lookbackDays = 7}) {
    final today = _startOfDay(DateTime.now());
    final cutoff = today.subtract(Duration(days: lookbackDays));
    return (_db.select(_db.focusPlans)
          ..where(
            (p) =>
                p.date.isBiggerOrEqualValue(cutoff) &
                p.date.isSmallerThanValue(today) &
                p.actualSeconds.isSmallerThan(p.plannedMinutes * const Constant(60)),
          )
          ..orderBy([
            (p) => OrderingTerm(
                  expression: p.date,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// 创建或更新计划（同一 taskId + date 唯一）。
  Future<String> upsertPlan({
    required String taskId,
    required DateTime date,
    required int plannedMinutes,
    int? sortOrder,
  }) async {
    final dayStart = _startOfDay(date);

    // 查找是否已存在
    final existing = await (_db.select(_db.focusPlans)
          ..where(
            (p) =>
                p.taskId.equals(taskId) &
                p.date.equals(dayStart),
          )
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.focusPlans)
            ..where((p) => p.id.equals(existing.id)))
          .write(FocusPlansCompanion(
        plannedMinutes: Value(plannedMinutes),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      ));
      return existing.id;
    }

    final id = newId();
    // 获取当日最大 sortOrder
    final maxSort = sortOrder ??
        await _maxSortOrderForDate(dayStart) + 1;

    await _db.into(_db.focusPlans).insert(
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
    final plan = await (_db.select(_db.focusPlans)
          ..where((p) => p.id.equals(planId)))
        .getSingleOrNull();
    if (plan == null) return;

    await (_db.update(_db.focusPlans)
          ..where((p) => p.id.equals(planId)))
        .write(FocusPlansCompanion(
      actualSeconds: Value(plan.actualSeconds + seconds),
    ));
  }

  /// 根据 taskId 和 date 累加实际时长（秒）。找不到计划则忽略。
  Future<void> addActualSecondsByTaskDate(
    String taskId,
    DateTime date,
    int seconds,
  ) async {
    final dayStart = _startOfDay(date);
    final plan = await (_db.select(_db.focusPlans)
          ..where(
            (p) =>
                p.taskId.equals(taskId) &
                p.date.equals(dayStart),
          )
          ..limit(1))
        .getSingleOrNull();
    if (plan == null) return;

    await (_db.update(_db.focusPlans)
          ..where((p) => p.id.equals(plan.id)))
        .write(FocusPlansCompanion(
      actualSeconds: Value(plan.actualSeconds + seconds),
    ));
  }

  /// 删除计划。
  Future<void> deletePlan(String id) async {
    await (_db.delete(_db.focusPlans)..where((p) => p.id.equals(id))).go();
  }

  /// 删除任务的所有未来计划（任务完成时调用）。
  Future<void> deleteFuturePlansForTask(String taskId) async {
    final today = _startOfDay(DateTime.now());
    await (_db.delete(_db.focusPlans)
          ..where(
            (p) =>
                p.taskId.equals(taskId) &
                p.date.isBiggerOrEqualValue(today),
          ))
        .go();
  }

  /// 批量更新排序。
  Future<void> reorderPlans(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.focusPlans)
              ..where((p) => p.id.equals(orderedIds[i])))
            .write(FocusPlansCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// 查询某任务已有的所有计划（用于规划引擎检查）。
  Future<List<FocusPlan>> plansForTask(String taskId) async {
    return (_db.select(_db.focusPlans)
          ..where((p) => p.taskId.equals(taskId))
          ..orderBy([(p) => OrderingTerm(expression: p.date)]))
        .get();
  }

  Future<int> _maxSortOrderForDate(DateTime dayStart) async {
    final dayEnd = dayStart.add(const Duration(days: 1));
    final expr = _db.focusPlans.sortOrder.max();
    final query = _db.selectOnly(_db.focusPlans)
      ..addColumns([expr])
      ..where(_db.focusPlans.date.isBetweenValues(dayStart, dayEnd));
    final row = await query.getSingle();
    return row.read(expr) ?? -1;
  }

  static DateTime _startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}

@Riverpod(keepAlive: true)
FocusPlanRepository focusPlanRepository(Ref ref) {
  return FocusPlanRepository(ref.watch(appDatabaseProvider));
}
