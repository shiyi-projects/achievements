import 'package:flutter/material.dart';

/// 全局动画时长与曲线常量。
/// 所有动效直接引用此文件的常量,保持风格统一。
abstract final class MotionDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration xSlow = Duration(milliseconds: 600);
}

abstract final class MotionCurves {
  static const Curve standard = Curves.easeInOut;
  static const Curve decelerate = Curves.easeOut;
  static const Curve accelerate = Curves.easeIn;
  static const Curve spring = Curves.easeOutBack;
  static const Curve emphasized = Curves.fastOutSlowIn;
}
