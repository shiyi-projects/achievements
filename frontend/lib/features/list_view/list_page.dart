import 'package:achievements/core/constants.dart';
import 'package:achievements/core/sync/sync_coordinator.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:achievements/shared/widgets/pending_completed_list.dart';
import 'package:achievements/shared/widgets/quick_create_input.dart';
import 'package:achievements/shared/widgets/task_tile.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通用清单视图(System.{inbox/important/planned/all/completed/trash} 与
/// 用户自定义清单共用)。
///
/// 搜索由全局 Ctrl+K 命令面板承担,本页不再嵌入 inline 搜索栏。
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

    final canQuickCreate = current != null &&
        (!current.isSystem ||
            SystemListKind.fromValue(current.systemKind) ==
                SystemListKind.inbox);

    final isTrash = current != null &&
        current.isSystem &&
        SystemListKind.fromValue(current.systemKind) ==
            SystemListKind.trash;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(syncCoordinatorProvider).runFullSync(),
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Text('加载失败: $e'),
                ),
              ),
              data: (tasks) => isTrash
                  ? _TrashList(tasks: tasks)
                  : PendingCompletedList(
                      tasks: tasks,
                      emptyState: EmptyState(
                        icon: AppIcons.svgIcon(AppIcons.inbox, size: 36),
                        title: '还没有任务',
                        subtitle: '从下方输入框创建，或从其他清单移入。',
                      ),
                    ),
            ),
          ),
        ),

        if (canQuickCreate)
          QuickCreateInput(
            hint: '添加任务到「${displayNameOfList(systemKind: current.systemKind, fallback: current.name)}」…',
            onSubmit: (title) => ref
                .read(taskRepositoryProvider)
                .createTask(listId: current.id, title: title),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Trash — 扁平列表,不区分已完成/未完成
// ─────────────────────────────────────────────────────────────────────

class _TrashList extends ConsumerWidget {
  const _TrashList({required this.tasks});
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      // 同 PendingCompletedList:让外层 RefreshIndicator 在空清单也能拉。
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Center(
              child: EmptyState(
                icon: AppIcons.svgIcon(AppIcons.delete, size: 36),
                title: '回收站是空的',
                subtitle: '被删除的任务会出现在这里。',
              ),
            ),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      itemCount: tasks.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl, Spacing.sm, Spacing.base, Spacing.xs,
            ),
            child: Text(
              '已删除 (${tasks.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.outline,
                letterSpacing: 0.5,
              ),
            ),
          );
        }
        final task = tasks[index - 1];
        return Dismissible(
          key: ValueKey('trash-${task.id}'),
          // 右滑: 恢复
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            color: scheme.primaryContainer,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcons.svgIcon(AppIcons.undo, size: 20),
                const SizedBox(width: Spacing.xs),
                Text('恢复', style: TextStyle(color: scheme.onPrimaryContainer)),
              ],
            ),
          ),
          // 左滑: 永久删除
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            color: scheme.errorContainer,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('永久删除', style: TextStyle(color: scheme.onErrorContainer)),
                const SizedBox(width: Spacing.xs),
                AppIcons.svgIcon(AppIcons.delete, size: 20),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // 恢复
              await ref.read(taskRepositoryProvider).restore(task.id);
              return false; // 流会自动更新列表
            } else {
              // 永久删除
              await ref.read(taskRepositoryProvider).hardDelete(task.id);
              return false;
            }
          },
          child: TaskTile(task: task),
        );
      },
    );
  }
}
