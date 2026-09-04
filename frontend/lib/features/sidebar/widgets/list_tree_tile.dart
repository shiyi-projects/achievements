import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/models/list_tree.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/sidebar/widgets/sidebar_tile.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/expanded_lists.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 侧栏里的一行用户清单。
///
/// 一行同时是:拖拽源、「拖到我身上 = 成为我的子清单」的落点、可展开的分支、
/// 可重命名 / 新建子清单 / 删除的菜单宿主。旧版把这些能力拆在「文件夹」和
/// 「清单」两套组件里,现在只有一套。
class ListTreeTile extends ConsumerWidget {
  const ListTreeTile({required this.row, super.key});

  final ListTreeRow row;

  TaskList get list => row.list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(allListsProvider).valueOrNull ?? const <TaskList>[];
    final expanded = ref.watch(expandedListsProvider);
    final isExpanded = expanded.contains(list.id);
    final currentId = ref
        .watch(currentListProvider)
        .maybeWhen(data: (l) => l?.id, orElse: () => null);
    final selected =
        list.id == currentId &&
        ref.watch(currentViewNotifierProvider) == AppView.list;
    final count = ref
        .watch(taskCountForListIdProvider(list.id))
        .maybeWhen(data: (n) => n, orElse: () => 0);

    final tile = SidebarTileShell(
      depth: row.depth - 1,
      icon: AppIcons.svgIcon(AppIcons.list),
      title: list.name,
      selected: selected,
      count: count,
      expander: row.hasChildren
          ? _Expander(
              expanded: isExpanded,
              onTap: () =>
                  ref.read(expandedListsProvider.notifier).toggle(list.id),
            )
          : null,
      trailing: _MenuButton(
        onPressed: (position) => _showMenu(context, ref, position),
      ),
      onContextMenu: (position) => _showMenu(context, ref, position),
      onTap: () {
        ref.read(currentViewNotifierProvider.notifier).showList();
        ref.read(selectedListIdProvider.notifier).select(list.id);
        closeDrawerIfOpen(context);
      },
    );

    // 落点:拖到本行 = 成为本行的子清单。
    final dropTarget = DragTarget<TaskList>(
      onWillAcceptWithDetails: (details) =>
          checkAttach(moving: details.data, parentId: list.id, all: all) ==
          null,
      onAcceptWithDetails: (details) async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        try {
          await ref
              .read(listRepositoryProvider)
              .moveTo(listId: details.data.id, parentId: list.id);
          ref.read(expandedListsProvider.notifier).expand(list.id);
        } on ListAttachException catch (e) {
          messenger?.showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
      builder: (ctx, candidates, _) {
        if (candidates.isEmpty) return tile;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(Radii.input),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: tile,
        );
      },
    );

    final feedback = _DragFeedback(name: list.name);
    final placeholder = Opacity(opacity: 0.4, child: tile);

    // 触屏没有右键,按下即拖会和点击 / 长按菜单打架,故改为长按启动拖拽。
    return isTouchPlatform(theme.platform)
        ? LongPressDraggable<TaskList>(
            data: list,
            feedback: feedback,
            childWhenDragging: placeholder,
            child: dropTarget,
          )
        : Draggable<TaskList>(
            data: list,
            feedback: feedback,
            childWhenDragging: placeholder,
            child: dropTarget,
          );
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset? position,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final anchor = position ?? overlay.localToGlobal(Offset.zero);
    final selection = await showMenu<_ListAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchor.dx,
        anchor.dy,
        overlay.size.width - anchor.dx,
        overlay.size.height - anchor.dy,
      ),
      items: [
        const PopupMenuItem(
          value: _ListAction.rename,
          child: _MenuRow(icon: Icons.edit_rounded, label: '重命名'),
        ),
        const PopupMenuItem(
          value: _ListAction.newChild,
          child: _MenuRow(
            icon: Icons.subdirectory_arrow_right_rounded,
            label: '在此新建子清单',
          ),
        ),
        PopupMenuItem(
          value: _ListAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: '删除',
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
    if (!context.mounted || selection == null) return;
    switch (selection) {
      case _ListAction.rename:
        final name = await showNameInputDialog(
          context,
          title: '重命名清单',
          initial: list.name,
        );
        if (name != null && name != list.name) {
          await ref.read(listRepositoryProvider).rename(list.id, name);
        }
      case _ListAction.newChild:
        final name = await showNameInputDialog(
          context,
          title: '在「${list.name}」下新建清单',
          confirm: '创建',
          icon: Icons.list_alt_rounded,
        );
        if (name == null) return;
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        try {
          await ref
              .read(listRepositoryProvider)
              .create(name: name, parentId: list.id);
          ref.read(expandedListsProvider.notifier).expand(list.id);
        } on ListAttachException catch (e) {
          messenger?.showSnackBar(SnackBar(content: Text(e.message)));
        }
      case _ListAction.delete:
        final confirmed = await _confirmDelete(context, ref);
        if (confirmed) await _delete(ref);
    }
  }

  Future<void> _delete(WidgetRef ref) async {
    // 选中的清单(或它的祖先)被删掉后,主视图不能再停在上面。
    final all = ref.read(allListsProvider).valueOrNull ?? const <TaskList>[];
    final selectedId = ref.read(selectedListIdProvider);
    if (selectedId != null && subtreeIdsOf(list.id, all).contains(selectedId)) {
      ref.read(selectedListIdProvider.notifier).clear();
    }
    await ref.read(listRepositoryProvider).softDelete(list);
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final all = ref.read(allListsProvider).valueOrNull ?? const <TaskList>[];
    final childCount = subtreeIdsOf(list.id, all).length - 1;
    final detail = childCount > 0
        ? '清单「${list.name}」、它的 $childCount 个子清单以及其中的任务会一起移到回收站,可在回收站整体还原。'
        : '清单「${list.name}」及其中的任务会移到回收站,可在回收站还原。';
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.error,
              size: 32,
            ),
            title: const Text('删除清单?'),
            content: Text(detail),
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
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

enum _ListAction { rename, newChild, delete }

class _Expander extends StatelessWidget {
  const _Expander({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.circle),
      onTap: onTap,
      child: Icon(
        expanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});

  final void Function(Offset position) onPressed;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => InkWell(
        borderRadius: BorderRadius.circular(Radii.circle),
        onTap: () {
          final box = ctx.findRenderObject()! as RenderBox;
          onPressed(box.localToGlobal(box.size.bottomLeft(Offset.zero)));
        },
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 18,
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Spacing.md),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(Radii.input),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: AppIcons.svgIcon(AppIcons.list),
            ),
            const SizedBox(width: Spacing.md),
            Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Insertion Slot — 行与行之间的插入落点
// ─────────────────────────────────────────────────────────────────────

/// 两行之间的细长落点:把清单拖到这里 = 挂到 [parentId] 下的第 [index] 位。
///
/// 「拖到行上 = 成为子清单」「拖到行间 = 排序」两个语义靠不同的落区区分,
/// 不需要在一行内部按坐标猜用户意图。
class ListInsertionSlot extends ConsumerWidget {
  const ListInsertionSlot({
    required this.parentId,
    required this.index,
    required this.depth,
    super.key,
  });

  final String? parentId;
  final int index;

  /// 缩进层级(与相邻行对齐),顶层为 0。
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(allListsProvider).valueOrNull ?? const <TaskList>[];
    return DragTarget<TaskList>(
      onWillAcceptWithDetails: (details) =>
          checkAttach(moving: details.data, parentId: parentId, all: all) ==
          null,
      onAcceptWithDetails: (details) async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        try {
          await ref
              .read(listRepositoryProvider)
              .moveTo(
                listId: details.data.id,
                parentId: parentId,
                index: index,
              );
        } on ListAttachException catch (e) {
          messenger?.showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
      builder: (ctx, candidates, _) {
        final active = candidates.isNotEmpty;
        return Padding(
          padding: EdgeInsets.only(
            left: Spacing.md + depth * Spacing.base,
            right: Spacing.sm,
          ),
          child: SizedBox(
            height: active ? 10 : 6,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: active ? 2 : 0,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
