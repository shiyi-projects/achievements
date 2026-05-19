import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任务行,Today / ListPage 共用。
///
/// 点击左侧 checkbox 切换完成态;后续 Phase 增加右侧元数据(优先级 / 标签 /
/// 截止时间)与 onTap 打开详情面板。
class TaskTile extends ConsumerWidget {
  const TaskTile({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.completedAt != null;
    final theme = Theme.of(context);
    return ListTile(
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
    );
  }
}
