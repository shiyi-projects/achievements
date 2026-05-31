import 'package:achievements/features/achievement/models/achievement_def.dart';
import 'package:achievements/features/statistics/data/stats_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievement_providers.g.dart';

/// Maps achievement code → whether it is unlocked locally.
@riverpod
Future<Map<String, bool>> achievementStatus(Ref ref) async {
  final repo = ref.watch(statsRepositoryProvider);

  // Fetch all metrics in parallel for efficiency.
  final intResults = await Future.wait<int>([
    repo.totalCompletedTasks(), // 0
    repo.streakDays(), // 1
    repo.completedFocusSessions(), // 2
    repo.todayFocusMinutes(), // 3
    repo.totalFocusMinutes(), // 4
    repo.maxDailyCompletedTasks(), // 5
  ]);

  final boolResults = await Future.wait<bool>([
    repo.hasEarlyCompletion(), // 0
    repo.hasLateCompletion(), // 1
  ]);

  final metrics = _AchievementMetrics(
    totalTasks: intResults[0],
    streak: intResults[1],
    focusSessions: intResults[2],
    todayFocusMin: intResults[3],
    totalFocusMin: intResults[4],
    maxDailyTasks: intResults[5],
    hasEarly: boolResults[0],
    hasLate: boolResults[1],
  );

  return {
    for (final def in kAchievementDefs) def.code: _isUnlocked(def, metrics),
  };
}

class _AchievementMetrics {
  const _AchievementMetrics({
    required this.totalTasks,
    required this.streak,
    required this.focusSessions,
    required this.todayFocusMin,
    required this.totalFocusMin,
    required this.maxDailyTasks,
    required this.hasEarly,
    required this.hasLate,
  });

  final int totalTasks;
  final int streak;
  final int focusSessions;
  final int todayFocusMin;
  final int totalFocusMin;
  final int maxDailyTasks;
  final bool hasEarly;
  final bool hasLate;
}

bool _isUnlocked(AchievementDef def, _AchievementMetrics m) {
  return switch (def.criteriaType) {
    AchievementCriteriaType.tasksCompleted => m.totalTasks >= def.threshold,
    AchievementCriteriaType.streakDays => m.streak >= def.threshold,
    AchievementCriteriaType.focusSessions => m.focusSessions >= def.threshold,
    AchievementCriteriaType.dailyFocusMinutes =>
      m.todayFocusMin >= def.threshold,
    AchievementCriteriaType.totalFocusMinutes =>
      m.totalFocusMin >= def.threshold,
    AchievementCriteriaType.dailyTasksCompleted =>
      m.maxDailyTasks >= def.threshold,
    AchievementCriteriaType.earlyCompletion => m.hasEarly,
    AchievementCriteriaType.lateCompletion => m.hasLate,
  };
}
