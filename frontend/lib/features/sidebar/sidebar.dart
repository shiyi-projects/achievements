import 'package:achievements/core/constants.dart';
import 'package:achievements/core/sync/sync_engine.dart';
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
                        displayName: _systemDisplayName(
                          SystemListKind.fromValue(list.systemKind),
                          list.name,
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
                        '清单',
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
                          '还没有自定义清单',
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

  /// 系统清单的中文显示名。数据库里 seed 出的英文(Inbox / Today / …)是给同步
  /// 协议的稳定标识,UI 这一层做翻译;非系统清单走用户自定义的 [fallback]。
  String _systemDisplayName(SystemListKind? kind, String fallback) {
    switch (kind) {
      case SystemListKind.inbox:
        return '收件箱';
      case SystemListKind.today:
        return '今天';
      case SystemListKind.important:
        return '重要';
      case SystemListKind.planned:
        return '计划';
      case SystemListKind.all:
        return '全部任务';
      case SystemListKind.completed:
        return '已完成';
      case SystemListKind.trash:
        return '回收站';
      case null:
        return fallback;
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
          const _SyncStatusIndicator(),
        ],
      ),
    );
  }
}

/// 同步状态指示器。watch [SyncStatusController],按状态切 icon + tooltip。
/// syncing 状态下做一个简单的旋转动画;idle 态下显示极淡的 cloud_done 让用户
/// 知道"已同步";error / offline 用 colorScheme.error / outline 着色。
class _SyncStatusIndicator extends ConsumerStatefulWidget {
  const _SyncStatusIndicator();

  @override
  ConsumerState<_SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<_SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusControllerProvider);
    final theme = Theme.of(context);
    if (status == SyncStatus.syncing) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      if (_spin.isAnimating) _spin.stop();
    }

    final (icon, color, tooltip) = switch (status) {
      SyncStatus.idle => (
        Icons.cloud_done_rounded,
        theme.colorScheme.outline.withValues(alpha: 0.6),
        '已同步',
      ),
      SyncStatus.syncing => (
        Icons.sync_rounded,
        theme.colorScheme.primary,
        '同步中…',
      ),
      SyncStatus.error => (
        Icons.sync_problem_rounded,
        theme.colorScheme.error,
        '同步失败',
      ),
      SyncStatus.offline => (
        Icons.cloud_off_rounded,
        theme.colorScheme.outline,
        '离线,暂存本地',
      ),
    };

    final iconWidget = Icon(icon, size: 18, color: color);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: status == SyncStatus.syncing
              ? RotationTransition(turns: _spin, child: iconWidget)
              : iconWidget,
        ),
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

// ─────────────────────────────────────────────────────────────────────
// Sidebar Tile
// ─────────────────────────────────────────────────────────────────────

class _SidebarTile extends ConsumerWidget {
  const _SidebarTile({
    required this.list,
    required this.icon,
    required this.selected,
    this.displayName,
  });

  final TaskList list;
  final IconData icon;
  final bool selected;

  /// UI 层覆写显示名(用于系统清单中文化)。为 null 时回退到 `list.name`。
  final String? displayName;

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
                      displayName ?? list.name,
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
        PopupMenuItem(value: 'rename', child: Text('重命名')),
        PopupMenuItem(value: 'delete', child: Text('删除')),
      ],
    );
    if (!context.mounted) return;
    switch (selection) {
      case 'rename':
        final name = await showNameInputDialog(
          context,
          title: '重命名清单',
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
            title: const Text('删除清单?'),
            content: Text('清单"$name"及其任务将被移到回收站。'),
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
          '新建清单',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: () async {
          final name = await showNameInputDialog(
            context,
            title: '新建清单',
            confirm: '创建',
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
          '新建文件夹',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: () async {
          final name = await showNameInputDialog(
            context,
            title: '新建文件夹',
            confirm: '创建',
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
          '设置',
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
        '侧边栏加载失败:$message',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
