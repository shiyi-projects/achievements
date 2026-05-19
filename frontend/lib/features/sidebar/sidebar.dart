import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左侧导航栏。
///
/// Phase 1 step 1:只读渲染,分两段:
///   1. System(Today / Important / Planned / All / Completed / Trash)
///   2. Lists(用户自定义清单)
///
/// 文件夹分组与拖拽排序见后续 commit。
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLists = ref.watch(allListsProvider);
    final allFolders = ref.watch(allFoldersProvider);

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
              for (final list in systemLists) _SystemListTile(list: list),
              if (folders.isNotEmpty || userLists.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
                  child: Text(
                    'Lists',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              for (final list in userLists) _UserListTile(list: list),
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
}

class _SystemListTile extends StatelessWidget {
  const _SystemListTile({required this.list});

  final TaskList list;

  @override
  Widget build(BuildContext context) {
    final kind = SystemListKind.fromValue(list.systemKind);
    return ListTile(
      dense: true,
      leading: Icon(_iconFor(kind), size: 20),
      title: Text(list.name),
      onTap: () {
        // Phase 1 step 2:把选中态写入 selectedListProvider,主视图据此刷新
      },
    );
  }

  IconData _iconFor(SystemListKind? kind) {
    switch (kind) {
      case SystemListKind.today:
        return Icons.today_outlined;
      case SystemListKind.important:
        return Icons.star_outline;
      case SystemListKind.planned:
        return Icons.event_outlined;
      case SystemListKind.all:
        return Icons.inbox_outlined;
      case SystemListKind.completed:
        return Icons.check_circle_outline;
      case SystemListKind.trash:
        return Icons.delete_outline;
      case null:
        return Icons.list_alt_outlined;
    }
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({required this.list});

  final TaskList list;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.list_outlined, size: 20),
      title: Text(list.name),
      onTap: () {
        // Phase 1 step 2:同上
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
