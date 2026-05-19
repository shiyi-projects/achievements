/// Local achievement definitions — mirrors the backend seed data.
library;

enum AchievementCriteriaType {
  tasksCompleted,
  streakDays,
  focusSessions,
  dailyFocusMinutes,
}

class AchievementDef {
  const AchievementDef({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.criteriaType,
    required this.threshold,
  });

  final String code;
  final String name;
  final String description;
  final String icon;
  final AchievementCriteriaType criteriaType;
  final int threshold;
}

const List<AchievementDef> kAchievementDefs = [
  AchievementDef(
    code: 'first_task',
    name: '第一步',
    description: '完成你的第一个任务',
    icon: '🎯',
    criteriaType: AchievementCriteriaType.tasksCompleted,
    threshold: 1,
  ),
  AchievementDef(
    code: 'tasks_10',
    name: '渐入佳境',
    description: '累计完成 10 个任务',
    icon: '🔥',
    criteriaType: AchievementCriteriaType.tasksCompleted,
    threshold: 10,
  ),
  AchievementDef(
    code: 'tasks_100',
    name: '百任达人',
    description: '累计完成 100 个任务',
    icon: '💯',
    criteriaType: AchievementCriteriaType.tasksCompleted,
    threshold: 100,
  ),
  AchievementDef(
    code: 'streak_3',
    name: '三日连冠',
    description: '连续 3 天完成任务',
    icon: '📅',
    criteriaType: AchievementCriteriaType.streakDays,
    threshold: 3,
  ),
  AchievementDef(
    code: 'streak_7',
    name: '一周不息',
    description: '连续 7 天完成任务',
    icon: '🗓️',
    criteriaType: AchievementCriteriaType.streakDays,
    threshold: 7,
  ),
  AchievementDef(
    code: 'first_focus',
    name: '初心专注',
    description: '完成第一次专注会话',
    icon: '⏱️',
    criteriaType: AchievementCriteriaType.focusSessions,
    threshold: 1,
  ),
  AchievementDef(
    code: 'focus_10',
    name: '专注十次',
    description: '累计完成 10 次专注会话',
    icon: '🧘',
    criteriaType: AchievementCriteriaType.focusSessions,
    threshold: 10,
  ),
  AchievementDef(
    code: 'focus_1h',
    name: '一小时专注',
    description: '单日累计专注 60 分钟',
    icon: '⏰',
    criteriaType: AchievementCriteriaType.dailyFocusMinutes,
    threshold: 60,
  ),
];
