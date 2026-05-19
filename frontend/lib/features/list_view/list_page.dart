import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:achievements/shared/widgets/pending_completed_list.dart';
import 'package:achievements/shared/widgets/quick_create_input.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通用清单视图(System.{inbox/important/planned/all/completed/trash} 与
/// 用户自定义清单共用)。
///
/// 不含 Scaffold / AppBar,由外层 AppShell 提供。
/// current = Inbox 或非系统(自定义)时底部展示 QuickCreate 输入框。
class ListPage extends ConsumerWidget {
  const ListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksForCurrentListProvider);
    final currentAsync = ref.watch(currentListProvider);
    final current = currentAsync.maybeWhen(
      data: (list) => list,
      orElse: () => null,
    );

    final canQuickCreate =
        current != null &&
        (!current.isSystem ||
            SystemListKind.fromValue(current.systemKind) ==
                SystemListKind.inbox);

    return Column(
      children: [
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Text('Failed to load: $e'),
              ),
            ),
            data: (tasks) => PendingCompletedList(
              tasks: tasks,
              emptyState: const EmptyState(
                icon: Icons.inbox_rounded,
                title: 'No tasks here yet',
                subtitle:
                    'Create from the input below or move tasks from other lists.',
              ),
            ),
          ),
        ),
        if (canQuickCreate)
          QuickCreateInput(
            hint: 'Add a task to ${current.name}',
            onSubmit: (title) => ref
                .read(taskRepositoryProvider)
                .createTask(listId: current.id, title: title),
          ),
      ],
    );
  }
}
