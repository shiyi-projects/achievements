import 'package:achievements/data/repositories/tag_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任务详情面板内的标签编辑区。
///
/// - 显示用户所有 active 标签为 FilterChip,已分配给当前任务的标记为 selected
/// - tap chip 切换 add/remove 关联
/// - 末尾 ActionChip "+ New" 弹 dialog 创建新标签并自动关联
/// - 空态(无标签库)时引导 "+ New"
class TagEditor extends ConsumerWidget {
  const TagEditor({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allTagsProvider);
    final mineAsync = ref.watch(tagsForTaskProvider(taskId));

    return allAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, st) => Text('标签加载失败:$e'),
      data: (allTags) {
        final mine = mineAsync.maybeWhen(
          data: (list) => list.map((t) => t.id).toSet(),
          orElse: () => const <String>{},
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.label_outline,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in allTags)
                    FilterChip(
                      label: Text(tag.name),
                      selected: mine.contains(tag.id),
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
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('New'),
                    onPressed: () => _showCreate(context, ref),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (created == null || created.isEmpty) return;
    final repo = ref.read(tagRepositoryProvider);
    final tagId = await repo.create(created);
    await repo.addToTask(taskId, tagId);
  }
}
