import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
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
        DragTarget<TaskList>(
          onWillAcceptWithDetails: (details) =>
              details.data.folderId != folder.id,
          onAcceptWithDetails: (details) {
            ref
                .read(listRepositoryProvider)
                .setFolder(details.data.id, folder.id);
            // 拖入后自动展开文件夹
            if (!isExpanded) {
              ref.read(expandedFoldersProvider.notifier).toggle(folder.id);
            }
          },
          builder: (ctx, candidateItems, _) {
            final over = candidateItems.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: over
                    ? theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.input),
                border: over
                    ? Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      )
                    : null,
              ),
              child: GestureDetector(
                onSecondaryTapDown: (d) =>
                    _showMenu(context, ref, d.globalPosition),
                onLongPress: () => _showMenu(context, ref, null),
                child: ListTile(
                  dense: true,
                  leading: AppIcons.svgIcon(AppIcons.folder),
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
                  onTap: () => ref
                      .read(expandedFoldersProvider.notifier)
                      .toggle(folder.id),
                ),
              ),
            );
          },
        ),
        if (isExpanded)
          for (final list in lists)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.base),
              child: SidebarTile(
                list: list,
                icon: AppIcons.svgIcon(AppIcons.list),
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
      items: [
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18),
              SizedBox(width: Spacing.md),
              Text('重命名'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: Spacing.md),
              Text(
                '删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
    if (!context.mounted) return;
    switch (selection) {
      case 'rename':
        final name = await showNameInputDialog(
          context,
          title: '重命名文件夹',
          initial: folder.name,
          icon: Icons.folder_rounded,
        );
        if (name != null && name != folder.name) {
          await ref.read(folderRepositoryProvider).rename(folder.id, name);
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.error,
              size: 32,
            ),
            title: const Text('删除文件夹?'),
            content: Text('文件夹"${folder.name}"将被删除,其中的清单会移到根目录,不会丢失。'),
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
        );
        if (confirmed ?? false) {
          await ref.read(folderRepositoryProvider).softDelete(folder);
        }
    }
  }
}
