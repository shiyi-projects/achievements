import 'package:achievements/core/constants.dart';
import 'package:achievements/core/sync/sync_coordinator.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:achievements/shared/widgets/pending_completed_list.dart';
import 'package:achievements/shared/widgets/quick_create_input.dart';
import 'package:achievements/shared/widgets/task_tile.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前清单是否只看星标(⭐ 筛选开关)。
///
/// 「重要」系统清单从侧边栏收敛后(见 dev_docs/recurring-tasks.md §8.1),改由此
/// 开关在**任意清单内**就地筛选星标任务,语义更通用。
final listStarFilterProvider = StateProvider<bool>((ref) => false);

/// 通用清单视图(System.{inbox/planned/all/completed/trash} 与用户自定义清单共用)。
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
    final starOnly = ref.watch(listStarFilterProvider);

    final canQuickCreate =
        current != null &&
        (!current.isSystem ||
            SystemListKind.fromValue(current.systemKind) ==
                SystemListKind.inbox);

    final isTrash =
        current != null &&
        current.isSystem &&
        SystemListKind.fromValue(current.systemKind) == SystemListKind.trash;

    return Column(
      children: [
        if (!isTrash) const _StarFilterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(syncCoordinatorProvider).runFullSync(),
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Text('加载失败: $e'),
                ),
              ),
              data: (tasks) {
                if (isTrash) return _TrashList(tasks: tasks);
                final shown = starOnly
                    ? tasks.where((t) => t.starred).toList()
                    : tasks;
                return PendingCompletedList(
                  tasks: shown,
                  emptyState: EmptyState(
                    icon: AppIcons.svgIcon(AppIcons.inbox, size: 36),
                    title: starOnly ? '没有星标任务' : '还没有任务',
                    subtitle: starOnly
                        ? '点亮任务的 ⭐ 即可在这里聚焦。'
                        : '从下方输入框创建，或从其他清单移入。',
                  ),
                );
              },
            ),
          ),
        ),

        if (canQuickCreate)
          QuickCreateInput(
            hint:
                '添加任务到「${displayNameOfList(systemKind: current.systemKind, fallback: current.name)}」…',
            onSubmit: (title) => ref
                .read(taskRepositoryProvider)
                .createTask(listId: current.id, title: title),
            onSubmitCapture: (r) => ref
                .read(taskRepositoryProvider)
                .createTask(
                  listId: current.id,
                  title: r.title,
                  dueAt: r.dueAt,
                  remindAt: r.remindAt,
                  repeatRule: r.repeatRuleBody,
                ),
          ),
      ],
    );
  }
}

/// 列表顶部的 ⭐ 仅星标筛选条。
class _StarFilterBar extends ConsumerWidget {
  const _StarFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starOnly = ref.watch(listStarFilterProvider);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.base,
          Spacing.xs,
          Spacing.base,
          0,
        ),
        child: FilterChip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(
            starOnly ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: starOnly
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          label: const Text('仅星标'),
          labelStyle: theme.textTheme.labelMedium,
          selected: starOnly,
          showCheckmark: false,
          onSelected: (v) =>
              ref.read(listStarFilterProvider.notifier).state = v,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Trash — 扁平列表,不区分已完成/未完成
// ─────────────────────────────────────────────────────────────────────

class _TrashList extends ConsumerWidget {
  const _TrashList({required this.tasks});

  /// 用户单独删除的任务。随清单级联删除的任务不在此列——它们跟着清单条目
  /// 整体还原,不单独露出。
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref
        .watch(trashedListsProvider)
        .maybeWhen(data: (d) => d, orElse: () => const <TaskList>[]);

    if (tasks.isEmpty && lists.isEmpty) {
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
                subtitle: '被删除的任务与清单会出现在这里。',
              ),
            ),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // 清单在前、任务在后。清单条目代表「一整个清单连同它的内容」,还原它
    // 会把当初随它一起删掉的子清单与任务一并带回来。
    final items = <Widget>[
      if (lists.isNotEmpty) ...[
        _TrashSectionHeader(text: '已删除的清单 (${lists.length})'),
        for (final list in lists) _TrashedListTile(list: list),
      ],
      if (tasks.isNotEmpty) ...[
        _TrashSectionHeader(text: '已删除的任务 (${tasks.length})'),
        for (final task in tasks) _trashedTaskTile(ref, scheme, task),
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  Widget _trashedTaskTile(WidgetRef ref, ColorScheme scheme, Task task) {
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
  }
}

class _TrashSectionHeader extends StatelessWidget {
  const _TrashSectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.sm,
        Spacing.base,
        Spacing.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.outline,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 回收站里的一条清单。右滑还原(连同随它一起删掉的子清单与任务),
/// 左滑永久删除(不可逆,单独确认)。
class _TrashedListTile extends ConsumerWidget {
  const _TrashedListTile({required this.list});

  final TaskList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dismissible(
      key: ValueKey('trash-list-${list.id}'),
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
        final repo = ref.read(listRepositoryProvider);
        if (direction == DismissDirection.startToEnd) {
          await repo.restore(list);
          return false; // 流会自动更新列表
        }
        final confirmed = await _confirmPurge(context);
        if (confirmed) await repo.hardDelete(list);
        return false;
      },
      child: ListTile(
        leading: AppIcons.svgIcon(AppIcons.list),
        title: Text(list.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '清单 · 其中的任务会一起还原',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      ),
    );
  }

  Future<bool> _confirmPurge(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.error,
              size: 32,
            ),
            title: const Text('永久删除清单?'),
            content: Text('「${list.name}」及其中的所有任务将被彻底删除,无法恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('永久删除'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
