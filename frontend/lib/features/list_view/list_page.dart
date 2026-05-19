import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通用清单视图(System.{all/important/planned/completed/trash/inbox} 与用户自定义清单共用)。
///
/// 不含 Scaffold / AppBar,由外层 AppShell 提供。
class ListPage extends ConsumerWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksForCurrentListProvider);
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('加载失败:$e'),
        ),
      ),
      data: (tasks) => tasks.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No tasks here yet',
              subtitle: '在底部快速创建,或从其他清单移动过来。',
            )
          : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _TaskTile(task: tasks[i]),
            ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final done = task.completedAt != null;
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? Theme.of(context).colorScheme.outline : null,
        ),
      ),
    );
  }
}
