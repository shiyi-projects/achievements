import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/tag_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/priority_chip.dart';
import 'package:achievements/shared/widgets/tags_row.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任务行,Today / ListPage 共用。
///
/// 卡片式布局:
/// - 左侧 4dp 优先级色条
/// - 圆形 Checkbox
/// - 标题 + 标签行
/// - trailing: 优先级 Chip / 提醒图标 / 星标
class TaskTile extends ConsumerWidget {
  const TaskTile({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.completedAt != null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedId = ref.watch(selectedTaskIdProvider);
    final selected = selectedId == task.id;
    final priority = TaskPriority.fromValue(task.priority);
    final tagsAsync = ref.watch(tagsForTaskProvider(task.id));
    final tags = tagsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <Tag>[],
    );
    final hasFutureReminder =
        task.remindAt != null && task.remindAt!.isAfter(DateTime.now());

    final priorityColor = _priorityColor(priority);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      child: Material(
        color: selected
            ? scheme.secondaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () =>
              ref.read(selectedTaskIdProvider.notifier).select(task.id),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Priority Color Strip ──
                if (priority != TaskPriority.none)
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(Radii.card),
                      ),
                    ),
                  ),

                // ── Main Content ──
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      priority != TaskPriority.none ? Spacing.sm : Spacing.md,
                      Spacing.sm,
                      Spacing.md,
                      Spacing.sm,
                    ),
                    child: Row(
                      children: [
                        // ── Checkbox ──
                        _RoundCheckbox(
                          checked: done,
                          color: done ? scheme.primary : scheme.outline,
                          onTap: () => ref
                              .read(taskRepositoryProvider)
                              .setCompleted(task.id, completed: !done),
                        ),
                        const SizedBox(width: Spacing.md),

                        // ── Title + Tags ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                task.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: done ? scheme.outline : null,
                                  decorationColor: scheme.outline,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (tags.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: Spacing.xs,
                                  ),
                                  child: TagsRow(tags: tags),
                                ),
                            ],
                          ),
                        ),

                        // ── Trailing ──
                        ..._buildTrailing(
                          theme,
                          scheme,
                          priority,
                          hasFutureReminder,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTrailing(
    ThemeData theme,
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
            size: 18,
            color: scheme.outline,
          ),
        ),
      );
    }
    if (task.starred) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: Spacing.sm),
          child: Icon(Icons.star_rounded, size: 18, color: scheme.tertiary),
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
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? color : Colors.transparent,
          border: Border.all(color: color, width: 2),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
