import 'package:achievements/core/constants.dart';
import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_repository.g.dart';

class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  /// 创建一条新任务并落 Drift,返回主键。
  ///
  /// 调用方需保证 [listId] 是真实存在的 TaskList(非系统智能过滤,
  /// 如 today / important 等不可作为 listId)。
  Future<String> createTask({
    required String listId,
    required String title,
    DateTime? dueAt,
    bool starred = false,
  }) async {
    final id = newId();
    await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            userId: kLocalUserId,
            listId: listId,
            title: title,
            dueAt: Value(dueAt),
            starred: Value(starred),
          ),
        );
    return id;
  }

  /// 切换任务完成态:写入 / 清空 completedAt,Drift 自动更新 updatedAt。
  ///
  /// Phase 2 同步引擎接入后,会在 customUpdate 里同步 `version = version + 1`,
  /// 当前 Phase 1 不强依赖,留待迁移。
  Future<void> setCompleted(String id, {required bool completed}) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(completedAt: Value(completed ? DateTime.now() : null)),
    );
  }

  /// 局部更新任务字段。
  ///
  /// 传入 `Value.absent()` 的字段保持不变;显式想清空 [dueAt] 时传 `Value(null)`。
  /// 同步引擎接入后,这里会一并 bump version。
  Future<void> update(
    String id, {
    Value<String> title = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    Value<bool> starred = const Value.absent(),
  }) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: title,
        notes: notes,
        dueAt: dueAt,
        starred: starred,
      ),
    );
  }

  /// 根据 [list] 决定查询策略:系统清单走对应的智能过滤,自定义清单按 listId。
  Stream<List<Task>> watchForList(TaskList list) {
    if (list.isSystem) {
      switch (SystemListKind.fromValue(list.systemKind)) {
        case SystemListKind.today:
          return watchToday();
        case SystemListKind.important:
          return _watchActive((t) => t.starred.equals(true));
        case SystemListKind.planned:
          return _watchPlanned();
        case SystemListKind.all:
          return _watchActive((t) => const Constant(true));
        case SystemListKind.completed:
          return _watchActive((t) => t.completedAt.isNotNull());
        case SystemListKind.trash:
          return _watchTrashed();
        case SystemListKind.inbox:
        case null:
          return watchByListId(list.id);
      }
    }
    return watchByListId(list.id);
  }

  /// 监听今日任务:dueAt 落在今天 00:00 ~ 明日 00:00 之间,且未软删。
  Stream<List<Task>> watchToday() {
    final start = _startOfToday();
    final end = start.add(const Duration(days: 1));
    return _watchActive((t) => t.dueAt.isBetweenValues(start, end));
  }

  Stream<List<Task>> watchByListId(String listId) {
    return _watchActive((t) => t.listId.equals(listId) & t.parentId.isNull());
  }

  Stream<List<Task>> _watchActive(
    Expression<bool> Function($TasksTable) filter,
  ) {
    return (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNull() & filter(t))
          ..orderBy([
            (t) => OrderingTerm(expression: t.completedAt.isNull()),
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Stream<List<Task>> _watchPlanned() {
    final tomorrow = _startOfToday().add(const Duration(days: 1));
    return _watchActive(
      (t) => t.dueAt.isBiggerOrEqualValue(tomorrow) & t.completedAt.isNull(),
    );
  }

  Stream<List<Task>> _watchTrashed() {
    return (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) {
  return TaskRepository(ref.watch(appDatabaseProvider));
}

/// 当前选中清单的任务流。
///
/// 用于 Today / ListPage 等主视图。当 [currentListProvider] 仍在 resolve 时
/// 先 yield 空列表占位。
@riverpod
Stream<List<Task>> tasksForCurrentList(Ref ref) async* {
  final list = await ref.watch(currentListProvider.future);
  if (list == null) {
    yield const <Task>[];
    return;
  }
  yield* ref.watch(taskRepositoryProvider).watchForList(list);
}
