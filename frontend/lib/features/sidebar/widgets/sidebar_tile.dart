import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Sidebar Tile — 带动画指示条和悬停效果
// ─────────────────────────────────────────────────────────────────────

class SidebarTile extends ConsumerStatefulWidget {
  const SidebarTile({
    required this.list,
    required this.icon,
    required this.selected,
    super.key,
    this.displayName,
  });

  final TaskList list;
  final IconData icon;
  final bool selected;

  /// UI 层覆写显示名(用于系统清单中文化)。为 null 时回退到 `list.name`。
  final String? displayName;

  @override
  ConsumerState<SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends ConsumerState<SidebarTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    final countAsync = ref.watch(taskCountForListIdProvider(widget.list.id));
    final count = countAsync.maybeWhen(data: (n) => n, orElse: () => 0);

    // 背景色：选中 > 悬停 > 透明
    final bgColor = widget.selected
        ? scheme.secondaryContainer
        : _hovering
            ? (isLight
                ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
                : scheme.surfaceContainerHigh.withValues(alpha: 0.3))
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 1),
      child: GestureDetector(
        onSecondaryTapDown: (d) =>
            _showMenu(context, ref, d.globalPosition),
        onLongPress: () => _showMenu(context, ref, null),
        child: MouseRegion(
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
                onTap: () {
                  ref.read(currentViewNotifierProvider.notifier).showList();
                  ref.read(selectedListIdProvider.notifier).select(widget.list.id);
                  final scaffold = Scaffold.maybeOf(context);
                  if ((scaffold?.hasDrawer ?? false) && scaffold!.isDrawerOpen) {
                    Navigator.of(context).pop();
                  }
                },
                child: Row(
                  children: [
                    // ── 左侧指示条 ──
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
                          widget.selected ? Spacing.sm : Spacing.md,
                          Spacing.sm + 2,
                          Spacing.md,
                          Spacing.sm + 2,
                        ),
                        child: Row(
                          children: [
                            AnimatedScale(
                              scale: widget.selected ? 1.08 : 1.0,
                              duration: MotionDurations.fast,
                              curve: MotionCurves.bouncySpring,
                              child: Icon(
                                widget.icon,
                                size: 20,
                                color: widget.selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: Text(
                                widget.displayName ?? widget.list.name,
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
                            if (count > 0)
                              AnimatedContainer(
                                duration: MotionDurations.fast,
                                curve: MotionCurves.gentleSpring,
                                constraints: const BoxConstraints(minWidth: 22),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.selected
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
                                    color: widget.selected
                                        ? scheme.onSecondaryContainer
                                        : scheme.outline,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
    if (widget.list.isSystem) return;
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
          initial: widget.list.name,
        );
        if (name != null && name != widget.list.name) {
          await ref.read(listRepositoryProvider).rename(widget.list.id, name);
        }
      case 'delete':
        final confirmed = await _confirmDelete(context, widget.list.name);
        if (confirmed) {
          await ref.read(listRepositoryProvider).softDelete(widget.list);
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
