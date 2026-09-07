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

  /// ── 极简风格(设置页) ──
  /// Material 默认的大圆角在信息密集、以排版分层的界面里显得过于圆润,
  /// 这两个 token 把圆角收在 6–10px。

  /// 控件:分段选择器、小按钮、色卡
  static const double control = 8;

  /// 面板:设置弹窗等大块容器
  static const double panel = 10;

  /// 分段选择器内部选中块(比外框小 2px,视觉上同心)
  static const double controlInner = 6;
}
