import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/shared/widgets/priority_chip.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 日历视图专用的任务行。
///
/// 卡片式布局:
/// - 左侧 3dp 优先级色条
/// - 弹性圆形 checkbox
/// - 标题（完成时划线）
/// - 时间标签
/// - Trailing: 优先级 Chip / 提醒图标 / 星标
/// - Dismissible 滑动操作 (右滑完成, 左滑删除)
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

    String? timeLabel;
    if (task.dueAt != null) {
      final local = task.dueAt!.toLocal();
      if (local.hour != 0 || local.minute != 0) {
        timeLabel = DateFormat('HH:mm').format(local);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Dismissible(
        key: ValueKey('cal-task-${task.id}'),
        direction: DismissDirection.horizontal,
        // ── 右滑: 完成/恢复 ──
        background: _SwipeBackground(
          alignment: Alignment.centerLeft,
          color: scheme.primary,
          icon: done ? AppIcons.svgIcon(AppIcons.undo, size: 20) : AppIcons.svgIcon(AppIcons.check, size: 20),
          label: done ? '恢复' : '完成',
        ),
        // ── 左滑: 删除 ──
        secondaryBackground: _SwipeBackground(
          alignment: Alignment.centerRight,
          color: scheme.error,
          icon: AppIcons.svgIcon(AppIcons.delete, size: 20),
          label: '删除',
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await ref
                .read(taskRepositoryProvider)
                .setCompleted(task.id, completed: !done);
          } else {
            await ref.read(taskRepositoryProvider).softDelete(task.id);
          }
          return false; // Don't remove widget, let provider rebuild
        },
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
                        // ── Checkbox ──
                        _BouncyCheckbox(
                          checked: done,
                          color: done ? scheme.primary : scheme.outline,
                          onTap: () => ref
                              .read(taskRepositoryProvider)
                              .setCompleted(task.id, completed: !done),
                        ),
                        const SizedBox(width: Spacing.md),

                        // ── Title + time ──
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
                                      AppIcons.svgIcon(AppIcons.planned, size: 12),
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

                        // ── Trailing indicators ──
                        if (showTrailing)
                          ..._buildTrailing(
                              scheme, priority, hasFutureReminder),
                      ],
                    );
                  },
                ),
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
          child: AppIcons.svgIcon(AppIcons.reminder, size: 16),
        ),
      );
    }
    if (task.starred) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: Spacing.sm),
          child: AppIcons.svgIcon(AppIcons.important, size: 16),
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
// Bouncy Checkbox — animated scale on toggle
// ─────────────────────────────────────────────────────────────────────

class _BouncyCheckbox extends StatefulWidget {
  const _BouncyCheckbox({
    required this.checked,
    required this.color,
    required this.onTap,
  });

  final bool checked;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_BouncyCheckbox> createState() => _BouncyCheckboxState();
}

class _BouncyCheckboxState extends State<_BouncyCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionDurations.fast,
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.15), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: _ctrl,
      curve: MotionCurves.emphasizedDecelerate,
    ));
  }

  @override
  void didUpdateWidget(_BouncyCheckbox old) {
    super.didUpdateWidget(old);
    if (old.checked != widget.checked) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: MotionDurations.fast,
          curve: MotionCurves.emphasizedDecelerate,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.checked ? widget.color : Colors.transparent,
            border: Border.all(color: widget.color, width: 1.5),
          ),
          child: widget.checked
              ? AppIcons.svgIcon(AppIcons.check, size: 14)
              : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Swipe background
// ─────────────────────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final AlignmentGeometry alignment;
  final Color color;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: Spacing.xs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
