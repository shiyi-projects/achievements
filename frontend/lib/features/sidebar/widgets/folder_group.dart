import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/features/sidebar/widgets/sidebar_tile.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:achievements/state/expanded_folders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Folder Group
// ─────────────────────────────────────────────────────────────────────

class FolderGroup extends ConsumerWidget {
  const FolderGroup({
    required this.folder,
    required this.lists,
    required this.isExpanded,
    required this.currentId,
    super.key,
  });

  final Folder folder;
  final List<TaskList> lists;
  final bool isExpanded;
  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      children: [
        GestureDetector(
          onSecondaryTapDown: (d) => _showMenu(context, ref, d.globalPosition),
          onLongPress: () => _showMenu(context, ref, null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: ListTile(
              dense: true,
              leading: Icon(
                isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                folder.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: theme.colorScheme.outline,
              ),
              onTap: () =>
                  ref.read(expandedFoldersProvider.notifier).toggle(folder.id),
            ),
          ),
        ),
        if (isExpanded)
          for (final list in lists)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.base),
              child: SidebarTile(
                list: list,
                icon: Icons.format_list_bulleted_rounded,
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
        PopupMenuItem(value: 'rename', child: Text('重命名')),
        PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    );
    if (!context.mounted) return;
    switch (selection) {
      case 'rename':
        final name = await showNameInputDialog(
          context,
          title: '重命名文件夹',
          initial: folder.name,
        );
        if (name != null && name != folder.name) {
          await ref.read(folderRepositoryProvider).rename(folder.id, name);
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除文件夹?'),
            content: Text('文件夹"${folder.name}"将被删除,其中的清单会移到根目录,不会丢失。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
                  backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
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
