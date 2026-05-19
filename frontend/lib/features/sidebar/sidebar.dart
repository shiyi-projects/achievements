import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:achievements/state/expanded_folders.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左侧导航栏。
///
/// 段落:
///   1. 品牌 Header
///   2. System 清单(7 个内置)
///   3. Folders + 各文件夹下的清单(可折叠;长按文件夹改 / 删)
///   4. 根目录用户清单(folder_id IS NULL)
///   5. 末尾 "+ New list" 与 "+ New folder" 入口
///   6. 底部设置占位
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
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
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

          return Column(
            children: [
              // ── Brand Header ──
              const _BrandHeader(),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              // ── Content ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  children: [
                    // ── System lists ──
                    for (final list in systemLists)
                      _SidebarTile(
                        list: list,
                        icon: _systemIcon(
                          SystemListKind.fromValue(list.systemKind),
                        ),
                        selected: list.id == currentId,
                      ),

                    // ── Separator ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.lg,
                        Spacing.base,
                        Spacing.base,
                        Spacing.sm,
                      ),
                      child: Text(
                        'LISTS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.outline,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    // ── Folders ──
                    for (final folder in folders)
                      _FolderGroup(
                        folder: folder,
                        lists: byFolder[folder.id] ?? const [],
                        isExpanded: expanded.contains(folder.id),
                        currentId: currentId,
                      ),

                    // ── Root lists ──
                    for (final list in rootLists)
                      _SidebarTile(
                        list: list,
                        icon: Icons.format_list_bulleted_rounded,
                        selected: list.id == currentId,
                      ),

                    // ── Create actions ──
                    const _NewListTile(),
                    const _NewFolderTile(),

                    if (folders.isEmpty && rootLists.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.lg,
                          Spacing.xs,
                          Spacing.base,
                          Spacing.sm,
                        ),
                        child: Text(
                          'No custom lists yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── Bottom Settings ──
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              const _SettingsTile(),
            ],
          );
        },
      ),
    );
  }

  IconData _systemIcon(SystemListKind? kind) {
    switch (kind) {
      case SystemListKind.inbox:
        return Icons.inbox_rounded;
      case SystemListKind.today:
        return Icons.today_rounded;
      case SystemListKind.important:
        return Icons.star_rounded;
      case SystemListKind.planned:
        return Icons.event_rounded;
      case SystemListKind.all:
        return Icons.checklist_rounded;
      case SystemListKind.completed:
        return Icons.task_alt_rounded;
      case SystemListKind.trash:
        return Icons.delete_outline_rounded;
      case null:
        return Icons.list_alt_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Brand Header
// ─────────────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xl,
        Spacing.base,
        Spacing.base,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              'Achievements',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Folder Group
// ─────────────────────────────────────────────────────────────────────

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
              child: _SidebarTile(
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
            content: Text(
              'Folder "${folder.name}" will be deleted. Lists inside will '
              'be moved to root and will not be lost.',
            ),
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

// ─────────────────────────────────────────────────────────────────────
// Sidebar Tile
// ─────────────────────────────────────────────────────────────────────

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final countAsync = ref.watch(taskCountForListIdProvider(list.id));
    final count = countAsync.maybeWhen(data: (n) => n, orElse: () => 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 1),
      child: GestureDetector(
        onSecondaryTapDown: (d) => _showMenu(context, ref, d.globalPosition),
        onLongPress: () => _showMenu(context, ref, null),
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.input),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.input),
            onTap: () {
              ref.read(selectedListIdProvider.notifier).select(list.id);
              final scaffold = Scaffold.maybeOf(context);
              if ((scaffold?.hasDrawer ?? false) && scaffold!.isDrawerOpen) {
                Navigator.of(context).pop();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm + 2,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      list.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? scheme.onSecondaryContainer
                            : scheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (count > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.onSecondaryContainer.withValues(
                                alpha: 0.12,
                              )
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(Radii.circle),
                      ),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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
            content: Text('List "$name" and its tasks will be moved to Trash.'),
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

// ─────────────────────────────────────────────────────────────────────
// Create Tiles
// ─────────────────────────────────────────────────────────────────────

class _NewListTile extends ConsumerWidget {
  const _NewListTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.add_rounded,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'New list',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: () async {
          final name = await showNameInputDialog(
            context,
            title: 'New list',
            confirm: 'Create',
          );
          if (name == null) return;
          await ref.read(listRepositoryProvider).create(name: name);
        },
      ),
    );
  }
}

class _NewFolderTile extends ConsumerWidget {
  const _NewFolderTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.create_new_folder_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'New folder',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: () async {
          final name = await showNameInputDialog(
            context,
            title: 'New folder',
            confirm: 'Create',
          );
          if (name == null) return;
          await ref.read(folderRepositoryProvider).create(name: name);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Settings Tile (placeholder)
// ─────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.sm,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.settings_rounded,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          'Settings',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () {
          // Phase 4: navigate to settings
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────

class _SidebarError extends StatelessWidget {
  const _SidebarError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.base),
      child: Text(
        'Failed to load sidebar: $message',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
