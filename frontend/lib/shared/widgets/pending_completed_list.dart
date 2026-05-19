import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/shared/widgets/task_tile.dart';
import 'package:flutter/material.dart';

/// 把任务列表拆成 "未完成 + 可折叠的已完成区" 两段。
///
/// - tasks 全为空 -> 渲染 [emptyState]
/// - 仅 pending -> 直接渲染
/// - 仅 completed -> 折叠区一开始展开
/// - 两者都有 -> 上半 pending,下半 ExpansionTile("Completed (N)")
class PendingCompletedList extends StatelessWidget {
  const PendingCompletedList({
    required this.tasks,
    required this.emptyState,
    super.key,
  });

  final List<Task> tasks;
  final Widget emptyState;

  @override
  Widget build(BuildContext context) {
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
              'Pending (${pending.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.outline,
                letterSpacing: 0.5,
              ),
            ),
          ),

        for (final t in pending) TaskTile(task: t),

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
                  'Completed (${completed.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.outline,
                    letterSpacing: 0.5,
                  ),
                ),
                childrenPadding: EdgeInsets.zero,
                children: [for (final t in completed) TaskTile(task: t)],
              ),
            ),
          ),
      ],
    );
  }
}
