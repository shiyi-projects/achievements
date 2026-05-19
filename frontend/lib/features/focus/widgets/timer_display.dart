import 'dart:math' as math;

import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 专注计时器主显示区域。
///
/// 包含:
/// - 圆形进度环（[CustomPaint]）
/// - 中心大字计时数字（MM:SS）
/// - 阶段标签
/// - 已完成番茄数提示
class TimerDisplay extends ConsumerWidget {
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusTimerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final timeText = _formatDuration(
      state.mode == FocusMode.free ? state.elapsed : state.remaining,
    );

    final progress = _computeProgress(state);
    final phaseLabel = _phaseLabel(state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(240, 240),
                painter: _RingPainter(
                  progress: progress,
                  ringColor: scheme.surfaceContainerHighest,
                  progressColor: scheme.primary,
                  strokeWidth: 8,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    phaseLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.completedPomodoros > 0) ...[
          const SizedBox(height: Spacing.md),
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
      FocusPhase.idle => '空闲',
      FocusPhase.working => '专注中',
      FocusPhase.shortBreak => '休息中',
      FocusPhase.done => state.mode == FocusMode.pomodoro ? '专注完成' : '已停止',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring painter
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color ringColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring
    final bgPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    // Progress arc — starts at 12 o'clock (-π/2)
    final fgPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.progressColor != progressColor ||
      old.strokeWidth != strokeWidth;
}
