import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// M3 风格页面切换过渡 — SharedAxis 纵轴变体。
///
/// 旧页面: 向后缩小(scale 1→0.92) + 淡出
/// 新页面: 从前方滑入(offset 0.06→0) + 淡入
///
/// 比默认 FadeTransition 更有层次感和方向感。
class SharedAxisTransitionBuilder extends StatelessWidget {
  const SharedAxisTransitionBuilder({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 入场
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: MotionCurves.emphasizedDecelerate,
    );
    final slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(fadeIn);

    // 退场（被新页面覆盖时）
    final fadeOut = CurvedAnimation(
      parent: secondaryAnimation,
      curve: MotionCurves.emphasizedAccelerate,
    );
    final scaleOut = Tween<double>(begin: 1.0, end: 0.92).animate(fadeOut);

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(fadeIn),
      child: SlideTransition(
        position: slideIn,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.0).animate(animation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.6).animate(fadeOut),
            child: ScaleTransition(scale: scaleOut, child: child),
          ),
        ),
      ),
    );
  }
}

/// AnimatedSwitcher 专用的过渡构造器。
///
/// 使用：
/// ```dart
/// AnimatedSwitcher(
///   duration: MotionDurations.normal,
///   transitionBuilder: sharedAxisTransition,
///   child: ...
/// )
/// ```
Widget sharedAxisTransition(Widget child, Animation<double> animation) {
  final curvedAnim = CurvedAnimation(
    parent: animation,
    curve: MotionCurves.emphasizedDecelerate,
    reverseCurve: MotionCurves.emphasizedAccelerate,
  );
  return FadeTransition(
    opacity: curvedAnim,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(curvedAnim),
      child: child,
    ),
  );
}

/// 水平轴过渡 — 适用于侧边栏导航间切换。
Widget horizontalAxisTransition(Widget child, Animation<double> animation) {
  final curvedAnim = CurvedAnimation(
    parent: animation,
    curve: MotionCurves.emphasizedDecelerate,
    reverseCurve: MotionCurves.emphasizedAccelerate,
  );
  return FadeTransition(
    opacity: curvedAnim,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.03, 0),
        end: Offset.zero,
      ).animate(curvedAnim),
      child: child,
    ),
  );
}
