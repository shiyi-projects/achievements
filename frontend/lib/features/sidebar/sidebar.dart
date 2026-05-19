import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:achievements/state/expanded_folders.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左侧导航栏。
///
/// 段落:
///   1. System(7 个内置清单)
///   2. Folders + 各文件夹下的清单(可折叠;长按文件夹改 / 删)
///   3. 根目录用户清单(folder_id IS NULL)
///   4. 末尾 "+ New list" 与 "+ New folder" 入口
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
    final expanded = ref.watch(expandedFoldersProvider);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: allLists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => _SidebarError(message: e.toString()),
        data: (lists) {
          final systemLists = lists.where((l) => l.isSystem).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final folders = allFolders.maybeWhen(
            data: (data) => data,
            orElse: () => const <Folder>[],
          );
          final folderIds = {for (final f in folders) f.id};
          // 用户清单按 folder_id 归桶;folder_id 未识别(或 null)的归根目录
          final byFolder = <String, List<TaskList>>{};
          final rootLists = <TaskList>[];
          for (final list in lists.where((l) => !l.isSystem)) {
            final fid = list.folderId;
            if (fid != null && folderIds.contains(fid)) {
              byFolder.putIfAbsent(fid, () => []).add(list);
            } else {
              rootLists.add(list);
            }
          }
          for (final bucket in byFolder.values) {
            bucket.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          }
          rootLists.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

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
              for (final folder in folders)
                _FolderGroup(
                  folder: folder,
                  lists: byFolder[folder.id] ?? const [],
                  isExpanded: expanded.contains(folder.id),
                  currentId: currentId,
                ),
              for (final list in rootLists)
                _SidebarTile(
                  list: list,
                  icon: Icons.list_outlined,
                  selected: list.id == currentId,
                ),
              const _NewListTile(),
              const _NewFolderTile(),
              if (folders.isEmpty && rootLists.isEmpty)
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

class _FolderGroup extends ConsumerWidget {
  const _FolderGroup({
    required this.folder,
    required this.lists,
    required this.isExpanded,
    required this.currentId,
  });

  final Folder folder;
  final List<TaskList> lists;
  final bool isExpanded;
  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        GestureDetector(
          onSecondaryTapDown: (d) => _showMenu(context, ref, d.globalPosition),
          onLongPress: () => _showMenu(context, ref, null),
          child: ListTile(
            dense: true,
            leading: Icon(
              isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 20,
            ),
            title: Text(folder.name),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            onTap: () =>
                ref.read(expandedFoldersProvider.notifier).toggle(folder.id),
          ),
        ),
        if (isExpanded)
          for (final list in lists)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _SidebarTile(
                list: list,
                icon: Icons.list_outlined,
                selected: list.id == currentId,
              ),
            ),
      ],
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
          title: 'Rename folder',
          initial: folder.name,
        );
        if (name != null && name != folder.name) {
          await ref.read(folderRepositoryProvider).rename(folder.id, name);
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete folder?'),
            content: Text('文件夹 "${folder.name}" 将被删除;其下清单移到根目录,不会丢失。'),
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
        );
        if (confirmed ?? false) {
          await ref.read(folderRepositoryProvider).softDelete(folder);
        }
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
      onSecondaryTapDown: (d) => _showMenu(context, ref, d.globalPosition),
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
    if (list.isSystem) return;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
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
  const _NewListTile();

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

class _NewFolderTile extends ConsumerWidget {
  const _NewFolderTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.create_new_folder_outlined, size: 20),
      title: const Text('New folder'),
      onTap: () async {
        final name = await showNameInputDialog(
          context,
          title: 'New folder',
          confirm: 'Create',
        );
        if (name == null) return;
        await ref.read(folderRepositoryProvider).create(name: name);
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
