import 'package:achievements/core/id.dart';
import 'package:achievements/core/recurrence/recurrence_service.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:drift/drift.dart' show Value;
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

/// 当月所有带 dueAt 的任务（响应式）。含一次性任务、重复模板(锚点当天)、override。
final monthTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final month = ref.watch(focusedMonthProvider);
  return ref.watch(tasksForMonthProvider(month));
});

/// 所有与重复相关的行(模板 + override,含软删 override)。
final recurringRowsProvider = Provider<AsyncValue<List<Task>>>((ref) {
  return ref.watch(_recurringRowsStreamProvider);
});

final _recurringRowsStreamProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchRecurring();
});

// ─────────────────────────────────────────────────────────────────────
// 日历条目:统一「一次性任务 / 已实体化 override」与「虚拟发生点」
// ─────────────────────────────────────────────────────────────────────

/// 日历上的一条任务。[displayTask] 永远是可渲染的 Task(虚拟发生点用模板派生的合成行)。
/// [isVirtual] 为 true 时,[template] + [occurrence] 提供完成 / 删除该次所需上下文。
class CalendarEntry {
  const CalendarEntry._({
    required this.displayTask,
    this.template,
    this.occurrence,
  });

  /// 真实行(一次性任务或已实体化 override)。
  factory CalendarEntry.real(Task task) => CalendarEntry._(displayTask: task);

  /// 虚拟发生点:用模板派生一个仅供展示的合成行。
  factory CalendarEntry.virtual({
    required Task template,
    required DateTime occurrence,
  }) {
    return CalendarEntry._(
      displayTask: template.copyWith(
        id: occurrenceId(template.id, occurrence),
        dueAt: Value(occurrence),
        remindAt: const Value(null),
        completedAt: const Value(null),
      ),
      template: template,
      occurrence: occurrence,
    );
  }

  final Task displayTask;
  final Task? template;
  final DateTime? occurrence;

  bool get isVirtual => template != null;
  DateTime get date => displayTask.dueAt!;
}

/// 当月按天分组的日历条目(一次性 + 重复展开 + override 合并)。key = day number。
final calendarEntriesByDayProvider = Provider<Map<int, List<CalendarEntry>>>((
  ref,
) {
  final month = ref.watch(focusedMonthProvider);
  final svc = ref.watch(recurrenceServiceProvider);
  final monthTasks = ref
      .watch(monthTasksProvider)
      .maybeWhen(data: (t) => t, orElse: () => const <Task>[]);
  final recurring = ref
      .watch(recurringRowsProvider)
      .maybeWhen(data: (t) => t, orElse: () => const <Task>[]);

  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1);

  final byDay = <int, List<CalendarEntry>>{};
  void add(CalendarEntry e) =>
      byDay.putIfAbsent(e.date.toLocal().day, () => []).add(e);

  // 1) 一次性任务:排除模板(交给展开)与 override(由 mergeOverrides 处理)。
  for (final t in monthTasks) {
    if (t.repeatRule != null) continue;
    if (t.recurrenceParentId != null) continue;
    if (t.dueAt == null) continue;
    add(CalendarEntry.real(t));
  }

  // 2) 重复系列:展开当月窗口 + 合并 override。
  final overridesByParent = <String, List<Task>>{};
  for (final t in recurring) {
    final pid = t.recurrenceParentId;
    if (pid != null) overridesByParent.putIfAbsent(pid, () => []).add(t);
  }
  for (final tpl in recurring) {
    if (tpl.repeatRule == null ||
        tpl.recurrenceParentId != null ||
        tpl.deletedAt != null ||
        tpl.dueAt == null) {
      continue; // 仅展开未删的模板
    }
    final dates = svc.expand(
      rule: tpl.repeatRule!,
      dtStart: tpl.dueAt!,
      from: from,
      to: to,
    );
    final views = svc.mergeOverrides(
      templateId: tpl.id,
      virtualDates: dates,
      overrides: overridesByParent[tpl.id] ?? const [],
    );
    for (final v in views) {
      add(
        v.materialized != null
            ? CalendarEntry.real(v.materialized!)
            : CalendarEntry.virtual(template: tpl, occurrence: v.date),
      );
    }
  }

  for (final list in byDay.values) {
    list.sort((a, b) => a.date.compareTo(b.date));
  }
  return byDay;
});

/// 按天分组的展示任务(供月历格子统计 / 圆点)。从 [calendarEntriesByDayProvider] 派生。
final tasksByDayProvider = Provider<Map<int, List<Task>>>((ref) {
  final byDay = ref.watch(calendarEntriesByDayProvider);
  return {
    for (final entry in byDay.entries)
      entry.key: [for (final e in entry.value) e.displayTask],
  };
});

/// 选中日期的日历条目。
final selectedDayEntriesProvider = Provider<List<CalendarEntry>>((ref) {
  final selected = ref.watch(selectedDayProvider);
  if (selected == null) return const <CalendarEntry>[];
  final byDay = ref.watch(calendarEntriesByDayProvider);
  return byDay[selected.day] ?? const <CalendarEntry>[];
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
  final byDay = ref.watch(calendarEntriesByDayProvider);
  var total = 0;
  var completed = 0;
  for (final list in byDay.values) {
    for (final e in list) {
      total++;
      if (e.displayTask.completedAt != null) completed++;
    }
  }
  return MonthStatsWithDays(
    total: total,
    completed: completed,
    activeDays: byDay.keys.length,
  );
});
