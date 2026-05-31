import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/tag_repository.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _TagAction { rename, delete }

/// 任务详情面板内的标签编辑区。
///
/// - 显示所有 active 标签为 FilterChip,已关联标记 selected
/// - tap chip 切换 add/remove
/// - 长按 / 右键 chip 弹菜单:重命名 / 删除标签
/// - 末尾 ActionChip "New" 弹 dialog 创建新标签并自动关联
class TagEditor extends ConsumerWidget {
  const TagEditor({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allAsync = ref.watch(allTagsProvider);
    final mineAsync = ref.watch(tagsForTaskProvider(taskId));

    return allAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.sm),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, st) => Text('Failed to load tags: $e'),
      data: (allTags) {
        final mine = mineAsync.maybeWhen(
          data: (list) => list.map((t) => t.id).toSet(),
          orElse: () => const <String>{},
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: Wrap(
            spacing: Spacing.xs + 2,
            runSpacing: Spacing.xs + 2,
            children: [
              for (final tag in allTags)
                GestureDetector(
                  onLongPressStart: (d) =>
                      _showTagMenu(context, ref, tag, d.globalPosition),
                  onSecondaryTapDown: (d) =>
                      _showTagMenu(context, ref, tag, d.globalPosition),
                  child: FilterChip(
                    label: Text(tag.name),
                    labelStyle: theme.textTheme.labelMedium,
                    selected: mine.contains(tag.id),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    onSelected: (sel) async {
                      final repo = ref.read(tagRepositoryProvider);
                      if (sel) {
                        await repo.addToTask(taskId, tag.id);
                      } else {
                        await repo.removeFromTask(taskId, tag.id);
                      }
                    },
                  ),
                ),
              ActionChip(
                avatar: AppIcons.svgIcon(AppIcons.add, size: 16),
                label: Text(
                  'New',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                onPressed: () => _showCreate(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final created = await showNameInputDialog(
      context,
      title: 'New tag',
      hint: 'Tag name',
      confirm: 'Create',
    );
    if (created == null) return;
    final repo = ref.read(tagRepositoryProvider);
    final tagId = await repo.create(created);
    await repo.addToTask(taskId, tagId);
  }

  /// 长按 / 右键标签 chip 时,在指针位置弹出"重命名 / 删除"菜单。
  Future<void> _showTagMenu(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
    Offset position,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<_TagAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(
          value: _TagAction.rename,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_rounded, size: 20),
            title: Text('重命名'),
          ),
        ),
        PopupMenuItem(
          value: _TagAction.delete,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline_rounded, size: 20),
            title: Text('删除标签'),
          ),
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _TagAction.rename:
        await _renameTag(context, ref, tag);
      case _TagAction.delete:
        await _confirmDelete(context, ref, tag);
    }
  }

  Future<void> _renameTag(BuildContext context, WidgetRef ref, Tag tag) async {
    final name = await showNameInputDialog(
      context,
      title: '重命名标签',
      hint: '标签名',
      confirm: '保存',
      initial: tag.name,
    );
    if (name == null || name == tag.name) return;
    await ref.read(tagRepositoryProvider).rename(tag.id, name);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Tag tag,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('删除标签'),
        content: Text('确定删除标签「${tag.name}」吗?它会从所有任务上移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tagRepositoryProvider).softDelete(tag.id);
  }
}
