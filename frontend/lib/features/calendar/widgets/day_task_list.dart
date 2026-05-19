import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/calendar/providers/calendar_providers.dart';
import 'package:achievements/features/calendar/widgets/calendar_task_tile.dart';
import 'package:achievements/features/task_detail/widgets/date_helpers.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 选中日期的任务列表面板。
///
/// 包含:
/// - 日期标签 + 任务数量 badge
/// - 任务列表（CalendarTaskTile）
/// - 空状态提示
class DayTaskList extends ConsumerWidget {
  const DayTaskList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final tasks = ref.watch(selectedDayTasksProvider);

    if (selected == null) {
      return const EmptyState(
        icon: Icons.calendar_today_rounded,
        title: '点击日期查看任务',
        subtitle: '选择一个日期以查看当天的待办事项',
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = formatDateCn(selected);

    // Split pending / completed
    final pending = tasks.where((t) => t.completedAt == null).toList();
    final completed = tasks.where((t) => t.completedAt != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // — Date label + badge —
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.base, Spacing.sm, Spacing.base, Spacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: tasks.isNotEmpty
                      ? scheme.primary.withValues(alpha: 0.1)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.circle),
                ),
                child: Text(
                  '${tasks.length} 项任务',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        tasks.isNotEmpty ? scheme.primary : scheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        // — Task list or empty —
        if (tasks.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.event_available_rounded,
              title: '这一天没有任务',
              subtitle: '选定日期无待办事项',
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.base,
                vertical: Spacing.xs,
              ),
              children: [
                // Pending tasks
                if (pending.isNotEmpty) ...[
                  for (final t in pending) CalendarTaskTile(task: t),
                ],
                // Completed section
                if (completed.isNotEmpty) ...[
                  _CompletedHeader(
                    count: completed.length,
                  ),
                  for (final t in completed) CalendarTaskTile(task: t),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// 「已完成」折叠标题。
class _CompletedHeader extends StatefulWidget {
  const _CompletedHeader({required this.count});
  final int count;

  @override
  State<_CompletedHeader> createState() => _CompletedHeaderState();
}

class _CompletedHeaderState extends State<_CompletedHeader> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        top: Spacing.sm,
        bottom: Spacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            '已完成',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            '${widget.count}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
