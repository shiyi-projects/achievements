import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 清单选择下拉菜单，显示当前所属清单并支持切换。
class ListDropdown extends ConsumerWidget {
  const ListDropdown({
    required this.currentListId,
    required this.onChanged,
    super.key,
  });
  final String currentListId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lists = ref.watch(movableListsProvider);
    final folders = ref
        .watch(allFoldersProvider)
        .maybeWhen(data: (d) => d, orElse: () => const <Folder>[]);
    final currentName =
        lists
            .where((l) => l.id == currentListId)
            .map((l) => l.name)
            .firstOrNull ??
        '—';

    final inbox = lists.where((l) => l.isSystem).toList();
    final rootLists =
        lists.where((l) => !l.isSystem && l.folderId == null).toList();
    final folderIds = folders.map((f) => f.id).toSet();
    final byFolder = <String, List<TaskList>>{};
    for (final l in lists.where((l) => !l.isSystem && l.folderId != null)) {
      if (folderIds.contains(l.folderId)) {
        byFolder.putIfAbsent(l.folderId!, () => []).add(l);
      } else {
        rootLists.add(l);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.base),
          Expanded(
            child: PopupMenuButton<String>(
              initialValue: currentListId,
              onSelected: (id) {
                if (id != currentListId) onChanged(id);
              },
              offset: const Offset(0, 36),
              constraints:
                  const BoxConstraints(maxHeight: 400, minWidth: 200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.input),
              ),
              itemBuilder: (_) => [
                for (final l in inbox) _buildItem(l, scheme),
                for (final l in rootLists) _buildItem(l, scheme),
                for (final folder in folders) ...[
                  if (byFolder.containsKey(folder.id)) ...[
                    PopupMenuItem<String>(
                      enabled: false,
                      height: 32,
                      child: Text(
                        folder.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    for (final l in byFolder[folder.id]!)
                      _buildItem(l, scheme, indent: true),
                  ],
                ],
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        currentName,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 16,
                      color: scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildItem(
    TaskList l,
    ColorScheme scheme, {
    bool indent = false,
  }) {
    return PopupMenuItem<String>(
      value: l.id,
      child: Padding(
        padding: EdgeInsets.only(left: indent ? Spacing.base : 0),
        child: Row(
          children: [
            Icon(
              l.isSystem
                  ? Icons.inbox_rounded
                  : Icons.format_list_bulleted_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.md),
            Flexible(child: Text(l.name, overflow: TextOverflow.ellipsis)),
            if (l.id == currentListId)
              Icon(Icons.check_rounded, size: 18, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
