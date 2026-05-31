import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 显示任务的专注完成进度。
///
/// 展示：已专注时长 / 预估总时长 + 进度条。
/// 当 [estimatedMinutes] 为 0 或 null 时，由调用方决定不渲染此组件。
class FocusProgressRow extends StatelessWidget {
  const FocusProgressRow({
    required this.focusedSeconds,
    required this.estimatedMinutes,
    super.key,
  });

  final int focusedSeconds;
  final int estimatedMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final focusedMinutes = focusedSeconds ~/ 60;
    final progress = estimatedMinutes > 0
        ? (focusedMinutes / estimatedMinutes).clamp(0.0, 1.0)
        : 0.0;
    final isComplete = progress >= 1.0;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle_rounded : Icons.timer_outlined,
                size: 16,
                color: isComplete ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  '已专注 ${_formatMinutes(focusedMinutes)} / ${_formatMinutes(estimatedMinutes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isComplete
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight: isComplete ? FontWeight.w600 : null,
                  ),
                ),
              ),
              // 百分比标签
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isComplete
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(Radii.circle),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isComplete ? scheme.primary : scheme.outline,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.circle),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              valueColor: AlwaysStoppedAnimation(
                isComplete ? scheme.primary : scheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }
}
