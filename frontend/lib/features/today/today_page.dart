import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:achievements/shared/widgets/pending_completed_list.dart';
import 'package:achievements/shared/widgets/quick_create_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Today 页面主体(不含 Scaffold / AppBar,由外层 AppShell 提供)。
///
/// Phase 1 step 2:欢迎语 / 日期 / 任务计数 / 任务列表 / 底部快速创建。
/// 任务创建落 Inbox 清单,dueAt = 今天 23:59,确保新建任务立刻出现在 Today。
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksForCurrentListProvider);
    return Column(
      children: [
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载失败:$e'),
              ),
            ),
            data: (tasks) => _TodayBody(tasks: tasks, now: DateTime.now()),
          ),
        ),
        QuickCreateInput(
          hint: 'Add a task for today',
          onSubmit: (title) => _createForToday(ref, title),
        ),
      ],
    );
  }

  Future<void> _createForToday(WidgetRef ref, String title) async {
    final inbox = await ref.read(inboxListProvider.future);
    if (inbox == null) return;
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day, 23, 59);
    await ref
        .read(taskRepositoryProvider)
        .createTask(listId: inbox.id, title: title, dueAt: due);
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
          child: PendingCompletedList(
            tasks: tasks,
            emptyState: const EmptyState(
              icon: Icons.task_alt_outlined,
              title: 'Nothing on today',
              subtitle: '在底部输入框创建第一个任务。',
            ),
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
