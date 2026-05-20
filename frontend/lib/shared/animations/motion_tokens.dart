import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';

/// 全局动画时长与曲线常量。
/// 所有动效直接引用此文件的常量,保持风格统一。
abstract final class MotionDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration xSlow = Duration(milliseconds: 600);

  // ── 新增：灵动/活泼场景 ──
  /// 弹性入场 — 比 normal 稍长，留出弹跳空间
  static const Duration bouncy = Duration(milliseconds: 500);

  /// 庆祝/爆散粒子
  static const Duration celebration = Duration(milliseconds: 800);

  /// 列表交错基础间隔（每项叠加 staggerDelay）
  static const Duration staggerBase = Duration(milliseconds: 50);
}

abstract final class MotionCurves {
  static const Curve standard = Curves.easeInOut;
  static const Curve decelerate = Curves.easeOut;
  static const Curve accelerate = Curves.easeIn;
  static const Curve spring = Curves.easeOutBack;
  static const Curve emphasized = Curves.fastOutSlowIn;

  // ── 新增：活泼弹性曲线 ──
  /// 大幅过冲弹簧 — 用于 Checkbox、成就解锁
  static const Curve bouncySpring = _BouncySpringCurve();

  /// 轻弹簧 — 用于按压回弹、侧边栏指示条
  static const Curve gentleSpring = _GentleSpringCurve();

  /// M3 强调曲线 — 页面切换
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// M3 标准加速 — 页面退出
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
}

/// 弹性弹簧曲线 — 过冲约 15%，活泼但不夸张。
class _BouncySpringCurve extends Curve {
  const _BouncySpringCurve();

  @override
  double transformInternal(double t) {
    // damping=12, stiffness=180 → 明显弹跳
    final sim = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 180, damping: 12),
      0,
      1,
      0,
    );
    return sim.x(t);
  }
}

/// 柔和弹簧 — 几乎无过冲，但比 easeOut 更有弹性。
class _GentleSpringCurve extends Curve {
  const _GentleSpringCurve();

  @override
  double transformInternal(double t) {
    final sim = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 200, damping: 20),
      0,
      1,
      0,
    );
    return sim.x(t);
  }
}

/// 列表交错动画延迟计算器。
///
/// ```dart
/// delay: StaggerHelper.delay(index),
/// ```
abstract final class StaggerHelper {
  /// 第 [index] 项的入场延迟。最大 cap 在 400ms 防止列表太长时等太久。
  static Duration delay(int index, {Duration base = MotionDurations.staggerBase}) {
    final ms = (base.inMilliseconds * index).clamp(0, 400);
    return Duration(milliseconds: ms);
  }

  /// 交错淡入的初始偏移量 — 越靠后的项偏移越小（递减）。
  static double slideOffset(int index) {
    return (0.04 - index * 0.003).clamp(0.01, 0.04);
  }
}

/// 按压缩放动画的 Mixin — 让任何 Widget 拥有点按时缩小回弹的物理感。
///
/// 使用方式：在 StatefulWidget 的 State 中 `with PressScaleMixin`，
/// 然后在 build 中用 `buildPressScale(child: ..., onTap: ...)` 包裹内容。
mixin PressScaleMixin<T extends StatefulWidget> on State<T>,
    SingleTickerProviderStateMixin<T> {
  late final AnimationController _pressCtrl = AnimationController(
    vsync: this,
    duration: MotionDurations.fast,
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  late final Animation<double> _pressScale = Tween<double>(
    begin: 1.0,
    end: 0.96,
  ).animate(CurvedAnimation(
    parent: _pressCtrl,
    curve: MotionCurves.gentleSpring,
  ));

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Widget buildPressScale({
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: onTap,
      onLongPress: onLongPress,
      child: ScaleTransition(scale: _pressScale, child: child),
    );
  }
}

/// 粒子爆散效果的数据模型。
class Particle {
  Particle({required this.angle, required this.speed, required this.color});
  final double angle;
  final double speed;
  final Color color;

  Offset positionAt(double t) {
    // 带重力的抛射: y 方向叠加 0.5*g*t^2
    final dx = math.cos(angle) * speed * t;
    final dy = math.sin(angle) * speed * t + 0.5 * 200 * t * t;
    return Offset(dx, dy);
  }

  double opacityAt(double t) => (1.0 - t).clamp(0.0, 1.0);
  double sizeAt(double t) => (4.0 * (1.0 - t * 0.5)).clamp(1.0, 4.0);
}
