import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Today 页面主体(不含 Scaffold / AppBar,由外层 AppShell 提供)。
///
/// Phase 1 step 1:欢迎语 / 日期 / 任务计数 / 任务列表 / 空状态。
/// 后续 step 补:快速创建输入框、已完成折叠、连续完成天数、下拉刷新。
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

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
      data: (tasks) => _TodayBody(tasks: tasks, now: DateTime.now()),
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.tasks, required this.now});

  final List<Task> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = tasks.where((t) => t.completedAt != null).length;
    final pending = tasks.length - completed;
    final dateLabel = DateFormat.yMMMMEEEEd().format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(now.hour), style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tasks.isEmpty ? '没有今天到期的任务' : '$pending 个待办 · $completed 个已完成',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: tasks.isEmpty
              ? const EmptyState(
                  icon: Icons.task_alt_outlined,
                  title: 'Nothing on today',
                  subtitle: '快速输入框将在下一步落地。',
                )
              : ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _TaskTile(task: tasks[i]),
                ),
        ),
      ],
    );
  }

  String _greeting(int hour) {
    if (hour < 5) return 'Still up?';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
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
