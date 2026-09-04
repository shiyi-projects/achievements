import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/models/list_tree.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/features/sidebar/widgets/brand_header.dart';
import 'package:achievements/features/sidebar/widgets/create_tiles.dart';
import 'package:achievements/features/sidebar/widgets/list_tree_tile.dart';
import 'package:achievements/features/sidebar/widgets/sidebar_tile.dart';
import 'package:achievements/features/sidebar/widgets/view_nav_tile.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/expanded_lists.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左侧导航栏。
///
/// 段落:
///   1. 品牌 Header
///   2. 顶部导航(系统清单 + 视图入口合并,按使用频次从高到低排列)
///   3. 清单树 —— 用户清单的一棵自引用树,任意一级都能装任务与子清单;
///      行间的细落点用于排序,行本身是「成为子清单」的落点
///   4. 末尾「+ 新建清单」入口
///   5. 底部设置
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLists = ref.watch(allListsProvider);
    final expanded = ref.watch(expandedListsProvider);
    final currentView = ref.watch(currentViewNotifierProvider);
    final viewNotifier = ref.read(currentViewNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: allLists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => SidebarError(message: e.toString()),
        data: (lists) {
          final systemByKind = <String, TaskList>{
            for (final l in lists.where((l) => l.isSystem)) l.systemKind!: l,
          };
          final tree = buildListTree(lists);
          final rows = flattenTree(tree, expanded);

          // ── 顶部导航:系统清单 + 视图入口合并,按使用频次从高到低排列 ──
          // 导航收敛(见 dev_docs/recurring-tasks.md §8.1):
          // - 「计划」并入日历——日历虚拟展开重复任务,已完整覆盖「未来有排期」
          //   语义,故从侧边栏隐藏 planned(DB/同步不动)。
          // - 「重要」改为列表内 ⭐ 筛选开关,亦从侧边栏隐藏。
          // 系统清单相对顺序: 今天 > 收件箱 > 全部 > 已完成 > 回收站
          SystemListTile? systemTile(SystemListKind kind) {
            final list = systemByKind[kind.value];
            if (list == null) return null;
            return SystemListTile(list: list, icon: _systemIcon(kind));
          }

          final topNav = <Widget?>[
            systemTile(SystemListKind.today),
            systemTile(SystemListKind.inbox),
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
            systemTile(SystemListKind.all),
            ViewNavTile(
              icon: AppIcons.svgIcon(AppIcons.achievement),
              label: '成就',
              selected: currentView == AppView.insights,
              onTap: viewNotifier.showInsights,
            ),
            systemTile(SystemListKind.completed),
            systemTile(SystemListKind.trash),
          ].whereType<Widget>().toList();

          return Column(
            children: [
              const BrandHeader(),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  children: [
                    ...topNav,
                    _SectionLabel(text: '清单'),

                    // ── 清单树 ──
                    for (final row in rows) ...[
                      // 拖到这条线上 = 插到该行之前的同级位置。
                      ListInsertionSlot(
                        parentId: row.parentId,
                        index: row.siblingIndex,
                        depth: row.depth - 1,
                      ),
                      ListTreeTile(row: row),
                    ],
                    // 顶层末尾落点(也承担「从子清单里拖出来」的去处)。
                    ListInsertionSlot(
                      parentId: null,
                      index: tree.length,
                      depth: 0,
                    ),

                    const NewListTile(),

                    if (rows.isEmpty)
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.base,
        Spacing.base,
        Spacing.sm,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.outline,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
