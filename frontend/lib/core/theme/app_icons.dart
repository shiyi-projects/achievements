import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 集中管理所有自定义 SVG 图标路径。
///
/// 用法:
/// ```dart
/// AppIcons.svgIcon(AppIcons.today, size: 20)
/// ```
///
/// SVG 保持原始多色渲染,不做 colorFilter 覆盖。
abstract final class AppIcons {
  // ── 路径常量 ──────────────────────────────────────────────────────

  static const _base = 'assets/icons';

  // 品牌
  static const appIcon = '$_base/01_app_icon.svg';

  // 导航 — 系统清单
  static const allTasks = '$_base/02_all_tasks.svg';
  static const today = '$_base/03_today.svg';
  static const important = '$_base/04_important.svg';
  static const tag = '$_base/05_tag.svg';
  static const list = '$_base/06_list.svg';
  static const completed = '$_base/07_completed.svg';
  static const inbox = '$_base/08_inbox.svg';
  static const reminder = '$_base/09_reminder.svg';
  static const stats = '$_base/10_stats.svg';
  static const settings = '$_base/11_settings.svg';

  // 任务状态
  static const incomplete = '$_base/12_incomplete.svg';
  static const completedStatus = '$_base/13_completed_status.svg';
  static const inProgress = '$_base/14_in_progress.svg';

  // 优先级
  static const highPriority = '$_base/15_high_priority.svg';
  static const mediumPriority = '$_base/16_medium_priority.svg';
  static const lowPriority = '$_base/17_low_priority.svg';

  // 操作
  static const edit = '$_base/18_edit.svg';
  static const delete = '$_base/19_delete.svg';
  static const more = '$_base/20_more.svg';

  // 导航 — 视图
  static const calendar = '$_base/21_calendar.svg';
  static const focusTimer = '$_base/22_focus_timer.svg';
  static const achievement = '$_base/23_achievement.svg';
  static const planned = '$_base/24_planned.svg';
  static const search = '$_base/25_search.svg';

  // 通用操作
  static const add = '$_base/26_add.svg';
  static const close = '$_base/27_close.svg';
  static const check = '$_base/28_check.svg';
  static const folder = '$_base/29_folder.svg';
  static const newFolder = '$_base/30_new_folder.svg';
  static const undo = '$_base/31_undo.svg';
  static const expand = '$_base/32_expand.svg';
  static const cloudSync = '$_base/33_cloud_sync.svg';
  static const sync = '$_base/34_sync.svg';
  static const send = '$_base/35_send.svg';
  static const subtask = '$_base/36_subtask.svg';
  static const info = '$_base/37_info.svg';
  static const lock = '$_base/38_lock.svg';
  static const snooze = '$_base/39_snooze.svg';
  static const streak = '$_base/40_streak.svg';
  static const cloudOff = '$_base/41_cloud_off.svg';
  static const cloudError = '$_base/42_cloud_error.svg';

  // ── 工厂方法 ──────────────────────────────────────────────────────

  /// 返回一个保持多色原貌的 SVG Widget。
  ///
  /// [size] 同时约束 width/height,默认 20。
  static Widget svgIcon(String assetPath, {double size = 20}) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
    );
  }
}
