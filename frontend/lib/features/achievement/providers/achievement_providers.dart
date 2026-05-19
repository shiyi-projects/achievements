import 'package:achievements/features/achievement/models/achievement_def.dart';
import 'package:achievements/features/statistics/data/stats_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievement_providers.g.dart';

/// Maps achievement code → whether it is unlocked locally.
@riverpod
Future<Map<String, bool>> achievementStatus(Ref ref) async {
  final repo = ref.watch(statsRepositoryProvider);

  final results = await Future.wait<int>([
    repo.totalCompletedTasks(),
    repo.streakDays(),
    repo.completedFocusSessions(),
    repo.todayFocusMinutes(),
  ]);
  final totalTasks = results[0];
  final streak = results[1];
  final focusSessions = results[2];
  final todayFocusMin = results[3];

  return {
    for (final def in kAchievementDefs)
      def.code: _isUnlocked(def, totalTasks, streak, focusSessions, todayFocusMin),
  };
}

bool _isUnlocked(
  AchievementDef def,
  int totalTasks,
  int streak,
  int focusSessions,
  int todayFocusMin,
) {
  return switch (def.criteriaType) {
    AchievementCriteriaType.tasksCompleted => totalTasks >= def.threshold,
    AchievementCriteriaType.streakDays => streak >= def.threshold,
    AchievementCriteriaType.focusSessions => focusSessions >= def.threshold,
    AchievementCriteriaType.dailyFocusMinutes => todayFocusMin >= def.threshold,
  };
}
