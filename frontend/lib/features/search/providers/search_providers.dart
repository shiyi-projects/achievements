import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前搜索关键词。由全局命令面板(Ctrl+K)写入,关闭面板时重置为空串。
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 搜索结果(异步)。query 为空时直接返回空列表,不访问数据库。
final searchResultsProvider = FutureProvider<List<Task>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return const <Task>[];
  return ref.read(taskRepositoryProvider).searchTasks(query);
});
