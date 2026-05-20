import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/repositories/tag_repository.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任务详情面板内的标签编辑区。
///
/// - 显示所有 active 标签为 FilterChip,已关联标记 selected
/// - tap chip 切换 add/remove
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
                FilterChip(
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
}
