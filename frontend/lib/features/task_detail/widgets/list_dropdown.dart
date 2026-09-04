import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/models/list_tree.dart';
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
    final currentName =
        lists
            .where((l) => l.id == currentListId)
            .map((l) => l.name)
            .firstOrNull ??
        '—';

    final inbox = lists.where((l) => l.isSystem).toList();
    // 清单树全展开:选目标清单时不该还要先展开一层层父节点。
    final rows = flattenTree(buildListTree(lists), {
      for (final l in lists) l.id,
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: PopupMenuButton<String>(
        initialValue: currentListId,
        onSelected: (id) {
          if (id != currentListId) onChanged(id);
        },
        offset: const Offset(0, 36),
        constraints: const BoxConstraints(maxHeight: 400, minWidth: 200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        itemBuilder: (_) => [
          for (final l in inbox) _buildItem(l, scheme),
          for (final row in rows)
            _buildItem(row.list, scheme, depth: row.depth - 1),
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
              Icon(
                Icons.list_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(
                  currentName,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Icon(Icons.unfold_more_rounded, size: 16, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildItem(
    TaskList l,
    ColorScheme scheme, {
    int depth = 0,
  }) {
    return PopupMenuItem<String>(
      value: l.id,
      child: Padding(
        padding: EdgeInsets.only(left: depth * Spacing.base),
        child: Row(
          children: [
            Icon(
              l.isSystem ? Icons.inbox_rounded : Icons.list_rounded,
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
