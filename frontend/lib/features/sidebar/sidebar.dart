import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/features/sidebar/widgets/brand_header.dart';
import 'package:achievements/features/sidebar/widgets/create_tiles.dart';
import 'package:achievements/features/sidebar/widgets/folder_group.dart';
import 'package:achievements/features/sidebar/widgets/sidebar_tile.dart';
import 'package:achievements/features/sidebar/widgets/view_nav_tile.dart';
import 'package:achievements/state/current_view.dart';
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
    final currentView = ref.watch(currentViewNotifierProvider);
    final viewNotifier = ref.read(currentViewNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: allLists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => SidebarError(message: e.toString()),
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
              const BrandHeader(),
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
                      SidebarTile(
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

                    // ── Top-level view nav entries ──
                    ViewNavTile(
                      icon: AppIcons.svgIcon(AppIcons.calendar),
                      label: '日历',
                      selected: currentView == AppView.calendar,
                      onTap: viewNotifier.showCalendar,
                    ),
                    ViewNavTile(
                      icon: AppIcons.svgIcon(AppIcons.focusTimer),
                      label: '专注',
                      selected: currentView == AppView.focus,
                      onTap: viewNotifier.showFocus,
                    ),
                    ViewNavTile(
                      icon: AppIcons.svgIcon(AppIcons.stats),
                      label: '统计',
                      selected: currentView == AppView.statistics,
                      onTap: viewNotifier.showStatistics,
                    ),
                    ViewNavTile(
                      icon: AppIcons.svgIcon(AppIcons.achievement),
                      label: '成就',
                      selected: currentView == AppView.achievement,
                      onTap: viewNotifier.showAchievement,
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
                      FolderGroup(
                        folder: folder,
                        lists: byFolder[folder.id] ?? const [],
                        isExpanded: expanded.contains(folder.id),
                        currentId: currentId,
                      ),

                    // ── Root lists — DragTarget 接收从文件夹拖出的清单 ──
                    DragTarget<TaskList>(
                      onWillAcceptWithDetails: (details) =>
                          details.data.folderId != null,
                      onAcceptWithDetails: (details) {
                        ref
                            .read(listRepositoryProvider)
                            .setFolder(details.data.id, null);
                      },
                      builder: (ctx, candidateItems, _) {
                        final over = candidateItems.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: over
                              ? const EdgeInsets.symmetric(
                                  horizontal: Spacing.sm,
                                  vertical: Spacing.xs,
                                )
                              : EdgeInsets.zero,
                          decoration: over
                              ? BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.35),
                                  borderRadius:
                                      BorderRadius.circular(Radii.input),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                )
                              : null,
                          child: Column(
                            children: [
                              for (final list in rootLists)
                                SidebarTile(
                                  list: list,
                                  icon: AppIcons.svgIcon(AppIcons.list),
                                  selected: list.id == currentId,
                                ),
                              if (over && rootLists.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(Spacing.sm),
                                  child: Text(
                                    '松开移出文件夹',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // ── Create actions ──
                    const NewItemTile(),

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
              const SettingsTile(),
            ],
          );
        },
      ),
    );
  }

  Widget _systemIcon(SystemListKind? kind) {
    final path = switch (kind) {
      SystemListKind.inbox => AppIcons.inbox,
      SystemListKind.today => AppIcons.today,
      SystemListKind.important => AppIcons.important,
      SystemListKind.planned => AppIcons.planned,
      SystemListKind.all => AppIcons.allTasks,
      SystemListKind.completed => AppIcons.completed,
      SystemListKind.trash => AppIcons.delete,
      null => AppIcons.list,
    };
    return AppIcons.svgIcon(path);
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
