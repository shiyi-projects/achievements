import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/focus_plan_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'focus_plan_service.g.dart';

/// 智能专注规划引擎。
///
/// 职责:
/// - 根据任务的 [estimatedMinutes] + [dueAt] 自动按天拆分计划
/// - 计时结束后累加实际时长到对应计划
/// - 任务完成时清理未来计划
class FocusPlanService {
  FocusPlanService(this._planRepo, this._taskRepo);

  final FocusPlanRepository _planRepo;
  final TaskRepository _taskRepo;

  /// 默认每日最大规划时长（分钟）。
  static const int defaultDailyMaxMinutes = 240;

  /// 为任务自动生成每日计划。
  ///
  /// 规则:
  /// 1. 总时长 ÷ 剩余天数，余数加到最早一天
  /// 2. 已有 actualSeconds 的日期不重新分配
  /// 3. 每天最多 [defaultDailyMaxMinutes] 分钟
  Future<void> generatePlans(Task task) async {
    final estimated = task.estimatedMinutes;
    final dueAt = task.dueAt;
    if (estimated == null || estimated <= 0 || dueAt == null) return;

    final today = _startOfDay(DateTime.now());
    final dueDay = _startOfDay(dueAt);

    // 截止日当天不安排，只安排到截止日前一天
    if (!dueDay.isAfter(today)) {
      // 只剩今天或已过期 → 全部安排到今天
      await _planRepo.upsertPlan(
        taskId: task.id,
        date: today,
        plannedMinutes: estimated.clamp(1, defaultDailyMaxMinutes),
      );
      return;
    }

    // 计算可用天数
    final availableDays = dueDay.difference(today).inDays; // 不含截止日
    if (availableDays <= 0) return;

    // 检查已有计划的实际完成量
    final existingPlans = await _planRepo.plansForTask(task.id);
    final alreadyDone = existingPlans.fold<int>(
      0,
      (sum, p) => sum + (p.actualSeconds / 60).floor(),
    );

    final remaining = (estimated - alreadyDone).clamp(0, estimated);
    if (remaining <= 0) return; // 已经做完了

    // 均匀分配
    final perDay = remaining ~/ availableDays;
    var remainder = remaining % availableDays;

    for (var i = 0; i < availableDays; i++) {
      final date = today.add(Duration(days: i));
      var planned = perDay + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;

      // 限制单日上限
      planned = planned.clamp(1, defaultDailyMaxMinutes);

      // 如果该日已有完成量，不降低计划
      final existing = existingPlans
          .where((p) => _startOfDay(p.date) == date)
          .toList();
      if (existing.isNotEmpty &&
          (existing.first.actualSeconds / 60).floor() >= planned) {
        continue; // 已完成量超过分配量，跳过
      }

      await _planRepo.upsertPlan(
        taskId: task.id,
        date: date,
        plannedMinutes: planned,
      );
    }
  }

  /// 计时结束时调用：累加实际时长到今日对应计划 + 任务累计专注。
  Future<void> onSessionComplete({
    required String? taskId,
    required int durationSeconds,
  }) async {
    if (taskId == null || durationSeconds <= 0) return;
    // 秒级累加到计划
    await _planRepo.addActualSecondsByTaskDate(
      taskId,
      DateTime.now(),
      durationSeconds,
    );
    // 秒级累加到任务
    await _taskRepo.addFocusedSeconds(taskId, durationSeconds);
  }

  /// 任务完成时：清理所有未来计划。
  Future<void> onTaskCompleted(String taskId) async {
    await _planRepo.deleteFuturePlansForTask(taskId);
  }

  static DateTime _startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}

@Riverpod(keepAlive: true)
FocusPlanService focusPlanService(Ref ref) {
  return FocusPlanService(
    ref.watch(focusPlanRepositoryProvider),
    ref.watch(taskRepositoryProvider),
  );
}
