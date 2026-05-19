import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Sidebar Tile
// ─────────────────────────────────────────────────────────────────────

class SidebarTile extends ConsumerWidget {
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
              ref.read(currentViewNotifierProvider.notifier).showList();
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
