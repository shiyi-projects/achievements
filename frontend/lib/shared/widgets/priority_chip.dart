import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 优先级标签:[TaskPriority.none] 时不渲染。
///
/// 配色使用 ui_design_spec §2.4 优先级色,背景 12% 透明度;
/// 圆角 8px(ui_design_spec §4.2 Chip);
/// 文字 labelMedium (12sp W500)。
class PriorityChip extends StatelessWidget {
  const PriorityChip({required this.priority, super.key});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    if (priority == TaskPriority.none) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = _color(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        priority.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _color(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return AppColors.urgent;
      case TaskPriority.medium:
        return AppColors.medium;
      case TaskPriority.low:
        return AppColors.low;
      case TaskPriority.none:
        return Colors.transparent;
    }
  }
}
