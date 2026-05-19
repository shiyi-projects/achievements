import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_repository.g.dart';

class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  /// 监听今日任务:dueAt 落在今天 00:00 ~ 明日 00:00 之间,且未软删。
  /// 排序:未完成在前(completedAt 为 null),其次按 sortOrder。
  Stream<List<Task>> watchToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.tasks)
          ..where(
            (t) => t.deletedAt.isNull() & t.dueAt.isBetweenValues(start, end),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.completedAt.isNull()),
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  /// 监听某个清单下的根任务(不含子任务)。
  Stream<List<Task>> watchByListId(String listId) {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.listId.equals(listId) &
                t.parentId.isNull(),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }
}

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) {
  return TaskRepository(ref.watch(appDatabaseProvider));
}

@riverpod
Stream<List<Task>> todayTasks(Ref ref) {
  return ref.watch(taskRepositoryProvider).watchToday();
}
