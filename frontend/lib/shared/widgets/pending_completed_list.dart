import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/platform/android/haptic.dart';
import 'package:achievements/shared/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 把任务列表拆成 "未完成 + 可折叠的已完成区" 两段。
///
/// - tasks 全为空 -> 渲染 [emptyState]
/// - 仅 pending -> 直接渲染
/// - 仅 completed -> 折叠区一开始展开
/// - 两者都有 -> 上半 pending,下半 ExpansionTile("已完成 (N)")
///
/// 在移动端:向右滑动 = 完成/恢复,向左滑动 = 删除(带触觉反馈)。
class PendingCompletedList extends ConsumerWidget {
  const PendingCompletedList({
    required this.tasks,
    required this.emptyState,
    super.key,
  });

  final List<Task> tasks;
  final Widget emptyState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) return emptyState;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = tasks.where((t) => t.completedAt == null).toList();
    final completed = tasks.where((t) => t.completedAt != null).toList();

    return ListView(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      children: [
        // ── Pending section header ──
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.sm,
              Spacing.base,
              Spacing.xs,
            ),
            child: Text(
              '待完成 (${pending.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.outline,
                letterSpacing: 0.5,
              ),
            ),
          ),

        for (final t in pending)
          _SwipeableTaskTile(task: t, isPending: true),

        // ── Completed section ──
        if (completed.isNotEmpty)
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: ExpansionTile(
                key: const PageStorageKey<String>('completed-fold'),
                initiallyExpanded: pending.isEmpty,
                tilePadding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                ),
                title: Text(
                  '已完成 (${completed.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.outline,
                    letterSpacing: 0.5,
                  ),
                ),
                childrenPadding: EdgeInsets.zero,
                children: [
                  for (final t in completed)
                    _SwipeableTaskTile(task: t, isPending: false),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Swipeable wrapper — 增强的滑动动画
// ─────────────────────────────────────────────────────────────────────

class _SwipeableTaskTile extends ConsumerWidget {
  const _SwipeableTaskTile({required this.task, required this.isPending});

  final Task task;
  final bool isPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.read(taskRepositoryProvider);

    return Dismissible(
      key: ValueKey(task.id),
      // Right swipe: complete (pending) or restore (completed)
      background: _SwipeBackground(
        color: scheme.primaryContainer,
        icon: isPending ? Icons.check_circle_rounded : Icons.undo_rounded,
        label: isPending ? '完成' : '恢复',
        alignment: Alignment.centerLeft,
      ),
      // Left swipe: delete
      secondaryBackground: _SwipeBackground(
        color: scheme.errorContainer,
        icon: Icons.delete_rounded,
        label: '删除',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // complete / restore
          await Haptic.medium();
          await repo.setCompleted(task.id, completed: isPending);
          return false; // the list refreshes reactively; don't remove widget
        } else {
          // delete
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
  final IconData icon;
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
          Icon(
            icon,
            color: isLeft
                ? scheme.onPrimaryContainer
                : scheme.onErrorContainer,
          ),
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
