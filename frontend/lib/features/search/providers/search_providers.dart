import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 搜索栏是否展开。
final searchActiveProvider = StateProvider<bool>((ref) => false);

/// 当前搜索关键词。
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 搜索结果(异步)。query 为空时直接返回空列表,不访问数据库。
final searchResultsProvider = FutureProvider<List<Task>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const <Task>[];
  return ref.read(taskRepositoryProvider).searchTasks(query);
});

/// 关闭搜索并清空状态。
void closeSearch(WidgetRef ref) {
  ref.read(searchQueryProvider.notifier).state = '';
  ref.read(searchActiveProvider.notifier).state = false;
}
