/// 间距与圆角设计 Token（ui_design_spec §4）。
///
/// 基于 4px 网格。所有 UI 组件应引用这些常量,
/// 避免硬编码数值以保持全局一致性。
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

/// 圆角 Token（ui_design_spec §4.2）。
abstract final class Radii {
  /// FilledButton — 全圆角
  static const double button = 20;

  /// 卡片
  static const double card = 16;

  /// 输入框
  static const double input = 12;

  /// 底部弹窗 / 对话框
  static const double sheet = 28;

  /// 标签 Chip
  static const double chip = 8;

  /// 头像 / FAB
  static const double circle = 999;
}
