import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Sidebar Tile Shell — 侧栏所有行共用的视觉外壳
//
// 选中指示条 / hover 底色 / 图标 / 标题 / 计数徽标 / 按层级缩进。系统清单、
// 用户清单、视图入口都套这一层,行与行之间不会出现细微的排版差异。
// ─────────────────────────────────────────────────────────────────────

class SidebarTileShell extends StatefulWidget {
  const SidebarTileShell({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
    this.depth = 0,
    this.expander,
    this.count = 0,
    this.trailing,
    this.onContextMenu,
  });

  final Widget icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  /// 层级缩进,0 为顶层。
  final int depth;

  /// 展开 / 折叠箭头。无子节点时传 null,占位空白由内部补齐,保证同级对齐。
  final Widget? expander;

  final int count;

  /// hover 时出现在行尾的操作入口(通常是「⋯」)。
  final Widget? trailing;

  /// 右键 / 长按唤起菜单。传 null 表示该行没有菜单。
  final void Function(Offset? globalPosition)? onContextMenu;

  @override
  State<SidebarTileShell> createState() => _SidebarTileShellState();
}

class _SidebarTileShellState extends State<SidebarTileShell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    final bgColor = widget.selected
        ? scheme.secondaryContainer
        : _hovering
        ? (isLight
              ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.3))
        : Colors.transparent;

    final onContextMenu = widget.onContextMenu;
    final row = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: MotionDurations.fast,
        curve: MotionCurves.gentleSpring,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.input),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.input),
            onTap: widget.onTap,
            child: Row(
              children: [
                // ── 左侧选中指示条 ──
                AnimatedContainer(
                  duration: MotionDurations.fast,
                  curve: MotionCurves.emphasizedDecelerate,
                  width: widget.selected ? 3 : 0,
                  height: 20,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      (widget.selected ? Spacing.sm : Spacing.md) +
                          widget.depth * Spacing.base,
                      Spacing.sm + 2,
                      Spacing.sm,
                      Spacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: _expanderWidth, child: widget.expander),
                        AnimatedScale(
                          scale: widget.selected ? 1.08 : 1.0,
                          duration: MotionDurations.fast,
                          curve: MotionCurves.bouncySpring,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: widget.icon,
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: widget.selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: widget.selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 桌面端 hover 时用操作入口顶掉计数;触屏没有 hover,
                        // 两者并排常驻,否则「⋯」永远出不来。
                        if (widget.count > 0 &&
                            !(_hovering && widget.trailing != null))
                          _CountBadge(
                            count: widget.count,
                            selected: widget.selected,
                          ),
                        if (widget.trailing != null &&
                            (_hovering || isTouchPlatform(theme.platform)))
                          widget.trailing!,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 1),
      child: onContextMenu == null
          ? row
          : GestureDetector(
              onSecondaryTapDown: (d) => onContextMenu(d.globalPosition),
              child: row,
            ),
    );
  }

  static const double _expanderWidth = 18;
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: MotionDurations.fast,
      curve: MotionCurves.gentleSpring,
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? scheme.onSecondaryContainer.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.circle),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: selected ? scheme.onSecondaryContainer : scheme.outline,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// System List Tile — 系统清单(智能过滤)入口。不可拖拽 / 重命名 / 删除。
// ─────────────────────────────────────────────────────────────────────

class SystemListTile extends ConsumerWidget {
  const SystemListTile({required this.list, required this.icon, super.key});

  final TaskList list;
  final Widget icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref
        .watch(currentListProvider)
        .maybeWhen(data: (l) => l?.id, orElse: () => null);
    final selected =
        list.id == currentId &&
        ref.watch(currentViewNotifierProvider) == AppView.list;
    final count = ref
        .watch(taskCountForListIdProvider(list.id))
        .maybeWhen(data: (n) => n, orElse: () => 0);

    return SidebarTileShell(
      icon: icon,
      title: displayNameOfList(
        systemKind: list.systemKind,
        fallback: list.name,
      ),
      selected: selected,
      count: count,
      onTap: () {
        ref.read(currentViewNotifierProvider.notifier).showList();
        ref.read(selectedListIdProvider.notifier).select(list.id);
        closeDrawerIfOpen(context);
      },
    );
  }
}

/// 触屏平台没有 hover,也没有右键——行内操作入口需要常驻,拖拽要先长按。
bool isTouchPlatform(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;

/// 移动端侧栏是 Drawer,点完条目要把它收起来。
void closeDrawerIfOpen(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  if ((scaffold?.hasDrawer ?? false) && scaffold!.isDrawerOpen) {
    Navigator.of(context).pop();
  }
}
