import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Search local state providers
// ─────────────────────────────────────────────────────────────────────

/// 当前搜索关键词。空字符串表示未激活搜索。
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 搜索结果(异步)。query 为空时直接返回空列表,不访问数据库。
final searchResultsProvider = FutureProvider<List<Task>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const <Task>[];
  return ref.read(taskRepositoryProvider).searchTasks(query);
});

/// 最近搜索词列表(内存驻留,最多保留 10 条)。
final recentSearchesProvider = StateProvider<List<String>>((ref) => const []);

// ─────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────

/// 将 [query] 添加到最近搜索列表的前端,去重并限制最多 10 条。
void addRecentSearch(WidgetRef ref, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return;

  final current = ref.read(recentSearchesProvider);
  final updated = [
    trimmed,
    ...current.where((s) => s != trimmed),
  ].take(10).toList();

  ref.read(recentSearchesProvider.notifier).state = updated;
}
