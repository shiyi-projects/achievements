import 'dart:math' as math;

import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 浮游粒子氛围层。
///
/// 在专注页背景上绘制缓慢漂浮的半透明光点:
/// - 空闲: 慢速漂浮，低透明度
/// - 工作中: 加速，亮度提升
/// - 休息: 减速，变淡
class AmbientParticles extends ConsumerStatefulWidget {
  const AmbientParticles({super.key});

  @override
  ConsumerState<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends ConsumerState<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_FloatingParticle> _particles;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particles = List.generate(18, (_) => _FloatingParticle.random(_rand));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(focusTimerProvider.select((s) => s.phase));
    final isRunning = ref.watch(focusTimerProvider.select((s) => s.isRunning));
    final scheme = Theme.of(context).colorScheme;

    final baseOpacity = switch (phase) {
      FocusPhase.idle => 0.15,
      FocusPhase.working when isRunning => 0.35,
      FocusPhase.working => 0.12,
      FocusPhase.shortBreak => 0.1,
      FocusPhase.done => 0.4,
    };

    final speedMultiplier = switch (phase) {
      FocusPhase.idle => 0.5,
      FocusPhase.working when isRunning => 1.2,
      FocusPhase.working => 0.3,
      FocusPhase.shortBreak => 0.4,
      FocusPhase.done => 0.8,
    };

    final dotColor = switch (phase) {
      FocusPhase.idle => scheme.onSurfaceVariant,
      FocusPhase.working => scheme.primary,
      FocusPhase.shortBreak => scheme.tertiary,
      FocusPhase.done => const Color(0xFFFFD700),
    };

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(
              particles: _particles,
              time: _ctrl.value,
              baseOpacity: baseOpacity,
              speedMultiplier: speedMultiplier,
              color: dotColor,
            ),
          );
        },
      ),
    );
  }
}

class _FloatingParticle {
  _FloatingParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.phase,
  });

  factory _FloatingParticle.random(math.Random rand) {
    return _FloatingParticle(
      x: rand.nextDouble(),
      y: rand.nextDouble(),
      size: 1.5 + rand.nextDouble() * 2.5,
      speedX: (rand.nextDouble() - 0.5) * 0.02,
      speedY: (rand.nextDouble() - 0.5) * 0.015,
      phase: rand.nextDouble() * math.pi * 2,
    );
  }

  final double x;
  final double y;
  final double size;
  final double speedX;
  final double speedY;
  final double phase;

  Offset positionAt(double t, double speed) {
    final tx =
        (x +
            speedX * t * speed * 60 +
            math.sin(t * math.pi * 2 + phase) * 0.02) %
        1.0;
    final ty =
        (y +
            speedY * t * speed * 60 +
            math.cos(t * math.pi * 2 + phase * 1.3) * 0.015) %
        1.0;
    return Offset(tx, ty);
  }

  double opacityAt(double t) {
    return 0.3 + 0.7 * ((math.sin(t * math.pi * 2 + phase) + 1) / 2);
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({
    required this.particles,
    required this.time,
    required this.baseOpacity,
    required this.speedMultiplier,
    required this.color,
  });

  final List<_FloatingParticle> particles;
  final double time;
  final double baseOpacity;
  final double speedMultiplier;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final pos = p.positionAt(time, speedMultiplier);
      final opacity = (baseOpacity * p.opacityAt(time)).clamp(0.0, 1.0);
      final center = Offset(pos.dx * size.width, pos.dy * size.height);

      // 发光效果
      canvas.drawCircle(
        center,
        p.size * 2,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // 核心亮点
      canvas.drawCircle(
        center,
        p.size,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.time != time;
}
