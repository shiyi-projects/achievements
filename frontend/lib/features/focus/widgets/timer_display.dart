import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/features/focus/widgets/celebration_overlay.dart';
import 'package:achievements/features/focus/widgets/duration_picker_sheet.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 专注计时器主显示区域。
///
/// 包含:
/// - 双层同心环（外层刻度盘 + 内层渐变弧）
/// - 中心大字计时数字（MM:SS），空闲态可点击调节时长
/// - 阶段标签 + 激励副文案
/// - 已完成番茄数指示
/// - 空闲态呼吸脉冲 + 完成态庆祝动画
class TimerDisplay extends ConsumerStatefulWidget {
  const TimerDisplay({super.key});

  @override
  ConsumerState<TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends ConsumerState<TimerDisplay>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final AnimationController _pulseCtrl;
  bool _celebrationShown = false;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _pulseCtrl.dispose();
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
    final motivationText = _motivationText(state);
    final isIdle = state.phase == FocusPhase.idle;
    final isDone = state.phase == FocusPhase.done;

    // 完成态触发庆祝
    if (isDone && !_celebrationShown) {
      _celebrationShown = true;
      _pulseCtrl.forward().then((_) => _pulseCtrl.reverse());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) CelebrationOverlay.show(context);
      });
    }
    if (!isDone) _celebrationShown = false;

    // 自适应环尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final ringSize = screenWidth < 400 ? screenWidth * 0.65 : 280.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Ring ──
        AnimatedBuilder(
          animation: Listenable.merge([_breathCtrl, _pulseCtrl]),
          builder: (context, _) {
            final breathStroke = isIdle
                ? 7.0 + _breathCtrl.value * 2.0
                : 8.0;
            final pulseScale = 1.0 + _pulseCtrl.value * 0.05;

            return Transform.scale(
              scale: pulseScale,
              child: SizedBox(
                width: ringSize,
                height: ringSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 双层环
                    CustomPaint(
                      size: Size(ringSize, ringSize),
                      painter: _DualRingPainter(
                        progress: progress,
                        bgColor: scheme.onSurface.withValues(alpha: 0.06),
                        startColor: _ringStartColor(state, scheme),
                        endColor: _ringEndColor(state, scheme),
                        tickColor: scheme.onSurface,
                        strokeWidth: breathStroke,
                        showGlowDot: progress > 0 && !isIdle,
                        isDone: isDone,
                        breathValue: _breathCtrl.value,
                        isIdle: isIdle,
                      ),
                    ),
                    // ── Time + labels ──
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 时间数字 — 空闲态可点击
                        GestureDetector(
                          onTap: isIdle
                              ? () => DurationPickerSheet.show(context, ref)
                              : null,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.95, end: 1.0),
                            duration: MotionDurations.bouncy,
                            curve: MotionCurves.bouncySpring,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                  scale: scale, child: child);
                            },
                            child: Text(
                              timeText,
                              style: TextStyle(
                                fontSize: ringSize * 0.18,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                        if (isIdle) ...[
                          const SizedBox(height: 2),
                          Text(
                            '点击调整时长',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                        const SizedBox(height: Spacing.xs),
                        // 阶段标签
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
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // ── 激励文案 ──
        if (motivationText != null) ...[
          const SizedBox(height: Spacing.md),
          AnimatedSwitcher(
            duration: MotionDurations.normal,
            child: Text(
              motivationText,
              key: ValueKey(motivationText),
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        // ── 番茄数指示 ──
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  // ── Colors ──

  Color _ringStartColor(FocusTimerState state, ColorScheme scheme) {
    return switch (state.phase) {
      FocusPhase.idle => scheme.onSurface.withValues(alpha: 0.15),
      FocusPhase.working => scheme.primary,
      FocusPhase.shortBreak => scheme.tertiary,
      FocusPhase.done => const Color(0xFFFFD700),
    };
  }

  Color _ringEndColor(FocusTimerState state, ColorScheme scheme) {
    return switch (state.phase) {
      FocusPhase.idle => scheme.onSurface.withValues(alpha: 0.08),
      FocusPhase.working => scheme.tertiary,
      FocusPhase.shortBreak => scheme.secondary,
      FocusPhase.done => const Color(0xFFFFA500),
    };
  }

  // ── Helpers ──

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double _computeProgress(FocusTimerState state) {
    if (state.mode == FocusMode.free) {
      final secs = state.elapsed.inSeconds;
      return (secs % 60) / 60.0;
    }
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
      FocusPhase.done =>
        state.mode == FocusMode.pomodoro ? '专注完成 🎉' : '已停止',
    };
  }

  String? _motivationText(FocusTimerState state) {
    final texts = switch (state.phase) {
      FocusPhase.idle => const [
          '深呼吸，准备好了就开始',
          '今天也要加油 💪',
          '一次只做一件事',
        ],
      FocusPhase.working when state.isRunning => const [
          '保持专注，你正在变好',
          '沉浸其中，享受心流',
          '每一分钟都在积累',
        ],
      FocusPhase.working => const [
          '休息一下也没关系',
          '准备好了就继续',
        ],
      FocusPhase.shortBreak => const [
          '站起来活动活动',
          '闭眼放松一下',
          '喝口水吧',
        ],
      FocusPhase.done => const [
          '太棒了！又完成一个番茄',
          '你的努力不会白费',
          '坚持就是胜利',
        ],
    };
    // 基于当前秒数选一条，让它不频繁切换
    final index = (DateTime.now().minute ~/ 5) % texts.length;
    return texts[index];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dual-ring painter: outer tick marks + inner gradient arc
// ─────────────────────────────────────────────────────────────────────────────

class _DualRingPainter extends CustomPainter {
  const _DualRingPainter({
    required this.progress,
    required this.bgColor,
    required this.startColor,
    required this.endColor,
    required this.tickColor,
    required this.strokeWidth,
    required this.showGlowDot,
    required this.isDone,
    required this.breathValue,
    required this.isIdle,
  });

  final double progress;
  final Color bgColor;
  final Color startColor;
  final Color endColor;
  final Color tickColor;
  final double strokeWidth;
  final bool showGlowDot;
  final bool isDone;
  final double breathValue;
  final bool isIdle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width - 4) / 2;
    final innerRadius = outerRadius - 16;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

    // ── 外层刻度盘 ──
    _drawTickMarks(canvas, center, outerRadius);

    // ── 内层背景环 ──
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, innerRadius, bgPaint);

    if (progress <= 0 && !isIdle) return;

    // 空闲态: 呼吸透明度弧
    if (isIdle) {
      final idleOpacity = 0.08 + breathValue * 0.08;
      final idlePaint = Paint()
        ..color = startColor.withValues(alpha: idleOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, innerRadius, idlePaint);
      return;
    }

    // ── 内层进度弧 ──
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

    canvas.drawArc(innerRect, -math.pi / 2, sweepAngle, false, fgPaint);

    // ── 发光点 ──
    if (showGlowDot && progress > 0.01) {
      final angle = -math.pi / 2 + sweepAngle;
      final dotCenter = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );

      canvas.drawCircle(
        dotCenter,
        strokeWidth * 1.8,
        Paint()
          ..color = endColor.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        dotCenter,
        strokeWidth * 0.65,
        Paint()..color = endColor,
      );
    }
  }

  void _drawTickMarks(Canvas canvas, Offset center, double radius) {
    const totalTicks = 60;
    final tickPaint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < totalTicks; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / totalTicks);
      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 8.0 : 4.0;
      final tickWidth = isMajor ? 1.5 : 0.8;
      final opacity = isIdle
          ? 0.15 + breathValue * 0.1
          : (i / totalTicks <= progress ? 0.5 : 0.12);

      tickPaint
        ..strokeWidth = tickWidth
        ..color = tickColor.withValues(alpha: opacity);

      final outerPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );

      canvas.drawLine(outerPoint, innerPoint, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_DualRingPainter old) =>
      old.progress != progress ||
      old.bgColor != bgColor ||
      old.startColor != startColor ||
      old.endColor != endColor ||
      old.strokeWidth != strokeWidth ||
      old.showGlowDot != showGlowDot ||
      old.breathValue != breathValue;
}
