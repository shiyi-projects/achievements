import 'dart:math' as math;
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 成就总览卡片 — 进度条 + 圆形完成度环。
class AchievementOverviewCard extends StatefulWidget {
  const AchievementOverviewCard({
    required this.unlocked,
    required this.total,
    super.key,
  });

  final int unlocked;
  final int total;

  @override
  State<AchievementOverviewCard> createState() =>
      _AchievementOverviewCardState();
}

class _AchievementOverviewCardState extends State<AchievementOverviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    final pct = widget.total > 0 ? widget.unlocked / widget.total : 0.0;

    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // ── Left: text + progress bar ──
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '成就总览',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '记录任务完成、连续习惯和专注时长',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 10,
                        child: AnimatedBuilder(
                          animation: _ringCtrl,
                          builder: (_, __) => LinearProgressIndicator(
                            value: pct * _ringCtrl.value,
                            backgroundColor: isLight
                                ? const Color(0xFFE8EAF0)
                                : scheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              scheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '已解锁 ${widget.unlocked} / ${widget.total}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // ── Right: circular ring ──
              SizedBox(
                width: 90,
                height: 90,
                child: AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (_, __) => CustomPaint(
                    painter: _RingPainter(
                      progress: pct * _ringCtrl.value,
                      trackColor: isLight
                          ? const Color(0xFFE8EAF0)
                          : scheme.surfaceContainerHighest,
                      progressColor: scheme.primary,
                      strokeWidth: 8,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(pct * 100 * _ringCtrl.value).round()}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            '完成度',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: MotionDurations.normal)
        .slideY(
          begin: 0.04,
          duration: MotionDurations.normal,
          curve: MotionCurves.emphasizedDecelerate,
        );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top
        2 * math.pi * progress,
        false,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
