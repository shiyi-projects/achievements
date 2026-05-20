import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
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

/// 解析为真实 [Task] 行的流;选中 ID 为 null 时 yield null。
@riverpod
Stream<Task?> currentTask(Ref ref) async* {
  final id = ref.watch(selectedTaskIdProvider);
  if (id == null) {
    yield null;
    return;
  }
  final db = ref.watch(appDatabaseProvider);
  yield* (db.select(
    db.tasks,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();
}

/// 当前任务的父任务（面包屑导航用）。
///
/// 若当前任务有 [Task.parentId]，从 DB 实时查询父任务行；
/// 否则 yield null。
@riverpod
Stream<Task?> parentTask(Ref ref) async* {
  final current = ref.watch(currentTaskProvider).valueOrNull;
  if (current == null || current.parentId == null) {
    yield null;
    return;
  }
  final db = ref.watch(appDatabaseProvider);
  yield* (db.select(db.tasks)
        ..where((t) => t.id.equals(current.parentId!)))
      .watchSingleOrNull();
}
