import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/task_detail/widgets/date_helpers.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Providers (local state, keepAlive false — destroyed with page)
// ─────────────────────────────────────────────────────────────────────

final _focusedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final _selectedDayProvider = StateProvider<DateTime?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────
// CalendarPage
// ─────────────────────────────────────────────────────────────────────

/// 日历视图:月视图 + 选中日期任务列表。
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_focusedMonthProvider);
    final selected = ref.watch(_selectedDayProvider);
    final tasksAsync = ref.watch(tasksForMonthProvider(month));

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

    final dayTasks = selected == null
        ? const <Task>[]
        : (byDay[selected.day] ?? const <Task>[]);

    return Column(
      children: [
        _CalendarHeader(month: month),
        const Divider(height: 1),
        _MonthGrid(month: month, byDay: byDay, selected: selected),
        const Divider(height: 1),
        Expanded(
          child: selected == null
              ? _EmptyDayHint()
              : _DayTaskList(date: selected, tasks: dayTasks),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────

class _CalendarHeader extends ConsumerWidget {
  const _CalendarHeader({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = '${month.year} 年 ${month.month} 月';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.md,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => ref.read(_focusedMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => ref.read(_focusedMonthProvider.notifier).state =
                DateTime(month.year, month.month + 1),
          ),
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              ref.read(_focusedMonthProvider.notifier).state =
                  DateTime(now.year, now.month);
              ref.read(_selectedDayProvider.notifier).state =
                  DateTime(now.year, now.month, now.day);
            },
            child: const Text('今天'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Month Grid
// ─────────────────────────────────────────────────────────────────────

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selected,
  });

  final DateTime month;
  final Map<int, List<Task>> byDay;
  final DateTime? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

    // 当月第一天是周几 (1=Mon … 7=Sun)
    final firstWeekday = DateTime(month.year, month.month).weekday;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    final cells = <Widget>[
      for (final w in weekLabels)
        Center(
          child: Text(
            w,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
      // 占位格(周一为第一列)
      for (var i = 1; i < firstWeekday; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _DayCell(
          day: d,
          month: month,
          hasTasks: byDay.containsKey(d),
          taskCount: byDay[d]?.length ?? 0,
          isSelected: selected != null &&
              selected!.year == month.year &&
              selected!.month == month.month &&
              selected!.day == d,
          isToday: _isToday(month, d),
          onTap: () {
            ref.read(_selectedDayProvider.notifier).state =
                DateTime(month.year, month.month, d);
          },
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.1,
        children: cells,
      ),
    );
  }

  static bool _isToday(DateTime month, int day) {
    final now = DateTime.now();
    return now.year == month.year && now.month == month.month && now.day == day;
  }
}

// ─────────────────────────────────────────────────────────────────────
// Day Cell
// ─────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.month,
    required this.hasTasks,
    required this.taskCount,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final DateTime month;
  final bool hasTasks;
  final int taskCount;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bgColor = isSelected
        ? scheme.primary
        : isToday
            ? scheme.primaryContainer
            : Colors.transparent;
    final fgColor = isSelected
        ? scheme.onPrimary
        : isToday
            ? scheme.onPrimaryContainer
            : scheme.onSurface;
    final dotColor = isSelected ? scheme.onPrimary.withValues(alpha: 0.7) : scheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                color: fgColor,
              ),
            ),
            if (hasTasks)
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Day Task List
// ─────────────────────────────────────────────────────────────────────

class _DayTaskList extends ConsumerWidget {
  const _DayTaskList({required this.date, required this.tasks});

  final DateTime date;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = formatDateCn(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.base,
            Spacing.md,
            Spacing.base,
            Spacing.sm,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.base,
              vertical: Spacing.sm,
            ),
            child: Text(
              '这一天没有任务',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              itemCount: tasks.length,
              itemBuilder: (context, i) => _CalendarTaskTile(task: tasks[i]),
            ),
          ),
      ],
    );
  }
}

class _CalendarTaskTile extends ConsumerWidget {
  const _CalendarTaskTile({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final completed = task.completedAt != null;

    return InkWell(
      onTap: () => ref.read(selectedTaskIdProvider.notifier).select(task.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.base,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: completed ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                task.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: completed ? TextDecoration.lineThrough : null,
                  color: completed ? scheme.outline : scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.starred)
              Icon(Icons.star_rounded, size: 16, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Empty hint
// ─────────────────────────────────────────────────────────────────────

class _EmptyDayHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '点击日期查看任务',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}
