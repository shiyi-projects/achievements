import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/features/task_detail/widgets/date_helpers.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 搜索结果列表中的单条任务行。
class SearchResultTile extends ConsumerWidget {
  const SearchResultTile({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.completedAt != null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final notesPreview = _notesFirstLine(task.notes);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      leading: Icon(
        done ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: done ? scheme.primary : scheme.outline,
        size: 22,
      ),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          decoration: done ? TextDecoration.lineThrough : null,
          decorationColor: scheme.outline,
          color: done ? scheme.outline : null,
        ),
      ),
      subtitle: notesPreview != null
          ? Text(
              notesPreview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: task.dueAt != null
          ? _DateChip(date: task.dueAt!, done: done)
          : null,
      onTap: () {
        ref.read(currentViewNotifierProvider.notifier).showList();
        ref.read(selectedTaskIdProvider.notifier).select(task.id);
      },
    );
  }

  /// 取备注第一行,去除首尾空白;为空或 null 时返回 null。
  static String? _notesFirstLine(String? notes) {
    if (notes == null) return null;
    final first = notes.split('\n').first.trim();
    return first.isEmpty ? null : first;
  }
}

// ─────────────────────────────────────────────────────────────────────
// Private: due date chip
// ─────────────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.done});

  final DateTime date;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isOverdue = date.isBefore(now) && !done;
    final label = formatDateCn(date);
    final color = isOverdue ? scheme.error : scheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: isOverdue
            ? scheme.errorContainer.withValues(alpha: 0.4)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
