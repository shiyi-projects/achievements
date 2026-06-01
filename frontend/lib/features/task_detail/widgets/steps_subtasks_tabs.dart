import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/step_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/task_detail/widgets/steps_section.dart';
import 'package:achievements/features/task_detail/widgets/subtasks_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 「步骤」与「子任务」合并为同一张卡片,用 Tab 切换。
///
/// Tab 标签自带完成度徽标,故内部 Section 隐藏各自标题行。
class StepsSubtasksTabs extends ConsumerStatefulWidget {
  const StepsSubtasksTabs({required this.task, super.key});

  final Task task;

  @override
  ConsumerState<StepsSubtasksTabs> createState() => _StepsSubtasksTabsState();
}

class _StepsSubtasksTabsState extends ConsumerState<StepsSubtasksTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    // 完成度计数(供 Tab 徽标),Riverpod 复用 Section 内部已建立的订阅。
    final steps = ref
        .watch(stepsForTaskProvider(task.id))
        .maybeWhen(data: (s) => s, orElse: () => const <TaskStep>[]);
    final subs = ref
        .watch(subtasksOfProvider(task.id))
        .maybeWhen(data: (s) => s, orElse: () => const <Task>[]);

    final stepsDone = steps.where((s) => s.completedAt != null).length;
    final subsDone = subs.where((s) => s.completedAt != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tab 头 ──
        Row(
          children: [
            _TabButton(
              icon: Icons.checklist_rounded,
              label: '步骤',
              done: stepsDone,
              total: steps.length,
              selected: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _TabButton(
              icon: Icons.account_tree_rounded,
              label: '子任务',
              done: subsDone,
              total: subs.length,
              selected: _index == 1,
              onTap: () => setState(() => _index = 1),
            ),
          ],
        ),
        Divider(
          height: 1,
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: Spacing.sm),

        // ── Tab 体 ──
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _index == 0
              ? StepsSection(
                  key: const ValueKey('steps'),
                  taskId: task.id,
                  showHeader: false,
                )
              : SubtasksSection(
                  key: const ValueKey('subtasks'),
                  parent: task,
                  showHeader: false,
                ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.done,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int done;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.primary : scheme.outline;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (total > 0) ...[
                    const SizedBox(width: Spacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: done == total
                            ? scheme.primary.withValues(alpha: 0.15)
                            : scheme.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                        borderRadius: BorderRadius.circular(Radii.circle),
                      ),
                      child: Text(
                        '$done/$total',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: done == total
                              ? scheme.primary
                              : scheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Spacing.sm),
              // 选中下划线指示器
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(Radii.circle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
