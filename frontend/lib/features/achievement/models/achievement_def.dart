/// Local achievement definitions — mirrors the backend seed data.
library;

enum AchievementCriteriaType {
  tasksCompleted,
  streakDays,
  focusSessions,
  dailyFocusMinutes,
  totalFocusMinutes,
  dailyTasksCompleted,
  earlyCompletion,
  lateCompletion,
}

class AchievementDef {
  const AchievementDef({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.svgAsset,
    required this.criteriaType,
    required this.threshold,
  });

  final String code;
  final String name;
  final String description;
  final String icon;

  /// Path to the SVG banner asset, e.g. 'assets/achievements_svg/01_first_step_icon.svg'.
  final String svgAsset;

  final AchievementCriteriaType criteriaType;
  final int threshold;

  bool get hasSvg => svgAsset.isNotEmpty;
}

const _svgBase = 'assets/achievements_svg';

const List<AchievementDef> kAchievementDefs = [
  // ── 📋 任务完成类 ──────────────────────────────────────────────────
  AchievementDef(
    code: 'first_task',
    name: '第一步',
    description: '完成你的第一个任务',
    icon: '🎯',
    svgAsset: '$_svgBase/01_first_step_icon.svg',
    criteriaType: AchievementCriteriaType.tasksCompleted,
    threshold: 1,
  ),
  AchievementDef(
    code: 'tasks_10',
    name: '渐入佳境',
    description: '累计完成 10 个任务',
    icon: '🔥',
    svgAsset: '$_svgBase/04_getting_into_it_icon.svg',
    criteriaType: AchievementCriteriaType.tasksCompleted,
    threshold: 10,
  ),
  AchievementDef(
    code: 'tasks_50',
    name: '半百征途',
    description: '累计完成 50 个任务',
    icon: '📋',
    svgAsset: '$_svgBase/tasks_50.svg',
    criteriaType: AchievementCriteriaType.tasksCompleted,
    threshold: 50,
  ),
  AchievementDef(
    code: 'tasks_100',
    name: '百任达人',
    description: '累计完成 100 个任务',
    icon: '💯',
    svgAsset: '$_svgBase/05_100_tasks_master_icon.svg',
    criteriaType: AchievementCriteriaType.tasksCompleted,
    threshold: 100,
  ),
  AchievementDef(
    code: 'tasks_500',
    name: '五百里程碑',
    description: '累计完成 500 个任务',
    icon: '🏔️',
    svgAsset: '$_svgBase/tasks_500.svg',
    criteriaType: AchievementCriteriaType.tasksCompleted,
    threshold: 500,
  ),

  // ── 🔥 连续打卡类 ──────────────────────────────────────────────────
  AchievementDef(
    code: 'streak_3',
    name: '三日连冠',
    description: '连续 3 天完成任务',
    icon: '📅',
    svgAsset: '$_svgBase/06_three_day_streak_icon.svg',
    criteriaType: AchievementCriteriaType.streakDays,
    threshold: 3,
  ),
  AchievementDef(
    code: 'streak_7',
    name: '一周不息',
    description: '连续 7 天完成任务',
    icon: '🗓️',
    svgAsset: '$_svgBase/07_week_streak_icon.svg',
    criteriaType: AchievementCriteriaType.streakDays,
    threshold: 7,
  ),
  AchievementDef(
    code: 'streak_14',
    name: '双周挑战',
    description: '连续 14 天完成任务',
    icon: '🔥',
    svgAsset: '$_svgBase/streak_14.svg',
    criteriaType: AchievementCriteriaType.streakDays,
    threshold: 14,
  ),
  AchievementDef(
    code: 'streak_30',
    name: '月度冠军',
    description: '连续 30 天完成任务',
    icon: '🏆',
    svgAsset: '$_svgBase/streak_30.svg',
    criteriaType: AchievementCriteriaType.streakDays,
    threshold: 30,
  ),

  // ── ⏱️ 专注会话类 ──────────────────────────────────────────────────
  AchievementDef(
    code: 'first_focus',
    name: '初心专注',
    description: '完成第一次专注会话',
    icon: '⏱️',
    svgAsset: '$_svgBase/02_focus_launch_icon.svg',
    criteriaType: AchievementCriteriaType.focusSessions,
    threshold: 1,
  ),
  AchievementDef(
    code: 'focus_10',
    name: '专注十次',
    description: '累计完成 10 次专注会话',
    icon: '🧘',
    svgAsset: '$_svgBase/focus_10.svg',
    criteriaType: AchievementCriteriaType.focusSessions,
    threshold: 10,
  ),
  AchievementDef(
    code: 'focus_50',
    name: '专注达人',
    description: '累计完成 50 次专注会话',
    icon: '🎯',
    svgAsset: '$_svgBase/focus_50.svg',
    criteriaType: AchievementCriteriaType.focusSessions,
    threshold: 50,
  ),
  AchievementDef(
    code: 'focus_100',
    name: '专注百次',
    description: '累计完成 100 次专注会话',
    icon: '💎',
    svgAsset: '$_svgBase/focus_100.svg',
    criteriaType: AchievementCriteriaType.focusSessions,
    threshold: 100,
  ),

  // ── ⏰ 专注时长类 ──────────────────────────────────────────────────
  AchievementDef(
    code: 'focus_1h',
    name: '一小时专注',
    description: '单日累计专注 60 分钟',
    icon: '⏰',
    svgAsset: '$_svgBase/08_one_hour_focus_icon.svg',
    criteriaType: AchievementCriteriaType.dailyFocusMinutes,
    threshold: 60,
  ),
  AchievementDef(
    code: 'focus_total_10h',
    name: '十小时积累',
    description: '累计专注满 10 小时',
    icon: '⏳',
    svgAsset: '$_svgBase/focus_total_10h.svg',
    criteriaType: AchievementCriteriaType.totalFocusMinutes,
    threshold: 600,
  ),
  AchievementDef(
    code: 'focus_total_100h',
    name: '百小时大师',
    description: '累计专注满 100 小时',
    icon: '👑',
    svgAsset: '$_svgBase/focus_total_100h.svg',
    criteriaType: AchievementCriteriaType.totalFocusMinutes,
    threshold: 6000,
  ),

  // ── ⭐ 效率与习惯类 ────────────────────────────────────────────────
  AchievementDef(
    code: 'daily_5',
    name: '效率之星',
    description: '单日完成 5 个任务',
    icon: '⭐',
    svgAsset: '$_svgBase/03_efficiency_star_icon.svg',
    criteriaType: AchievementCriteriaType.dailyTasksCompleted,
    threshold: 5,
  ),
  AchievementDef(
    code: 'daily_10',
    name: '超级效率',
    description: '单日完成 10 个任务',
    icon: '⚡',
    svgAsset: '$_svgBase/daily_10.svg',
    criteriaType: AchievementCriteriaType.dailyTasksCompleted,
    threshold: 10,
  ),
  AchievementDef(
    code: 'early_bird',
    name: '早起鸟儿',
    description: '早上 7 点前完成一个任务',
    icon: '🌅',
    svgAsset: '$_svgBase/early_bird.svg',
    criteriaType: AchievementCriteriaType.earlyCompletion,
    threshold: 1,
  ),
  AchievementDef(
    code: 'night_owl',
    name: '夜猫子',
    description: '晚上 11 点后完成一个任务',
    icon: '🌙',
    svgAsset: '$_svgBase/night_owl.svg',
    criteriaType: AchievementCriteriaType.lateCompletion,
    threshold: 1,
  ),
];
