import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 专注会话关联任务显示与选择区域。
///
/// - 已关联任务时：显示任务标题 + 清除按钮
/// - 未关联且有当前选中任务时：显示「关联当前任务」提示
/// - 无关联 + 无选中：显示「关联任务」占位按钮（Phase 4 实现选取逻辑）
class TaskPicker extends ConsumerWidget {
  const TaskPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(focusTimerProvider);
    final notifier = ref.read(focusTimerProvider.notifier);
    final currentTaskAsync = ref.watch(currentTaskProvider);

    final associatedId = timerState.taskId;

    // 已关联任务 → 尝试显示标题
    if (associatedId != null) {
      final title = currentTaskAsync.maybeWhen(
        data: (task) => task?.id == associatedId ? task?.title : null,
        orElse: () => null,
      );
      return _AssociatedRow(
        title: title ?? associatedId,
        onClear: () => notifier.setTask(null),
      );
    }

    // 未关联，但当前有选中任务 → 提示快速关联
    final currentTask = currentTaskAsync.maybeWhen(
      data: (t) => t,
      orElse: () => null,
    );
    if (currentTask != null) {
      return _SuggestRow(
        taskTitle: currentTask.title,
        onAssociate: () => notifier.setTask(currentTask.id),
      );
    }

    // 无任何任务可关联 → 占位按钮
    return _EmptyRow();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AssociatedRow extends StatelessWidget {
  const _AssociatedRow({required this.title, required this.onClear});
  final String title;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              '关联任务：$title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
            color: scheme.onSurfaceVariant,
            tooltip: '取消关联',
          ),
        ],
      ),
    );
  }
}

class _SuggestRow extends StatelessWidget {
  const _SuggestRow({required this.taskTitle, required this.onAssociate});
  final String taskTitle;
  final VoidCallback onAssociate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.link_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              taskTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: Spacing.xs),
          TextButton(
            onPressed: onAssociate,
            child: const Text('关联此任务'),
          ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          Icon(
            Icons.link_off_rounded,
            size: 18,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: Spacing.xs),
          TextButton(
            // Phase 4 实现：打开任务选择器
            onPressed: null,
            child: Text(
              '关联任务',
              style: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
