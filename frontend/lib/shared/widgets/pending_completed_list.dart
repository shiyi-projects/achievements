import 'package:achievements/data/local/database.dart';
import 'package:achievements/shared/widgets/task_tile.dart';
import 'package:flutter/material.dart';

/// 把任务列表拆成 "未完成 + 可折叠的已完成区" 两段。
///
/// - tasks 全为空 -> 渲染 [emptyState]
/// - 仅 pending -> ListView.separated
/// - 仅 completed -> 折叠区一开始展开,user 主动可收起
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
    final pending = tasks.where((t) => t.completedAt == null).toList();
    final completed = tasks.where((t) => t.completedAt != null).toList();

    return ListView(
      children: [
        for (final t in pending) TaskTile(task: t),
        if (completed.isNotEmpty)
          Theme(
            // 折叠区在 list 中往往视觉过重,去掉 divider 干扰
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const PageStorageKey<String>('completed-fold'),
              initiallyExpanded: pending.isEmpty,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                'Completed (${completed.length})',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 13,
                ),
              ),
              childrenPadding: EdgeInsets.zero,
              children: [for (final t in completed) TaskTile(task: t)],
            ),
          ),
      ],
    );
  }
}
