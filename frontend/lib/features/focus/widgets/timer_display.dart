import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 专注计时器主显示区域。
///
/// 包含:
/// - 圆形进度环（渐变色 + 末端发光点）
/// - 中心大字计时数字（MM:SS）
/// - 阶段标签
/// - 已完成番茄数提示
/// - 空闲态呼吸脉冲
class TimerDisplay extends ConsumerStatefulWidget {
  const TimerDisplay({super.key});

  @override
  ConsumerState<TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends ConsumerState<TimerDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusTimerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final timeText = _formatDuration(
      state.mode == FocusMode.free ? state.elapsed : state.remaining,
    );

    final progress = _computeProgress(state);
    final phaseLabel = _phaseLabel(state);
    final isIdle = state.phase == FocusPhase.idle;
    final isDone = state.phase == FocusPhase.done;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Ring ──
              AnimatedBuilder(
                animation: _breathCtrl,
                builder: (context, _) {
                  // 呼吸效果: 空闲时 strokeWidth 在 7-9 之间缓慢变化
                  final breathStroke = isIdle
                      ? 7.0 + _breathCtrl.value * 2.0
                      : 8.0;
                  return CustomPaint(
                    size: const Size(240, 240),
                    painter: _GradientRingPainter(
                      progress: progress,
                      bgColor: scheme.surfaceContainerHighest,
                      startColor: scheme.primary,
                      endColor: scheme.tertiary,
                      strokeWidth: breathStroke,
                      showGlowDot: progress > 0 && !isIdle,
                      isDone: isDone,
                    ),
                  );
                },
              ),
              // ── Time display ──
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.95, end: 1.0),
                    duration: MotionDurations.bouncy,
                    curve: MotionCurves.bouncySpring,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Text(
                      timeText,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  AnimatedSwitcher(
                    duration: MotionDurations.fast,
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
                      phaseLabel,
                      key: ValueKey(phaseLabel),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.completedPomodoros > 0) ...[
          const SizedBox(height: Spacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              state.completedPomodoros.clamp(0, 8),
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: scheme.primary.withValues(
                    alpha: 0.5 + (i / state.completedPomodoros) * 0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '番茄 x ${state.completedPomodoros}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double _computeProgress(FocusTimerState state) {
    if (state.mode == FocusMode.free) {
      final secs = state.elapsed.inSeconds;
      return (secs % 60) / 60.0;
    }
    // 番茄钟模式
    final totalSecs = state.phase == FocusPhase.shortBreak
        ? state.breakDuration.inSeconds
        : state.workDuration.inSeconds;
    if (totalSecs == 0) return 0;
    final elapsed = totalSecs - state.remaining.inSeconds;
    return (elapsed / totalSecs).clamp(0.0, 1.0);
  }

  String _phaseLabel(FocusTimerState state) {
    if (!state.isRunning && state.phase == FocusPhase.working) return '已暂停';
    return switch (state.phase) {
      FocusPhase.idle => '准备就绪',
      FocusPhase.working => '专注中',
      FocusPhase.shortBreak => '休息中',
      FocusPhase.done => state.mode == FocusMode.pomodoro ? '专注完成 🎉' : '已停止',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient ring painter with glow dot
// ─────────────────────────────────────────────────────────────────────────────

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter({
    required this.progress,
    required this.bgColor,
    required this.startColor,
    required this.endColor,
    required this.strokeWidth,
    required this.showGlowDot,
    required this.isDone,
  });

  final double progress;
  final Color bgColor;
  final Color startColor;
  final Color endColor;
  final double strokeWidth;
  final bool showGlowDot;
  final bool isDone;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // Progress arc — gradient from startColor to endColor
    final sweepAngle = 2 * math.pi * progress;
    final gradient = ui.Gradient.sweep(
      center,
      [startColor, endColor, startColor],
      [0.0, 0.5, 1.0],
      TileMode.clamp,
      -math.pi / 2,
      -math.pi / 2 + sweepAngle,
    );

    final fgPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );

    // Glow dot at the end of progress arc
    if (showGlowDot && progress > 0.01) {
      final angle = -math.pi / 2 + sweepAngle;
      final dotCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      // Outer glow
      canvas.drawCircle(
        dotCenter,
        strokeWidth * 1.5,
        Paint()
          ..color = endColor.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Inner dot
      canvas.drawCircle(
        dotCenter,
        strokeWidth * 0.6,
        Paint()..color = endColor,
      );
    }
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) =>
      old.progress != progress ||
      old.bgColor != bgColor ||
      old.startColor != startColor ||
      old.endColor != endColor ||
      old.strokeWidth != strokeWidth ||
      old.showGlowDot != showGlowDot;
}
