import 'package:achievements/core/constants.dart';
import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_repository.g.dart';

typedef _TaskFilter = Expression<bool> Function($TasksTable);

class TaskRepository {
  TaskRepository(this._db, this._outbox, this._userId);

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final String _userId;

  /// 创建一条新任务并落 Drift,返回主键。
  Future<String> createTask({
    required String listId,
    required String title,
    String? parentId,
    DateTime? dueAt,
    bool starred = false,
    int? estimatedMinutes,
  }) async {
    final id = newId();
    return _db.transaction(() async {
      await _db
          .into(_db.tasks)
          .insert(
            TasksCompanion.insert(
              id: id,
              userId: _userId,
              listId: listId,
              title: title,
              parentId: Value(parentId),
              dueAt: Value(dueAt),
              starred: Value(starred),
              estimatedMinutes: Value(estimatedMinutes),
            ),
          );
      await _outbox.enqueue(
        entity: 'task',
        op: 'upsert',
        entityId: id,
        baseVersion: 0,
        payload: {
          'list_id': listId,
          'title': title,
          'parent_id': parentId,
          'due_at': dueAt?.toUtc().toIso8601String(),
          'starred': starred,
          'estimated_minutes': estimatedMinutes,
        },
      );
      return id;
    });
  }

  /// 监听某父任务的直接子任务(单层)。
  Stream<List<Task>> watchSubtasks(String parentId) {
    return _watchWith(
      (t) =>
          t.userId.equals(_userId) &
          t.deletedAt.isNull() &
          t.parentId.equals(parentId),
    );
  }

  Future<void> setCompleted(String id, {required bool completed}) async {
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).getSingle();
      final completedAt = completed ? DateTime.now() : null;
      await (_db.update(_db.tasks)
            ..where((t) => t.id.equals(id) & t.userId.equals(_userId)))
          .write(TasksCompanion(completedAt: Value(completedAt)));
      await _outbox.enqueue(
        entity: 'task',
        op: 'upsert',
        entityId: id,
        baseVersion: current.version,
        payload: {'completed_at': completedAt?.toUtc().toIso8601String()},
      );

      // 完成重复任务时生成下一实例
      if (completed) await _maybeCreateNextRepeat(current);
    });
  }

  Future<void> _maybeCreateNextRepeat(Task current) async {
    final rule = current.repeatRule;
    if (rule == null || rule.isEmpty) return;
    final nextDue = _nextOccurrence(rule, current.dueAt);
    if (nextDue == null) return;

    DateTime? nextRemind;
    if (current.remindAt != null && current.dueAt != null) {
      final offset = current.remindAt!.difference(current.dueAt!);
      nextRemind = nextDue.add(offset);
    }

    final nextId = newId();
    await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            id: nextId,
            userId: _userId,
            listId: current.listId,
            title: current.title,
            notes: Value(current.notes),
            priority: Value(current.priority),
            dueAt: Value(nextDue),
            remindAt: Value(nextRemind),
            repeatRule: Value(rule),
            starred: Value(current.starred),
          ),
        );
    await _outbox.enqueue(
      entity: 'task',
      op: 'upsert',
      entityId: nextId,
      baseVersion: 0,
      payload: {
        'list_id': current.listId,
        'title': current.title,
        'notes': current.notes,
        'priority': current.priority,
        'due_at': nextDue.toUtc().toIso8601String(),
        'remind_at': nextRemind?.toUtc().toIso8601String(),
        'repeat_rule': rule,
        'starred': current.starred,
      },
    );
  }

  /// 支持的重复规则:DAILY / WEEKLY / MONTHLY / YEARLY。
  static DateTime? _nextOccurrence(String rule, DateTime? from) {
    final base = from ?? DateTime.now();
    switch (rule.toUpperCase()) {
      case 'DAILY':
        return base.add(const Duration(days: 1));
      case 'WEEKLY':
        return base.add(const Duration(days: 7));
      case 'MONTHLY':
        return DateTime(
          base.year,
          base.month + 1,
          base.day,
          base.hour,
          base.minute,
        );
      case 'YEARLY':
        return DateTime(
          base.year + 1,
          base.month,
          base.day,
          base.hour,
          base.minute,
        );
      default:
        return null;
    }
  }

  /// 局部更新任务字段。传入 `Value.absent()` 的字段保持不变。
  ///
  /// [knownVersion] 由调用方传入(通常来自已持有的 Task 对象),跳过
  /// 额外的 SELECT 查询;未传入时回退到事务内读取(兼容旧调用路径)。
  Future<void> update(
    String id, {
    int? knownVersion,
    Value<String> title = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    Value<DateTime?> remindAt = const Value.absent(),
    Value<bool> starred = const Value.absent(),
    Value<int> priority = const Value.absent(),
    Value<String> listId = const Value.absent(),
    Value<int?> estimatedMinutes = const Value.absent(),
  }) async {
    await _db.transaction(() async {
      final version =
          knownVersion ??
          (await (_db.select(_db.tasks)
                    ..where((t) => t.id.equals(id) & t.userId.equals(_userId)))
                  .getSingle())
              .version;
      await (_db.update(
        _db.tasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).write(
        TasksCompanion(
          title: title,
          notes: notes,
          dueAt: dueAt,
          remindAt: remindAt,
          starred: starred,
          priority: priority,
          listId: listId,
          estimatedMinutes: estimatedMinutes,
        ),
      );
      final payload = <String, dynamic>{
        if (title.present) 'title': title.value,
        if (notes.present) 'notes': notes.value,
        if (dueAt.present) 'due_at': dueAt.value?.toUtc().toIso8601String(),
        if (remindAt.present)
          'remind_at': remindAt.value?.toUtc().toIso8601String(),
        if (starred.present) 'starred': starred.value,
        if (priority.present) 'priority': priority.value,
        if (listId.present) 'list_id': listId.value,
        if (estimatedMinutes.present)
          'estimated_minutes': estimatedMinutes.value,
      };
      if (payload.isEmpty) return;
      await _outbox.enqueue(
        entity: 'task',
        op: 'upsert',
        entityId: id,
        baseVersion: version,
        payload: payload,
      );
    });
  }

  /// 监听指定日期范围内有 due_at 的任务(日历视图用)。
  Stream<List<Task>> watchTasksInRange(DateTime from, DateTime to) {
    return _watchWith(
      (t) => t.deletedAt.isNull() & t.dueAt.isBetweenValues(from, to),
    );
  }

  /// 按标题 / 备注全文搜索(本地 LIKE)。最多返回 [limit] 条,按 updatedAt 倒序。
  Future<List<Task>> searchTasks(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    final pattern = '%${query.toLowerCase()}%';
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.userId.equals(_userId) &
                t.deletedAt.isNull() &
                (t.title.lower().like(pattern) | t.notes.lower().like(pattern)),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  /// 监听所有"待提醒"任务:remind_at 非空,未完成,未软删。
  /// ReminderScheduler 据此 reconcile 本地通知排程。
  Stream<List<Task>> watchTasksWithActiveReminders() {
    return _watchWith(
      (t) =>
          t.userId.equals(_userId) &
          t.remindAt.isNotNull() &
          t.completedAt.isNull() &
          t.deletedAt.isNull(),
    );
  }

  /// 查询所有已到期的提醒：remind_at <= now，未完成，未删除。
  /// [ReminderChecker] 前台轮询时使用。
  Future<List<Task>> findDueReminders() async {
    final now = DateTime.now();
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.userId.equals(_userId) &
                t.remindAt.isNotNull() &
                t.remindAt.isSmallerOrEqualValue(now) &
                t.completedAt.isNull() &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.remindAt)]))
        .get();
  }

  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).getSingle();
      await (_db.update(_db.tasks)
            ..where((t) => t.id.equals(id) & t.userId.equals(_userId)))
          .write(TasksCompanion(deletedAt: Value(DateTime.now())));
      await _outbox.enqueue(
        entity: 'task',
        op: 'delete',
        entityId: id,
        baseVersion: current.version,
        payload: const {},
      );
    });
  }

  Future<void> restore(String id) async {
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).getSingle();
      await (_db.update(_db.tasks)
            ..where((t) => t.id.equals(id) & t.userId.equals(_userId)))
          .write(const TasksCompanion(deletedAt: Value(null)));
      await _outbox.enqueue(
        entity: 'task',
        op: 'upsert',
        entityId: id,
        baseVersion: current.version,
        payload: const {'deleted_at': null},
      );
    });
  }

  /// 硬删本地行。同步语义降级为 server 软删:enqueue 一条 delete,服务端
  /// 据此把 deleted_at 写上,其他端 pull 后也变成软删。本地行已经物理消失,
  /// 后续 pull 回来 server 那行的 deleted_at 时,本地不会再恢复(insertOnConflictUpdate
  /// 仍会落,但 UI 查询都过滤了 deletedAt 非空,效果等价于不可见)。
  Future<void> hardDelete(String id) async {
    await _db.transaction(() async {
      final current =
          await (_db.select(_db.tasks)
                ..where((t) => t.id.equals(id) & t.userId.equals(_userId)))
              .getSingleOrNull();
      await (_db.delete(
        _db.tasks,
      )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).go();
      if (current != null) {
        await _outbox.enqueue(
          entity: 'task',
          op: 'delete',
          entityId: id,
          baseVersion: current.version,
          payload: const {},
        );
      }
    });
  }

  /// 单一事实源:根据 [list] 计算 WHERE 表达式。watchForList /
  /// watchCountForList 共用,保证视觉列表与 Sidebar 徽标数字一致。
  _TaskFilter _filterFor(TaskList list) {
    if (list.isSystem) {
      switch (SystemListKind.fromValue(list.systemKind)) {
        case SystemListKind.today:
          final start = _startOfToday();
          final end = start.add(const Duration(days: 1));
          return (t) =>
              t.userId.equals(_userId) &
              t.deletedAt.isNull() &
              t.dueAt.isBetweenValues(start, end);
        case SystemListKind.important:
          return (t) =>
              t.userId.equals(_userId) &
              t.deletedAt.isNull() &
              t.starred.equals(true);
        case SystemListKind.planned:
          final tomorrow = _startOfToday().add(const Duration(days: 1));
          return (t) =>
              t.userId.equals(_userId) &
              t.deletedAt.isNull() &
              t.dueAt.isBiggerOrEqualValue(tomorrow) &
              t.completedAt.isNull();
        case SystemListKind.all:
          return (t) => t.userId.equals(_userId) & t.deletedAt.isNull();
        case SystemListKind.completed:
          return (t) =>
              t.userId.equals(_userId) &
              t.deletedAt.isNull() &
              t.completedAt.isNotNull();
        case SystemListKind.trash:
          return (t) => t.userId.equals(_userId) & t.deletedAt.isNotNull();
        case SystemListKind.inbox:
        case null:
          return (t) =>
              t.userId.equals(_userId) &
              t.deletedAt.isNull() &
              t.listId.equals(list.id) &
              t.parentId.isNull();
      }
    }
    return (t) =>
        t.userId.equals(_userId) &
        t.deletedAt.isNull() &
        t.listId.equals(list.id) &
        t.parentId.isNull();
  }

  Stream<List<Task>> watchForList(TaskList list) {
    return _watchWith(
      _filterFor(list),
      reverseForTrash: list.systemKind == 'trash',
    );
  }

  /// 监听某清单的任务数量(Sidebar 徽标);与 [watchForList] 同口径。
  Stream<int> watchCountForList(TaskList list) {
    final filter = _filterFor(list);
    final countExpr = _db.tasks.id.count();
    final query = _db.selectOnly(_db.tasks)
      ..addColumns([countExpr])
      ..where(filter(_db.tasks));
    return query.map((row) => row.read(countExpr) ?? 0).watchSingle();
  }

  Stream<List<Task>> _watchWith(
    _TaskFilter filter, {
    bool reverseForTrash = false,
  }) {
    final query = _db.select(_db.tasks)..where(filter);
    if (reverseForTrash) {
      query.orderBy([
        (t) => OrderingTerm(expression: t.deletedAt, mode: OrderingMode.desc),
      ]);
    } else {
      query.orderBy([
        (t) => OrderingTerm(expression: t.completedAt.isNull()),
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    }
    return query.watch();
  }

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 根据 ID 获取单个任务。
  Future<Task?> getById(String taskId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.id.equals(taskId) & t.userId.equals(_userId)))
        .getSingleOrNull();
  }

  /// 累加任务的专注时长（秒）。
  Future<void> addFocusedSeconds(String taskId, int seconds) async {
    final task = await getById(taskId);
    if (task == null || seconds <= 0) return;
    await (_db.update(
      _db.tasks,
    )..where((t) => t.id.equals(taskId) & t.userId.equals(_userId))).write(
      TasksCompanion(focusedSeconds: Value(task.focusedSeconds + seconds)),
    );
  }
}

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) {
  return TaskRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(currentUserIdProvider),
  );
}

/// 当前选中清单的任务流(主视图用)。
@riverpod
Stream<List<Task>> tasksForCurrentList(Ref ref) async* {
  final list = await ref.watch(currentListProvider.future);
  if (list == null) {
    yield const <Task>[];
    return;
  }
  yield* ref.watch(taskRepositoryProvider).watchForList(list);
}

/// 监听某父任务的直接子任务。
@riverpod
Stream<List<Task>> subtasksOf(Ref ref, String parentId) {
  return ref.watch(taskRepositoryProvider).watchSubtasks(parentId);
}

/// 某清单的任务数量(Sidebar 徽标)。家族参数用 listId 字符串避免在
/// codegen 端引入 Drift 数据类的等值/哈希依赖。
@riverpod
Stream<int> taskCountForListId(Ref ref, String listId) async* {
  final list = await ref.watch(listRepositoryProvider).findById(listId);
  if (list == null) {
    yield 0;
    return;
  }
  yield* ref.watch(taskRepositoryProvider).watchCountForList(list);
}

/// 日历视图:指定月份内有 due_at 的任务流。[monthStart] 为当月 1 日 00:00。
@riverpod
Stream<List<Task>> tasksForMonth(Ref ref, DateTime monthStart) {
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1);
  return ref
      .watch(taskRepositoryProvider)
      .watchTasksInRange(monthStart, monthEnd);
}
