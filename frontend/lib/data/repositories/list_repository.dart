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

  /// 新建用户清单。可指定 folderId 归到某文件夹。
  Future<String> create({
    required String name,
    String? folderId,
    String? color,
    String? icon,
  }) async {
    final id = newId();
    final lastSort = await (_db.selectOnly(
      _db.taskLists,
    )..addColumns([_db.taskLists.sortOrder.max()])).getSingleOrNull();
    final nextSort = (lastSort?.read(_db.taskLists.sortOrder.max()) ?? 99) + 1;
    await _db
        .into(_db.taskLists)
        .insert(
          TaskListsCompanion.insert(
            id: id,
            userId: kLocalUserId,
            name: name,
            folderId: Value(folderId),
            color: Value(color),
            icon: Value(icon),
            sortOrder: Value(nextSort),
            isSystem: const Value(false),
          ),
        );
    return id;
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.taskLists)..where((t) => t.id.equals(id))).write(
      TaskListsCompanion(name: Value(name)),
    );
  }

  /// 软删用户清单。系统清单抛 [StateError]。
  Future<void> softDelete(TaskList list) async {
    if (list.isSystem) {
      throw StateError('System list cannot be deleted: ${list.name}');
    }
    await (_db.update(_db.taskLists)..where((t) => t.id.equals(list.id))).write(
      TaskListsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  /// 把清单挂到某个文件夹下(folderId=null 即移出文件夹)。
  Future<void> setFolder(String listId, String? folderId) async {
    await (_db.update(_db.taskLists)..where((t) => t.id.equals(listId))).write(
      TaskListsCompanion(folderId: Value(folderId)),
    );
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

/// 默认 Inbox 清单(系统种子)。Smart filter 视图下的快速创建落到这里。
@Riverpod(keepAlive: true)
Future<TaskList?> inboxList(Ref ref) {
  return ref
      .watch(listRepositoryProvider)
      .findBySystemKind(SystemListKind.inbox);
}

/// 任务可被移动到的目标清单:Inbox + 全部用户自定义清单。其他系统清单
/// (today/important/planned 等)是智能过滤,不存储任务,无法作为目标。
@riverpod
List<TaskList> movableLists(Ref ref) {
  final all = ref
      .watch(allListsProvider)
      .maybeWhen(data: (list) => list, orElse: () => const <TaskList>[]);
  return [
    for (final l in all)
      if (!l.isSystem ||
          SystemListKind.fromValue(l.systemKind) == SystemListKind.inbox)
        l,
  ];
}
