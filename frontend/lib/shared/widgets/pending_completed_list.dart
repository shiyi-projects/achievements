import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/shared/widgets/swipeable_task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 把任务列表拆成 "未完成 + 可折叠的已完成区" 两段。
///
/// - tasks 全为空 -> 渲染 [emptyState]
/// - 仅 pending -> 直接渲染
/// - 仅 completed -> 折叠区一开始展开
/// - 两者都有 -> 上半 pending,下半 ExpansionTile("已完成 (N)")
///
/// 滑动手势由共享的 [SwipeableTaskTile] 提供(右滑完成/恢复,左滑删除)。
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
    if (tasks.isEmpty) {
      // 用 ListView 而非裸 emptyState,这样外层 RefreshIndicator 在空清单上
      // 也能拉到(下拉手势需要 Scrollable 才能触发)。
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            // 给 emptyState 一个能撑满屏幕的高度,视觉上还是居中。
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Center(child: emptyState),
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = tasks.where((t) => t.completedAt == null).toList();
    final completed = tasks.where((t) => t.completedAt != null).toList();

    return ListView(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      physics: const AlwaysScrollableScrollPhysics(),
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

        for (final t in pending) SwipeableTaskTile(task: t, isPending: true),

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
                    SwipeableTaskTile(task: t, isPending: false),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
