import 'dart:math' as math;

import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// 番茄完成时的庆祝粒子爆散 Overlay。
///
/// 使用方式:
/// ```dart
/// CelebrationOverlay.show(context);
/// ```
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.onComplete});

  final VoidCallback onComplete;

  /// 在当前 context 上方显示庆祝效果。
  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => CelebrationOverlay(onComplete: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_CelebParticle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: MotionDurations.celebration)
          ..forward()
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onComplete();
            }
          });

    final rand = math.Random();
    _particles = List.generate(30, (_) {
      final angle = rand.nextDouble() * math.pi * 2;
      final speed = 80 + rand.nextDouble() * 200;
      final colors = [
        const Color(0xFFFFD700), // 金色
        const Color(0xFFFF6B6B), // 粉红
        const Color(0xFF6C63FF), // 紫色
        const Color(0xFF4ECDC4), // 青色
        const Color(0xFFFFE66D), // 黄色
      ];
      return _CelebParticle(
        angle: angle,
        speed: speed,
        color: colors[rand.nextInt(colors.length)],
        size: 3.0 + rand.nextDouble() * 3.0,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _CelebPainter(
              particles: _particles,
              progress: _ctrl.value,
            ),
          );
        },
      ),
    );
  }
}

class _CelebParticle {
  const _CelebParticle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
  });

  final double angle;
  final double speed;
  final Color color;
  final double size;
}

class _CelebPainter extends CustomPainter {
  const _CelebPainter({required this.particles, required this.progress});

  final List<_CelebParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.35);

    for (final p in particles) {
      final t = progress;
      final dx = math.cos(p.angle) * p.speed * t;
      final dy = math.sin(p.angle) * p.speed * t + 0.5 * 300 * t * t;
      final pos = center + Offset(dx, dy);

      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final particleSize = p.size * (1.0 - t * 0.5);

      if (opacity <= 0 || particleSize <= 0) continue;

      canvas.drawCircle(
        pos,
        particleSize,
        Paint()..color = p.color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_CelebPainter old) => old.progress != progress;
}
