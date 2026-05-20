import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/shared/animations/animated_list_item.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OverviewCards extends StatelessWidget {
  const OverviewCards({
    required this.totalCompleted,
    required this.todayCompleted,
    required this.streakDays,
    required this.totalFocusMinutes,
    super.key,
  });

  final int totalCompleted;
  final int todayCompleted;
  final int streakDays;
  final int totalFocusMinutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          index: 0,
          icon: AppIcons.svgIcon(AppIcons.completed, size: 18),
          label: '累计完成',
          value: totalCompleted,
          color: scheme.primary,
        ),
        _StatCard(
          index: 1,
          icon: AppIcons.svgIcon(AppIcons.today, size: 18),
          label: '今日完成',
          value: todayCompleted,
          color: scheme.secondary,
        ),
        _StatCard(
          index: 2,
          icon: AppIcons.svgIcon(AppIcons.streak, size: 18),
          label: '连续天数',
          value: streakDays,
          suffix: ' 天',
          color: scheme.tertiary,
        ),
        _StatCard(
          index: 3,
          icon: AppIcons.svgIcon(AppIcons.focusTimer, size: 18),
          label: '累计专注',
          value: totalFocusMinutes,
          formatter: (v) => '${v ~/ 60}h ${v % 60}m',
          color: scheme.primary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.index,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
    this.formatter,
  });

  final int index;
  final Widget icon;
  final String label;
  final int value;
  final Color color;
  final String suffix;
  final String Function(int)? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isLight ? 0.12 : 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: icon,
            ),
            const Spacer(),
            // ── Animated counter ──
            formatter != null
                ? AnimatedCounter(
                    value: value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    prefix: '',
                    suffix: '',
                  )
                : AnimatedCounter(
                    value: value,
                    suffix: suffix,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: MotionDurations.normal,
          delay: Duration(milliseconds: 100 * index),
        )
        .slideY(
          begin: 0.05,
          duration: MotionDurations.normal,
          delay: Duration(milliseconds: 100 * index),
          curve: MotionCurves.emphasizedDecelerate,
        );
  }
}
