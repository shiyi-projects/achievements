import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/tag_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/platform/android/haptic.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/shared/widgets/priority_chip.dart';
import 'package:achievements/shared/widgets/tags_row.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
          onLongPress: () {
            Haptic.medium();
            _showContextMenu(context, ref);
          },
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
                        // trailing 总宽 ~80dp,挤压时 title 走 ellipsis 截断,不再做窄屏隐藏
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
    )
        .animate()
        .fadeIn(duration: MotionDurations.fast)
        .slideX(
          begin: 0.03,
          duration: MotionDurations.normal,
          curve: MotionCurves.decelerate,
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

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final done = task.completedAt != null;
    final repo = ref.read(taskRepositoryProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                done ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
              ),
              title: Text(done ? '标记为未完成' : '标记为完成'),
              onTap: () {
                Navigator.pop(context);
                Haptic.light();
                repo.setCompleted(task.id, completed: !done);
              },
            ),
            ListTile(
              leading: Icon(
                task.starred
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: task.starred
                    ? Theme.of(context).colorScheme.tertiary
                    : null,
              ),
              title: Text(task.starred ? '取消星标' : '加星标'),
              onTap: () {
                Navigator.pop(context);
                Haptic.light();
                repo.update(task.id, starred: Value(!task.starred));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('移到回收站'),
              onTap: () {
                Navigator.pop(context);
                Haptic.medium();
                repo.softDelete(task.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Round Checkbox (animated)
// ─────────────────────────────────────────────────────────────────────

class _RoundCheckbox extends StatefulWidget {
  const _RoundCheckbox({
    required this.checked,
    required this.color,
    required this.onTap,
  });

  final bool checked;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_RoundCheckbox> createState() => _RoundCheckboxState();
}

class _RoundCheckboxState extends State<_RoundCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionDurations.fast,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: MotionCurves.decelerate));
  }

  @override
  void didUpdateWidget(_RoundCheckbox old) {
    super.didUpdateWidget(old);
    if (!old.checked && widget.checked) {
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
        scale: _scale,
        child: AnimatedContainer(
          duration: MotionDurations.fast,
          curve: MotionCurves.spring,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.checked ? widget.color : Colors.transparent,
            border: Border.all(color: widget.color, width: 2),
          ),
          child: AnimatedSwitcher(
            duration: MotionDurations.fast,
            child: widget.checked
                ? const Icon(
                    Icons.check_rounded,
                    key: ValueKey('check'),
                    size: 16,
                    color: Colors.white,
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ),
      ),
    );
  }
}
