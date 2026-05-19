import 'package:achievements/core/constants.dart';
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
/// - 左侧 checkbox(IconButton):切换完成态,不冒泡 onTap
/// - 整行 tap:打开任务详情面板
/// - 尾部:starred 星标 + 优先级 chip(None 不渲染)
class TaskTile extends ConsumerWidget {
  const TaskTile({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.completedAt != null;
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectedTaskIdProvider);
    final selected = selectedId == task.id;
    final priority = TaskPriority.fromValue(task.priority);
    final tagsAsync = ref.watch(tagsForTaskProvider(task.id));
    final tags = tagsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <Tag>[],
    );

    final trailing = <Widget>[
      if (priority != TaskPriority.none) PriorityChip(priority: priority),
      if (task.starred)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(Icons.star, size: 18, color: theme.colorScheme.tertiary),
        ),
    ];

    return ListTile(
      selected: selected,
      leading: IconButton(
        icon: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? theme.colorScheme.primary : null,
        ),
        tooltip: done ? 'Mark as not done' : 'Mark as done',
        onPressed: () => ref
            .read(taskRepositoryProvider)
            .setCompleted(task.id, completed: !done),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? theme.colorScheme.outline : null,
        ),
      ),
      subtitle: tags.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TagsRow(tags: tags),
            ),
      trailing: trailing.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: trailing),
      onTap: () => ref.read(selectedTaskIdProvider.notifier).select(task.id),
    );
  }
}
