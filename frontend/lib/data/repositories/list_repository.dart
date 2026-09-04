import 'package:achievements/core/constants.dart';
import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/data/models/list_tree.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'list_repository.g.dart';

/// 清单仓库。
///
/// 清单是一棵自引用树([TaskList.parentId]):任何清单都能直接装任务,也能装
/// 子清单,深度上限 [kMaxListDepth]。系统清单恒为顶层且不参与用户排序。
class ListRepository {
  ListRepository(this._db, this._outbox, this._userId);

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final String _userId;

  // ── 读 ────────────────────────────────────────────────────────────────

  /// 监听所有未软删的清单(系统 + 用户),按 sortOrder 升序。树结构由
  /// `buildListTree` 在内存中组装。
  Stream<List<TaskList>> watchAll() {
    return (_db.select(_db.taskLists)
          ..where((t) => t.userId.equals(_userId) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .watch();
  }

  /// 监听回收站里的清单:被直接删除的那些(`trashedWith` 为 null)。随父清单
  /// 级联进回收站的后代不单独列出,它们跟着根清单一起还原。
  Stream<List<TaskList>> watchTrashed() {
    return (_db.select(_db.taskLists)
          ..where(
            (t) =>
                t.userId.equals(_userId) &
                t.deletedAt.isNotNull() &
                t.trashedWith.isNull(),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// 通过系统类别拉单条清单(用于路由到 Sidebar 内置项)。
  Future<TaskList?> findBySystemKind(SystemListKind kind) {
    return (_db.select(_db.taskLists)
          ..where(
            (t) =>
                t.userId.equals(_userId) &
                t.systemKind.equals(kind.value) &
                t.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// 按 id 取未软删的清单。已删的清单一律视为不存在——否则删掉当前清单后,
  /// 主视图仍会解析出它并继续往里写任务。
  Future<TaskList?> findById(String id) {
    return (_db.select(_db.taskLists)
          ..where(
            (t) =>
                t.id.equals(id) &
                t.userId.equals(_userId) &
                t.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// 按 id 取清单(含已软删)。回收站还原路径专用。
  Future<TaskList?> findByIdIncludingTrashed(String id) {
    return (_db.select(_db.taskLists)
          ..where((t) => t.id.equals(id) & t.userId.equals(_userId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// 子树内全部清单 id(含 [rootId] 自身),仅未软删的行。
  Future<List<String>> subtreeIds(String rootId) async {
    final all = await _activeLists();
    return _subtreeIdsOf(rootId, all);
  }

  // ── 写 ────────────────────────────────────────────────────────────────

  /// 新建用户清单。[parentId] 非空即作为其子清单。
  Future<String> create({
    required String name,
    String? parentId,
    String? color,
    String? icon,
  }) async {
    if (parentId != null) {
      final all = await _activeLists();
      final parent = all.where((l) => l.id == parentId).firstOrNull;
      if (parent == null || parent.isSystem) {
        throw const ListAttachException(ListAttachError.systemList);
      }
      if (depthOf(parentId, all) + 1 > kMaxListDepth) {
        throw const ListAttachException(ListAttachError.tooDeep);
      }
    }
    final id = newId();
    return _db.transaction(() async {
      final nextSort = await _nextSortOrder(parentId);
      await _db
          .into(_db.taskLists)
          .insert(
            TaskListsCompanion.insert(
              id: id,
              userId: _userId,
              name: name,
              parentId: Value(parentId),
              color: Value(color),
              icon: Value(icon),
              sortOrder: Value(nextSort),
              isSystem: const Value(false),
            ),
          );
      await _outbox.enqueue(
        entity: 'list',
        op: 'upsert',
        entityId: id,
        baseVersion: 0,
        payload: {
          'name': name,
          'parent_id': parentId,
          'color': color,
          'icon': icon,
          'sort_order': nextSort,
          'is_system': false,
        },
      );
      return id;
    });
  }

  Future<void> rename(String id, String name) async {
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.taskLists,
      )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).getSingle();
      await (_db.update(_db.taskLists)
            ..where((t) => t.id.equals(id) & t.userId.equals(_userId)))
          .write(TaskListsCompanion(name: Value(name)));
      await _outbox.enqueue(
        entity: 'list',
        op: 'upsert',
        entityId: id,
        baseVersion: current.version,
        payload: {'name': name},
      );
    });
  }

  /// 把清单挂到 [parentId] 之下([parentId] 为 null 即提到顶层),排在同级末尾。
  /// 校验不通过抛 [ListAttachException]。
  Future<void> setParent(String listId, String? parentId) async {
    await moveTo(listId: listId, parentId: parentId);
  }

  /// 把清单移动到 [parentId] 下的第 [index] 个位置。[index] 为 null 时排到末尾。
  ///
  /// 同级 sortOrder 在事务内整体重编号为连续 0..n,变化的行逐个 enqueue,
  /// 避免出现「序号相同靠 name 兜底」的漂移。
  Future<void> moveTo({
    required String listId,
    required String? parentId,
    int? index,
  }) async {
    final all = await _activeLists();
    final moving = all.where((l) => l.id == listId).firstOrNull;
    if (moving == null) return;
    _assertCanAttach(moving: moving, parentId: parentId, all: all);

    final oldParentId = moving.parentId;
    await _db.transaction(() async {
      if (oldParentId != parentId) {
        await (_db.update(_db.taskLists)
              ..where((t) => t.id.equals(listId) & t.userId.equals(_userId)))
            .write(TaskListsCompanion(parentId: Value(parentId)));
        await _outbox.enqueue(
          entity: 'list',
          op: 'upsert',
          entityId: listId,
          baseVersion: moving.version,
          payload: {'parent_id': parentId},
        );
      }

      // 目标同级:排除自身,按现有顺序排好后把自身插到 index。
      final siblings =
          all
              .where(
                (l) => !l.isSystem && l.parentId == parentId && l.id != listId,
              )
              .toList()
            ..sort(_bySortOrder);
      final target = index == null || index > siblings.length
          ? siblings.length
          : (index < 0 ? 0 : index);
      siblings.insert(target, moving);
      await _renumber(siblings);

      // 旧同级留下的空洞一并压平。
      if (oldParentId != parentId) {
        final former =
            all
                .where(
                  (l) =>
                      !l.isSystem &&
                      l.parentId == oldParentId &&
                      l.id != listId,
                )
                .toList()
              ..sort(_bySortOrder);
        await _renumber(former);
      }
    });
  }

  /// 软删清单:自身 + 全部后代清单 + 这些清单下的所有任务一起进回收站。
  ///
  /// 被连带删除的行记 `trashedWith = 根清单 id`,回收站据此整体还原;根清单
  /// 自身的 `trashedWith` 保持 null,它才是回收站里露出的那一条。
  Future<void> softDelete(TaskList list) async {
    if (list.isSystem) {
      throw StateError('System list cannot be deleted: ${list.name}');
    }
    final all = await _activeLists();
    final ids = _subtreeIdsOf(list.id, all);
    final rows = all.where((l) => ids.contains(l.id)).toList();
    final now = DateTime.now();

    await _db.transaction(() async {
      // 1. 子树内所有清单的任务(含子任务与重复 override)一并软删。
      final tasks =
          await (_db.select(_db.tasks)..where(
                (t) =>
                    t.userId.equals(_userId) &
                    t.listId.isIn(ids) &
                    t.deletedAt.isNull(),
              ))
              .get();
      for (final task in tasks) {
        await (_db.update(
          _db.tasks,
        )..where((t) => t.id.equals(task.id) & t.userId.equals(_userId))).write(
          TasksCompanion(deletedAt: Value(now), trashedWith: Value(list.id)),
        );
        // 用 upsert 而非 delete:delete 的 payload 为空,trashed_with 传不到
        // 服务端,其他端就无法把这批任务认成「随清单一起删的」。
        await _outbox.enqueue(
          entity: 'task',
          op: 'upsert',
          entityId: task.id,
          baseVersion: task.version,
          payload: {
            'deleted_at': now.toUtc().toIso8601String(),
            'trashed_with': list.id,
          },
        );
      }

      // 2. 子树内的清单行本身。
      for (final row in rows) {
        final cascaded = row.id == list.id ? null : list.id;
        await (_db.update(
          _db.taskLists,
        )..where((t) => t.id.equals(row.id) & t.userId.equals(_userId))).write(
          TaskListsCompanion(
            deletedAt: Value(now),
            trashedWith: Value(cascaded),
          ),
        );
        await _outbox.enqueue(
          entity: 'list',
          op: 'upsert',
          entityId: row.id,
          baseVersion: row.version,
          payload: {
            'deleted_at': now.toUtc().toIso8601String(),
            'trashed_with': cascaded,
          },
        );
      }
    });
  }

  /// 从回收站还原清单:自身 + 当初随它一起被删的清单与任务。
  ///
  /// 若原父清单已不在(自己也被删了 / 被永久删除),还原后上浮到顶层,避免
  /// 挂在一个不存在的父节点下变成看不见的孤儿。
  Future<void> restore(TaskList list) async {
    final trashedLists =
        await (_db.select(_db.taskLists)..where(
              (t) => t.userId.equals(_userId) & t.trashedWith.equals(list.id),
            ))
            .get();
    final trashedTasks =
        await (_db.select(_db.tasks)..where(
              (t) => t.userId.equals(_userId) & t.trashedWith.equals(list.id),
            ))
            .get();

    // 父节点是否还健在(未删 + 存在)。
    var parentId = list.parentId;
    if (parentId != null) {
      final parent = await findById(parentId);
      if (parent == null) parentId = null;
    }

    await _db.transaction(() async {
      final sortOrder = parentId == list.parentId
          ? null
          : await _nextSortOrder(parentId);
      await (_db.update(
        _db.taskLists,
      )..where((t) => t.id.equals(list.id) & t.userId.equals(_userId))).write(
        TaskListsCompanion(
          deletedAt: const Value(null),
          trashedWith: const Value(null),
          parentId: Value(parentId),
          sortOrder: sortOrder == null
              ? const Value.absent()
              : Value(sortOrder),
        ),
      );
      await _outbox.enqueue(
        entity: 'list',
        op: 'upsert',
        entityId: list.id,
        baseVersion: list.version,
        payload: {
          'deleted_at': null,
          'trashed_with': null,
          'parent_id': parentId,
          if (sortOrder != null) 'sort_order': sortOrder,
        },
      );

      for (final row in trashedLists) {
        await (_db.update(
          _db.taskLists,
        )..where((t) => t.id.equals(row.id) & t.userId.equals(_userId))).write(
          const TaskListsCompanion(
            deletedAt: Value(null),
            trashedWith: Value(null),
          ),
        );
        await _outbox.enqueue(
          entity: 'list',
          op: 'upsert',
          entityId: row.id,
          baseVersion: row.version,
          payload: const {'deleted_at': null, 'trashed_with': null},
        );
      }
      for (final task in trashedTasks) {
        await (_db.update(
          _db.tasks,
        )..where((t) => t.id.equals(task.id) & t.userId.equals(_userId))).write(
          const TasksCompanion(
            deletedAt: Value(null),
            trashedWith: Value(null),
          ),
        );
        await _outbox.enqueue(
          entity: 'task',
          op: 'upsert',
          entityId: task.id,
          baseVersion: task.version,
          payload: const {'deleted_at': null, 'trashed_with': null},
        );
      }
    });
  }

  /// 回收站「永久删除」:物理删清单子树及其全部任务,逐行 enqueue `purge`
  /// 墓碑。服务端 GC 靠 FK CASCADE 带走的子行不会留墓碑,必须由发起端显式
  /// 为每一行发,其他端才收得到。
  Future<void> hardDelete(TaskList list) async {
    final rows =
        await (_db.select(_db.taskLists)..where(
              (t) => t.userId.equals(_userId) & t.trashedWith.equals(list.id),
            ))
            .get();
    final listRows = [list, ...rows];
    final listIds = [for (final l in listRows) l.id];

    await _db.transaction(() async {
      final tasks = await (_db.select(
        _db.tasks,
      )..where((t) => t.userId.equals(_userId) & t.listId.isIn(listIds))).get();
      for (final task in tasks) {
        await (_db.delete(
          _db.taskTags,
        )..where((tt) => tt.taskId.equals(task.id))).go();
        await (_db.delete(
          _db.tasks,
        )..where((t) => t.id.equals(task.id) & t.userId.equals(_userId))).go();
        await _outbox.enqueue(
          entity: 'task',
          op: 'purge',
          entityId: task.id,
          baseVersion: task.version,
          payload: const {},
        );
      }
      for (final row in listRows) {
        await (_db.delete(
          _db.taskLists,
        )..where((t) => t.id.equals(row.id) & t.userId.equals(_userId))).go();
        await _outbox.enqueue(
          entity: 'list',
          op: 'purge',
          entityId: row.id,
          baseVersion: row.version,
          payload: const {},
        );
      }
    });
  }

  /// 首次启动时种入所有系统清单(幂等)。
  ///
  /// 使用 [systemListIdForUser] 这一前后端共用的确定性 UUID 作为主键,确保后续
  /// sync pull 拿到服务端 seed 时通过主键命中既有行(insertOnConflictUpdate),
  /// 不会重复落入第二份系统清单。
  ///
  /// **不入 outbox**:服务端启动时已经用同样的确定性 UUID 自行 seed,这里只是
  /// 让本地数据库就位,不需要再把同样的行 push 回去。
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
                id: systemListIdForUser(_userId, kind),
                userId: _userId,
                name: _displayName(kind),
                isSystem: const Value(true),
                systemKind: Value(kind.value),
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  // ── 内部 ──────────────────────────────────────────────────────────────

  Future<List<TaskList>> _activeLists() {
    return (_db.select(
      _db.taskLists,
    )..where((t) => t.userId.equals(_userId) & t.deletedAt.isNull())).get();
  }

  /// 同级末尾的排序号。系统清单占着 0..6 但不参与用户排序,故顶层只统计
  /// 用户清单——旧实现在全表取 max 才需要 `?? 99` 这种魔法值兜底。
  Future<int> _nextSortOrder(String? parentId) async {
    final query = _db.selectOnly(_db.taskLists)
      ..addColumns([_db.taskLists.sortOrder.max()])
      ..where(
        _db.taskLists.userId.equals(_userId) &
            _db.taskLists.isSystem.equals(false) &
            _db.taskLists.deletedAt.isNull() &
            (parentId == null
                ? _db.taskLists.parentId.isNull()
                : _db.taskLists.parentId.equals(parentId)),
      );
    final row = await query.getSingleOrNull();
    return (row?.read(_db.taskLists.sortOrder.max()) ?? -1) + 1;
  }

  /// 把 [ordered] 按下标重编号,只对真正变化的行落库 + enqueue。
  Future<void> _renumber(List<TaskList> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final row = ordered[i];
      if (row.sortOrder == i) continue;
      await (_db.update(_db.taskLists)
            ..where((t) => t.id.equals(row.id) & t.userId.equals(_userId)))
          .write(TaskListsCompanion(sortOrder: Value(i)));
      await _outbox.enqueue(
        entity: 'list',
        op: 'upsert',
        entityId: row.id,
        baseVersion: row.version,
        payload: {'sort_order': i},
      );
    }
  }

  void _assertCanAttach({
    required TaskList moving,
    required String? parentId,
    required List<TaskList> all,
  }) {
    final reason = checkAttach(moving: moving, parentId: parentId, all: all);
    if (reason != null) throw ListAttachException(reason);
  }

  static List<String> _subtreeIdsOf(String rootId, List<TaskList> all) =>
      subtreeIdsOf(rootId, all);

  static int _bySortOrder(TaskList a, TaskList b) {
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    return bySort != 0 ? bySort : a.name.compareTo(b.name);
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
  return ListRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(currentUserIdProvider),
  );
}

/// 监听所有清单(Sidebar 用)。
@riverpod
Stream<List<TaskList>> allLists(Ref ref) {
  return ref.watch(listRepositoryProvider).watchAll();
}

/// 回收站里的清单条目。
@riverpod
Stream<List<TaskList>> trashedLists(Ref ref) {
  return ref.watch(listRepositoryProvider).watchTrashed();
}

/// 默认 Inbox 清单(系统种子)。Smart filter 视图下的快速创建落到这里。
@Riverpod(keepAlive: true)
Future<TaskList?> inboxList(Ref ref) {
  return ref
      .watch(listRepositoryProvider)
      .findBySystemKind(SystemListKind.inbox);
}

/// 任务可被移动到的目标清单:Inbox + 全部用户清单(树里的任何一级都能装任务)。
/// 其他系统清单(today/important/planned 等)是智能过滤,不存储任务。
@Riverpod(keepAlive: true)
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
