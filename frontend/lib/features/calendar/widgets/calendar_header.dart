import 'dart:math' as math;

import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/calendar/providers/calendar_providers.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 日历月份导航头部（合并统计摘要）。
///
/// 布局:
/// ```
/// ◂  2026 年 5 月              ○72%  今天
///    12 个任务 · 8 已完成 · 6 天活跃
/// ```
///
/// 月份文字切换带 AnimatedSwitcher(上下滑入)。
/// 箭头按钮带按压缩放。完成率圆环从 MonthSummaryBar 移入。
class CalendarHeader extends ConsumerWidget {
  const CalendarHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(focusedMonthProvider);
    final stats = ref.watch(monthStatsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    final label = '${month.year} 年 ${month.month} 月';
    final hasTasks = stats.total > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        Spacing.base, Spacing.sm, Spacing.base, 0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? [
                  scheme.primaryContainer,
                  scheme.primaryContainer.withValues(alpha: 0.45),
                ]
              : [
                  scheme.primaryContainer.withValues(alpha: 0.35),
                  scheme.primaryContainer.withValues(alpha: 0.12),
                ],
        ),
        borderRadius: BorderRadius.circular(Radii.card),
        border: isLight
            ? null
            : Border.all(
                color: scheme.primaryContainer.withValues(alpha: 0.2),
              ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Spacing.sm, Spacing.sm, Spacing.sm, Spacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Navigation + ring + today ──
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => ref.read(focusedMonthProvider.notifier).state =
                    DateTime(month.year, month.month - 1),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MotionDurations.fast,
                  switchInCurve: MotionCurves.emphasizedDecelerate,
                  switchOutCurve: MotionCurves.emphasizedAccelerate,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => ref.read(focusedMonthProvider.notifier).state =
                    DateTime(month.year, month.month + 1),
              ),
              if (hasTasks) ...[
                const SizedBox(width: Spacing.xs),
                _CompletionRing(
                  rate: stats.completionRate,
                  size: 28,
                  color: scheme.primary,
                  bgColor: scheme.onPrimaryContainer.withValues(alpha: 0.12),
                ),
              ],
              const SizedBox(width: Spacing.xs),
              _TodayPill(
                onTap: () {
                  final now = DateTime.now();
                  ref.read(focusedMonthProvider.notifier).state =
                      DateTime(now.year, now.month);
                  ref.read(selectedDayProvider.notifier).state =
                      DateTime(now.year, now.month, now.day);
                },
              ),
            ],
          ),

          // ── Row 2: Stats summary (only if tasks exist) ──
          if (hasTasks)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: AnimatedSwitcher(
                duration: MotionDurations.fast,
                child: Text(
                  '${stats.total} 个任务 · ${stats.completed} 已完成 · ${stats.daysWithTasks} 天活跃',
                  key: ValueKey('${stats.total}-${stats.completed}-${stats.daysWithTasks}'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.65),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────

class _NavButton extends StatefulWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: MotionDurations.instant,
        curve: MotionCurves.gentleSpring,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.circle),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.sm),
              child: Icon(
                widget.icon,
                size: 22,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(Radii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.xs + 2,
          ),
          child: Text(
            '今天',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Completion Ring (from old MonthSummaryBar, downsized to 28dp)
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
      duration: MotionDurations.celebration,
      curve: MotionCurves.emphasizedDecelerate,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: color,
              bgColor: bgColor,
              strokeWidth: 3,
            ),
            child: Center(
              child: Text(
                '${(value * 100).round()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 8,
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
  const _RingPainter({
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

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

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
