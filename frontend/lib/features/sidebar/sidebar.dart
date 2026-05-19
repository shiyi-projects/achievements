import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左侧导航栏。
///
/// - System 段:7 个内置清单(inbox/today/important/planned/all/completed/trash)
/// - Lists 段:用户自定义清单,末尾 "+ New list" 按钮;长按 / 右键弹菜单
///   Rename / Delete。
/// - 文件夹分组渲染下次 commit 接入,本轮先平铺显示。
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLists = ref.watch(allListsProvider);
    final allFolders = ref.watch(allFoldersProvider);
    final currentAsync = ref.watch(currentListProvider);
    final currentId = currentAsync.maybeWhen(
      data: (list) => list?.id,
      orElse: () => null,
    );

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: allLists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _SidebarError(message: e.toString()),
        data: (lists) {
          final systemLists = lists.where((l) => l.isSystem).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final userLists = lists.where((l) => !l.isSystem).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final folders = allFolders.maybeWhen(
            data: (data) => data,
            orElse: () => const <Folder>[],
          );

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final list in systemLists)
                _SidebarTile(
                  list: list,
                  icon: _systemIcon(SystemListKind.fromValue(list.systemKind)),
                  selected: list.id == currentId,
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Text(
                  'Lists',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final list in userLists)
                _SidebarTile(
                  list: list,
                  icon: Icons.list_outlined,
                  selected: list.id == currentId,
                ),
              _NewListTile(),
              if (folders.isEmpty && userLists.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 16, 8),
                  child: Text(
                    'No custom lists yet',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _systemIcon(SystemListKind? kind) {
    switch (kind) {
      case SystemListKind.inbox:
        return Icons.inbox_outlined;
      case SystemListKind.today:
        return Icons.today_outlined;
      case SystemListKind.important:
        return Icons.star_outline;
      case SystemListKind.planned:
        return Icons.event_outlined;
      case SystemListKind.all:
        return Icons.all_inbox_outlined;
      case SystemListKind.completed:
        return Icons.check_circle_outline;
      case SystemListKind.trash:
        return Icons.delete_outline;
      case null:
        return Icons.list_alt_outlined;
    }
  }
}

class _SidebarTile extends ConsumerWidget {
  const _SidebarTile({
    required this.list,
    required this.icon,
    required this.selected,
  });

  final TaskList list;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = selected ? Theme.of(context).colorScheme.primary : null;
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showMenu(context, ref, details.globalPosition),
      onLongPress: () => _showMenu(context, ref, null),
      child: ListTile(
        dense: true,
        selected: selected,
        leading: Icon(icon, size: 20, color: color),
        title: Text(list.name, style: TextStyle(color: color)),
        onTap: () {
          ref.read(selectedListIdProvider.notifier).select(list.id);
          final scaffold = Scaffold.maybeOf(context);
          if ((scaffold?.hasDrawer ?? false) && scaffold!.isDrawerOpen) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset? position,
  ) async {
    if (list.isSystem) return; // 系统清单不允许改
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final anchor = position ?? overlay.localToGlobal(Offset.zero);
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchor.dx,
        anchor.dy,
        overlay.size.width - anchor.dx,
        overlay.size.height - anchor.dy,
      ),
      items: const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    if (!context.mounted) return;
    switch (selection) {
      case 'rename':
        final name = await showNameInputDialog(
          context,
          title: 'Rename list',
          initial: list.name,
        );
        if (name != null && name != list.name) {
          await ref.read(listRepositoryProvider).rename(list.id, name);
        }
      case 'delete':
        final confirmed = await _confirmDelete(context, list.name);
        if (confirmed) {
          await ref.read(listRepositoryProvider).softDelete(list);
        }
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete list?'),
            content: Text('清单 "$name" 及其中任务将被移到 Trash。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
                  backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _NewListTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.add, size: 20),
      title: const Text('New list'),
      onTap: () async {
        final name = await showNameInputDialog(
          context,
          title: 'New list',
          confirm: 'Create',
        );
        if (name == null) return;
        await ref.read(listRepositoryProvider).create(name: name);
      },
    );
  }
}

class _SidebarError extends StatelessWidget {
  const _SidebarError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Sidebar 加载失败:$message',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
