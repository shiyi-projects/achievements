import 'package:achievements/core/constants.dart';
import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'list_repository.g.dart';

class ListRepository {
  ListRepository(this._db);

  final AppDatabase _db;

  /// 监听所有未软删的清单(系统 + 自定义),按 sortOrder 升序。
  Stream<List<TaskList>> watchAll() {
    return (_db.select(_db.taskLists)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .watch();
  }

  /// 监听某文件夹下的清单(folderId=null 表示无文件夹根目录)。
  Stream<List<TaskList>> watchByFolder(String? folderId) {
    final query = _db.select(_db.taskLists)..where((t) => t.deletedAt.isNull());
    if (folderId == null) {
      query.where((t) => t.folderId.isNull());
    } else {
      query.where((t) => t.folderId.equals(folderId));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    return query.watch();
  }

  /// 通过系统类别拉单条清单(用于路由到 Sidebar 内置项)。
  Future<TaskList?> findBySystemKind(SystemListKind kind) {
    return (_db.select(_db.taskLists)
          ..where((t) => t.systemKind.equals(kind.value))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<TaskList?> findById(String id) {
    return (_db.select(_db.taskLists)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }

  /// 首次启动时种入所有系统清单(幂等)。
  Future<void> ensureSystemLists() async {
    return _db.transaction(() async {
      for (var i = 0; i < SystemListKind.values.length; i++) {
        final kind = SystemListKind.values[i];
        final existing = await findBySystemKind(kind);
        if (existing != null) continue;
        await _db
            .into(_db.taskLists)
            .insert(
              TaskListsCompanion.insert(
                id: newId(),
                userId: kLocalUserId,
                name: _displayName(kind),
                isSystem: const Value(true),
                systemKind: Value(kind.value),
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  static String _displayName(SystemListKind kind) {
    switch (kind) {
      case SystemListKind.inbox:
        return 'Inbox';
      case SystemListKind.today:
        return 'Today';
      case SystemListKind.important:
        return 'Important';
      case SystemListKind.planned:
        return 'Planned';
      case SystemListKind.all:
        return 'All Tasks';
      case SystemListKind.completed:
        return 'Completed';
      case SystemListKind.trash:
        return 'Trash';
    }
  }
}

@Riverpod(keepAlive: true)
ListRepository listRepository(Ref ref) {
  return ListRepository(ref.watch(appDatabaseProvider));
}

/// 监听所有清单(Sidebar 用)。
@riverpod
Stream<List<TaskList>> allLists(Ref ref) {
  return ref.watch(listRepositoryProvider).watchAll();
}
