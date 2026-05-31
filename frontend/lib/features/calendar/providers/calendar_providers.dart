import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Calendar local state providers
// ─────────────────────────────────────────────────────────────────────

/// 当前聚焦月份（1 日 00:00）。
final focusedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// 当前选中日期。默认选中今天。
final selectedDayProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 当月所有带 dueAt 的任务（响应式）。
final monthTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final month = ref.watch(focusedMonthProvider);
  return ref.watch(tasksForMonthProvider(month));
});

/// 按天分组的任务 Map。key = day number (1-31)。
final tasksByDayProvider = Provider<Map<int, List<Task>>>((ref) {
  final tasksAsync = ref.watch(monthTasksProvider);
  final tasks = tasksAsync.maybeWhen(
    data: (t) => t,
    orElse: () => const <Task>[],
  );

  final byDay = <int, List<Task>>{};
  for (final t in tasks) {
    if (t.dueAt == null) continue;
    final d = t.dueAt!.toLocal();
    final key = d.day;
    byDay.putIfAbsent(key, () => []).add(t);
  }
  return byDay;
});

/// 选中日期的任务列表。
final selectedDayTasksProvider = Provider<List<Task>>((ref) {
  final selected = ref.watch(selectedDayProvider);
  if (selected == null) return const <Task>[];
  final byDay = ref.watch(tasksByDayProvider);
  return byDay[selected.day] ?? const <Task>[];
});

/// 月度统计数据。
class MonthStats {
  const MonthStats({required this.total, required this.completed});

  final int total;
  final int completed;

  int get pending => total - completed;
  double get completionRate => total > 0 ? completed / total : 0.0;
  int get daysWithTasks => 0; // 由 provider 覆盖
}

class MonthStatsWithDays extends MonthStats {
  const MonthStatsWithDays({
    required super.total,
    required super.completed,
    required this.activeDays,
  });

  final int activeDays;

  @override
  int get daysWithTasks => activeDays;
}

final monthStatsProvider = Provider<MonthStatsWithDays>((ref) {
  final tasksAsync = ref.watch(monthTasksProvider);
  final tasks = tasksAsync.maybeWhen(
    data: (t) => t,
    orElse: () => const <Task>[],
  );
  final byDay = ref.watch(tasksByDayProvider);

  final completed = tasks.where((t) => t.completedAt != null).length;
  return MonthStatsWithDays(
    total: tasks.length,
    completed: completed,
    activeDays: byDay.keys.length,
  );
});
