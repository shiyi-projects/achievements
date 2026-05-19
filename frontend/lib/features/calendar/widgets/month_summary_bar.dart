import 'dart:math' as math;

import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/calendar/providers/calendar_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 月度统计摘要条。
///
/// 渐变卡片中展示:
/// - 圆形完成率指示器（动画）
/// - 总任务数 / 已完成数 / 有任务天数
class MonthSummaryBar extends ConsumerWidget {
  const MonthSummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(monthStatsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // 无任务时不显示
    if (stats.total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            // — Completion ring —
            _CompletionRing(
              rate: stats.completionRate,
              size: 36,
              color: scheme.primary,
              bgColor: scheme.outline.withValues(alpha: 0.12),
            ),
            const SizedBox(width: Spacing.md),

            // — Stats —
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      value: '${stats.total}',
                      label: '总任务',
                      color: scheme.onSurface,
                      icon: Icons.list_alt_rounded,
                      iconColor: scheme.primary,
                    ),
                  ),
                  _StatDivider(color: scheme.outlineVariant),
                  Expanded(
                    child: _StatItem(
                      value: '${stats.completed}',
                      label: '已完成',
                      color: scheme.primary,
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: scheme.primary,
                    ),
                  ),
                  _StatDivider(color: scheme.outlineVariant),
                  Expanded(
                    child: _StatItem(
                      value: '${stats.daysWithTasks}',
                      label: '活跃天',
                      color: scheme.tertiary,
                      icon: Icons.calendar_today_rounded,
                      iconColor: scheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Completion Ring — animated circular progress
// ─────────────────────────────────────────────────────────────────────

class _CompletionRing extends StatelessWidget {
  const _CompletionRing({
    required this.rate,
    required this.size,
    required this.color,
    required this.bgColor,
  });

  final double rate;
  final double size;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: rate),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: color,
              bgColor: bgColor,
              strokeWidth: 3.5,
            ),
            child: Center(
              child: Text(
                '${(value * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────
// Stat items
// ─────────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    required this.iconColor,
  });

  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 3),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.outline,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: color.withValues(alpha: 0.3),
    );
  }
}
