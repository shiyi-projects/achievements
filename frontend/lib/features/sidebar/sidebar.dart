import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左侧导航栏。
///
/// 渲染分两段:
///   1. System(inbox / today / important / planned / all / completed / trash)
///   2. Lists(用户自定义清单)
///
/// tap 任意 tile 即 dispatch [SelectedListId.select],主视图随之切换。
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
              if (folders.isNotEmpty || userLists.isNotEmpty)
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
              if (folders.isEmpty && userLists.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 16, 8),
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
    return ListTile(
      dense: true,
      selected: selected,
      leading: Icon(icon, size: 20, color: color),
      title: Text(list.name, style: TextStyle(color: color)),
      onTap: () {
        ref.read(selectedListIdProvider.notifier).select(list.id);
        // 移动端 Drawer 中 tap 后需关闭抽屉,让用户看到主视图
        final scaffold = Scaffold.maybeOf(context);
        if ((scaffold?.hasDrawer ?? false) && scaffold!.isDrawerOpen) {
          Navigator.of(context).pop();
        }
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
