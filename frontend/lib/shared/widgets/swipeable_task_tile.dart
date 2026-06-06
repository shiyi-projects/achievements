import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/platform/android/haptic.dart';
import 'package:achievements/shared/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 带滑动手势的任务行(右滑完成/恢复,左滑删除,含触觉反馈)。
///
/// 抽成共享组件,供清单页([PendingCompletedList])与今天页统一复用,确保两处
/// 滑动语义一致(此前今天页用裸 TaskTile 无滑动,是已知不一致)。
class SwipeableTaskTile extends ConsumerWidget {
  const SwipeableTaskTile({
    required this.task,
    required this.isPending,
    super.key,
  });

  final Task task;

  /// true=未完成(右滑→完成);false=已完成(右滑→恢复)。
  final bool isPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.read(taskRepositoryProvider);

    return Dismissible(
      key: ValueKey(task.id),
      background: _SwipeBackground(
        color: scheme.primaryContainer,
        icon: isPending
            ? AppIcons.svgIcon(AppIcons.completedStatus, size: 24)
            : AppIcons.svgIcon(AppIcons.undo, size: 24),
        label: isPending ? '完成' : '恢复',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: scheme.errorContainer,
        icon: AppIcons.svgIcon(AppIcons.delete, size: 24),
        label: '删除',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await Haptic.medium();
          await repo.setCompleted(task.id, completed: isPending);
          return false; // 列表响应式刷新,不移除 widget
        } else {
          await Haptic.heavy();
          await repo.softDelete(task.id);
          return false;
        }
      },
      child: TaskTile(task: task),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final Widget icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLeft) ...[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: Spacing.sm),
          ],
          icon,
          if (isLeft) ...[
            const SizedBox(width: Spacing.sm),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
