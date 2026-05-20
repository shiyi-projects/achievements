import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/priority_chip.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 日历视图专用的任务行。
///
/// 卡片式布局:
/// - 左侧 3dp 优先级色条
/// - 圆形 checkbox (可点击完成/取消)
/// - 标题（完成时划线）
/// - 时间标签
/// - Trailing: 优先级 Chip / 提醒图标 / 星标
class CalendarTaskTile extends ConsumerWidget {
  const CalendarTaskTile({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.completedAt != null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final priority = TaskPriority.fromValue(task.priority);
    final priorityColor = _priorityColor(priority);
    final hasFutureReminder =
        task.remindAt != null && task.remindAt!.isAfter(DateTime.now());

    // Due time label (only show time portion for calendar view)
    String? timeLabel;
    if (task.dueAt != null) {
      final local = task.dueAt!.toLocal();
      if (local.hour != 0 || local.minute != 0) {
        timeLabel = DateFormat('HH:mm').format(local);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.input),
          onTap: () =>
              ref.read(selectedTaskIdProvider.notifier).select(task.id),
          child: Container(
            decoration: priority != TaskPriority.none
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: priorityColor, width: 3),
                    ),
                  )
                : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                priority != TaskPriority.none ? Spacing.sm : Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showTrailing = constraints.maxWidth > 180;
                  return Row(
                    children: [
                      // Checkbox
                      _RoundCheckbox(
                        checked: done,
                        color: done ? scheme.primary : scheme.outline,
                        onTap: () => ref
                            .read(taskRepositoryProvider)
                            .setCompleted(task.id, completed: !done),
                      ),
                      const SizedBox(width: Spacing.md),

                      // Title + time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              task.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: done ? scheme.outline : null,
                                decorationColor: scheme.outline,
                                fontWeight:
                                    done ? FontWeight.w400 : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (timeLabel != null)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: Spacing.xs),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 12,
                                      color: scheme.outline,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      timeLabel,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: scheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Trailing indicators
                      if (showTrailing)
                        ..._buildTrailing(scheme, priority, hasFutureReminder),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTrailing(
    ColorScheme scheme,
    TaskPriority priority,
    bool hasFutureReminder,
  ) {
    final items = <Widget>[];
    if (priority != TaskPriority.none) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: Spacing.sm),
          child: PriorityChip(priority: priority),
        ),
      );
    }
    if (hasFutureReminder) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: Spacing.sm),
          child: Icon(
            Icons.notifications_active_rounded,
            size: 16,
            color: scheme.outline,
          ),
        ),
      );
    }
    if (task.starred) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: Spacing.sm),
          child: Icon(
            Icons.star_rounded,
            size: 16,
            color: Colors.amber.shade600,
          ),
        ),
      );
    }
    return items;
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return AppColors.urgent;
      case TaskPriority.medium:
        return AppColors.medium;
      case TaskPriority.low:
        return AppColors.low;
      case TaskPriority.none:
        return Colors.transparent;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Round Checkbox
// ─────────────────────────────────────────────────────────────────────

class _RoundCheckbox extends StatelessWidget {
  const _RoundCheckbox({
    required this.checked,
    required this.color,
    required this.onTap,
  });

  final bool checked;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}
