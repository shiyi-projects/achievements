import 'package:achievements/features/statistics/data/stats_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_providers.g.dart';

@riverpod
Future<
  ({
    int totalCompleted,
    int todayCompleted,
    int streakDays,
    int totalFocusMinutes,
  })
>
statsOverview(Ref ref) async {
  final repo = ref.watch(statsRepositoryProvider);
  final results = await Future.wait<int>([
    repo.totalCompletedTasks(),
    repo.todayCompletedTasks(),
    repo.streakDays(),
    repo.totalFocusMinutes(),
  ]);
  return (
    totalCompleted: results[0],
    todayCompleted: results[1],
    streakDays: results[2],
    totalFocusMinutes: results[3],
  );
}

@riverpod
Future<Map<String, int>> statsHeatmap(Ref ref) =>
    ref.watch(statsRepositoryProvider).completionHeatmap();

@riverpod
Future<List<({String date, int sessions, int minutes})>> statsFocus(Ref ref) =>
    ref.watch(statsRepositoryProvider).focusStats();

@riverpod
Future<List<({String date, int completed, int created})>> statsTrends(
  Ref ref,
) => ref.watch(statsRepositoryProvider).completionTrends();
