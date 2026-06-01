import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_task.g.dart';

/// 当前打开的任务详情 ID。
///
/// - 桌面 ≥1024:Shell 据此渲染第三列详情面板
/// - 移动:Shell `ref.listen` 此 provider,变化时 showModalBottomSheet
///
/// 关闭详情时调用 [SelectedTaskId.clear]。
@Riverpod(keepAlive: true)
class SelectedTaskId extends _$SelectedTaskId {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties — Riverpod 推荐 method
  void select(String id) => state = id;

  void clear() => state = null;
}

/// 解析为真实 [Task] 行的响应式流;选中 ID 为 null 时发射 null。
///
/// 用 [TaskRepository.watchById] 而非一次性 `getById`,确保任意字段
/// (星标 / 完成态 / 日期等)在 DB 更新后实时反映到详情面板。
@riverpod
Stream<Task?> currentTask(Ref ref) {
  final id = ref.watch(selectedTaskIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(taskRepositoryProvider).watchById(id);
}

/// 当前任务的父任务（面包屑导航用），同样响应式监听。
@riverpod
Stream<Task?> parentTask(Ref ref) {
  final current = ref.watch(currentTaskProvider).valueOrNull;
  if (current == null || current.parentId == null) return Stream.value(null);
  return ref.watch(taskRepositoryProvider).watchById(current.parentId!);
}
