import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任务详情面板内的子任务区。
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
    final scheme = theme.colorScheme;
    final subtasksAsync = ref.watch(subtasksOfProvider(widget.parent.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        subtasksAsync.when(
          loading: () => Row(
            children: [
              AppIcons.svgIcon(AppIcons.subtask, size: 18),
              const SizedBox(width: Spacing.sm),
              Text('子任务', style: theme.textTheme.labelLarge),
            ],
          ),
          error: (e, st) => Text('Failed to load: $e'),
          data: (subs) {
            final total = subs.length;
            final done = subs.where((s) => s.completedAt != null).length;
            return Row(
              children: [
                AppIcons.svgIcon(AppIcons.subtask, size: 18),
                const SizedBox(width: Spacing.sm),
                Text('子任务', style: theme.textTheme.labelLarge),
                if (total > 0) ...[
                  const SizedBox(width: Spacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: done == total && total > 0
                          ? scheme.primary.withValues(alpha: 0.15)
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(Radii.circle),
                    ),
                    child: Text(
                      '$done/$total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: done == total && total > 0
                            ? scheme.primary
                            : scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: Spacing.sm),
        subtasksAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, __) => const SizedBox.shrink(),
          data: (subs) {
            if (subs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Text(
                  '暂无子任务',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
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
          padding: const EdgeInsets.only(top: Spacing.sm),
          child: Row(
            children: [
              AppIcons.svgIcon(AppIcons.add, size: 18),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_submitting,
                  onSubmitted: (_) => _submit(),
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: '添加子任务',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.outline,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: Spacing.sm,
                    ),
                  ),
                ),
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
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.chip),
      onTap: () => ref.read(selectedTaskIdProvider.notifier).select(sub.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.xs + 2,
          horizontal: Spacing.xs,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => ref
                  .read(taskRepositoryProvider)
                  .setCompleted(sub.id, completed: !done),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? scheme.primary : Colors.transparent,
                  border: Border.all(
                    color: done ? scheme.primary : scheme.outline,
                    width: 1.5,
                  ),
                ),
                child: done
                    ? AppIcons.svgIcon(AppIcons.check, size: 14)
                    : null,
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                sub.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? scheme.outline : null,
                  decorationColor: scheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
