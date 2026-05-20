import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// 优先级选择器 — 紧凑 ChoiceChip 行，带颜色圆点指示 + 选中弹性动效。
class PriorityChips extends StatelessWidget {
  const PriorityChips({required this.priority, required this.onChanged, super.key});
  final TaskPriority priority;
  final ValueChanged<TaskPriority> onChanged;

  static const _items = [
    (TaskPriority.none, '无', null),
    (TaskPriority.low, '低', AppColors.low),
    (TaskPriority.medium, '中', AppColors.medium),
    (TaskPriority.high, '高', AppColors.high),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          AppIcons.svgIcon(AppIcons.highPriority),
          const SizedBox(width: Spacing.base),
          Expanded(
            child: Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final (p, label, color) in _items)
                  AnimatedScale(
                    scale: priority == p ? 1.05 : 1.0,
                    duration: MotionDurations.fast,
                    curve: MotionCurves.bouncySpring,
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (color != null) ...[
                            AnimatedContainer(
                              duration: MotionDurations.fast,
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                boxShadow: priority == p
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: Spacing.xs),
                          ],
                          Text(label),
                        ],
                      ),
                      selected: priority == p,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                      selectedColor: color?.withValues(alpha: 0.15) ??
                          scheme.surfaceContainerHighest,
                      side: priority == p && color != null
                          ? BorderSide(color: color.withValues(alpha: 0.4))
                          : null,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            priority == p ? FontWeight.w600 : FontWeight.w400,
                        color: priority == p
                            ? (color ?? scheme.onSurface)
                            : scheme.onSurfaceVariant,
                      ),
                      onSelected: (_) => onChanged(p),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
