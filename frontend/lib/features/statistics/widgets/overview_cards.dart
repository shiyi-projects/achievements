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
    final isLight = scheme.brightness == Brightness.light;

    // ── 紧凑单行四宫格 ──
    return Row(
      children: [
        Expanded(
          child: _CompactStatCard(
            index: 0,
            icon: AppIcons.svgIcon(AppIcons.completed, size: 16),
            label: '累计完成',
            value: totalCompleted,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? [const Color(0xFF6C63FF), const Color(0xFF9B8FFF)]
                  : [const Color(0xFF8B7FFF), const Color(0xFF6C63FF)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            index: 1,
            icon: AppIcons.svgIcon(AppIcons.today, size: 16),
            label: '今日完成',
            value: todayCompleted,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? [const Color(0xFFFF6B6B), const Color(0xFFFF9A8B)]
                  : [const Color(0xFFFF8A80), const Color(0xFFFF6B6B)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            index: 2,
            icon: AppIcons.svgIcon(AppIcons.streak, size: 16),
            label: '连续天数',
            value: streakDays,
            suffix: '天',
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? [const Color(0xFFFF9F43), const Color(0xFFFFC568)]
                  : [const Color(0xFFFFB347), const Color(0xFFFF9F43)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _CompactStatCard(
            index: 3,
            icon: AppIcons.svgIcon(AppIcons.focusTimer, size: 16),
            label: '累计专注',
            value: totalFocusMinutes,
            formatter: _formatMinutes,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? [const Color(0xFF2ED8A3), const Color(0xFF6EEFC0)]
                  : [const Color(0xFF4ADBB0), const Color(0xFF2ED8A3)],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatMinutes(int v) {
    if (v < 60) return '${v}m';
    final h = v ~/ 60;
    final m = v % 60;
    return m == 0 ? '${h}h' : '${h}h${m}m';
  }
}

class _CompactStatCard extends StatelessWidget {
  const _CompactStatCard({
    required this.index,
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    this.suffix = '',
    this.formatter,
  });

  final int index;
  final Widget icon;
  final String label;
  final int value;
  final Gradient gradient;
  final String suffix;
  final String Function(int)? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: (gradient as LinearGradient).colors.first.withValues(
                  alpha: isLight ? 0.25 : 0.15,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: icon,
                ),
              ),
              const SizedBox(height: 10),
              // Value
              formatter != null
                  ? Text(
                      formatter!(value),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    )
                  : AnimatedCounter(
                      value: value,
                      suffix: suffix,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
              const SizedBox(height: 2),
              // Label
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(
          duration: MotionDurations.normal,
          delay: Duration(milliseconds: 80 * index),
        )
        .slideY(
          begin: 0.08,
          duration: MotionDurations.normal,
          delay: Duration(milliseconds: 80 * index),
          curve: MotionCurves.emphasizedDecelerate,
        );
  }
}
