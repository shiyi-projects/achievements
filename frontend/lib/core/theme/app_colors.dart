import 'package:flutter/material.dart';

/// 应用自定义色彩常量。
///
/// 优先级色彩来自 ui_design_spec §2.4;
/// 不随 Light/Dark 切换,在任何主题模式下保持固定语义。
abstract final class AppColors {
  // ── 任务优先级 ──
  /// 🔴 紧急 / Urgent
  static const Color urgent = Color(0xFFDC362E);

  /// 🟠 高 / High
  static const Color high = Color(0xFFE8710A);

  /// 🔵 中 / Medium
  static const Color medium = Color(0xFF2196F3);

  /// ⚪ 低 / Low — 使用 outline 色调
  static const Color low = Color(0xFF79747E);

  /// ⭐ 星标 / Starred — 暖金色,语义固定不随主题切换。
  /// 背景高亮用本色叠加低 alpha,在 Light/Dark 下均为柔和暖调。
  static const Color star = Color(0xFFF5A623);

  // ── 主题预设种子色 ──
  /// 科技蓝 — 主默认种子色
  static const Color seedTechBlue = Color(0xFF0078D4);

  /// 薄荷绿
  static const Color seedMintGreen = Color(0xFF00A67E);

  /// 海洋蓝
  static const Color seedOceanBlue = Color(0xFF0061A4);

  /// 森林绿
  static const Color seedForestGreen = Color(0xFF386A20);

  /// 日落橙
  static const Color seedSunsetOrange = Color(0xFFA23F16);

  /// 纯净灰
  static const Color seedNeutralGray = Color(0xFF5D5D5D);
}
