import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任务详情面板内的子任务区。
///
/// - 列出当前任务的直接子任务(单层),tap 钻入该子任务详情
/// - 底部输入框 Enter 即创建子任务(继承父任务的 list_id + parent_id)
class SubtasksSection extends ConsumerStatefulWidget {
  const SubtasksSection({required this.parent, super.key});

  final Task parent;

  @override
  ConsumerState<SubtasksSection> createState() => _SubtasksSectionState();
}

class _SubtasksSectionState extends ConsumerState<SubtasksSection> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(taskRepositoryProvider)
          .createTask(
            listId: widget.parent.listId,
            parentId: widget.parent.id,
            title: raw,
          );
      _controller.clear();
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtasksAsync = ref.watch(subtasksOfProvider(widget.parent.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Text('Subtasks', style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        subtasksAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, st) => Text('加载失败:$e'),
          data: (subs) {
            if (subs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '暂无子任务',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              );
            }
            return Column(
              children: [for (final sub in subs) _SubtaskRow(sub: sub)],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const Icon(Icons.add, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_submitting,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'Add subtask',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send_outlined, size: 18),
                tooltip: 'Create',
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtaskRow extends ConsumerWidget {
  const _SubtaskRow({required this.sub});

  final Task sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = sub.completedAt != null;
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: IconButton(
        icon: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: done ? theme.colorScheme.primary : null,
        ),
        onPressed: () => ref
            .read(taskRepositoryProvider)
            .setCompleted(sub.id, completed: !done),
      ),
      title: Text(
        sub.title,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? theme.colorScheme.outline : null,
        ),
      ),
      onTap: () => ref.read(selectedTaskIdProvider.notifier).select(sub.id),
    );
  }
}
