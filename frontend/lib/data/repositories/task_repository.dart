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
    DateTime? remindAt,
    String? repeatRule,
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
              remindAt: Value(remindAt),
              repeatRule: Value(repeatRule),
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
          'remind_at': remindAt?.toUtc().toIso8601String(),
          'repeat_rule': repeatRule,
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

      // 注:重复系列某次的「完成 / 删除」走 setOccurrenceCompleted /
      // deleteOccurrence(实体化 override),不经此普通完成路径。
    });
  }

  // ----------------------------------------------------------------------
  // 重复系列(模板 + 虚拟展开)。展开计算在 RecurrenceService;这里只管 DB 实体化。
  // 见 dev_docs/recurring-tasks.md §3。
  // ----------------------------------------------------------------------

  /// 监听所有重复「模板」:repeat_rule 非空、非 override、未软删。
  /// 日历 / 提醒据此虚拟展开。
  Stream<List<Task>> watchTemplates() {
    return _watchWith(
      (t) =>
          t.userId.equals(_userId) &
          t.deletedAt.isNull() &
          t.recurrenceParentId.isNull() &
          t.repeatRule.isNotNull(),
    );
  }

  /// 监听所有与重复相关的行:模板(repeat_rule 非空)+ override(recurrence_parent_id
  /// 非空)。**含软删 override**(EXDATE 跳过标记)。日历 / 提醒据此一次性展开,避免
  /// 为每个模板各开一条流。模板的软删需调用方自行过滤。
  Stream<List<Task>> watchRecurring() {
    return (_db.select(_db.tasks)..where(
          (t) =>
              t.userId.equals(_userId) &
              (t.repeatRule.isNotNull() | t.recurrenceParentId.isNotNull()),
        ))
        .watch();
  }

  /// 监听某模板的全部 override(**含软删** —— 软删 override 即 EXDATE 跳过标记)。
  Stream<List<Task>> watchOverridesForTemplate(String templateId) {
    return (_db.select(_db.tasks)..where(
          (t) =>
              t.userId.equals(_userId) &
              t.recurrenceParentId.equals(templateId),
        ))
        .watch();
  }

  /// 取某模板的全部 override(含软删),供一次性合并展开。
  Future<List<Task>> getOverridesForTemplate(String templateId) {
    return (_db.select(_db.tasks)..where(
          (t) =>
              t.userId.equals(_userId) &
              t.recurrenceParentId.equals(templateId),
        ))
        .get();
  }

  /// 完成 / 取消完成重复系列的某一次:把该发生点实体化为 override。
  ///
  /// override 主键用确定性 [occurrenceId],多端对同一次操作天然合并。提醒时间按
  /// 模板的 remind-due 偏移继承到该次。
  Future<void> setOccurrenceCompleted({
    required Task template,
    required DateTime occurrence,
    required bool completed,
  }) async {
    await _upsertOverride(
      template: template,
      occurrence: occurrence,
      completedAt: completed ? DateTime.now() : null,
    );
  }

  /// 删除重复系列的某一次(EXDATE):实体化一条软删 override,展开时跳过该发生点。
  Future<void> deleteOccurrence({
    required Task template,
    required DateTime occurrence,
  }) async {
    await _upsertOverride(
      template: template,
      occurrence: occurrence,
      deletedAt: DateTime.now(),
    );
  }

  /// 删除整个重复系列:软删模板及其全部 override。
  Future<void> deleteSeries(String templateId) async {
    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.tasks)..where(
                (t) =>
                    t.userId.equals(_userId) &
                    (t.id.equals(templateId) |
                        t.recurrenceParentId.equals(templateId)),
              ))
              .get();
      final now = DateTime.now();
      for (final row in rows) {
        if (row.deletedAt != null) continue;
        await (_db.update(_db.tasks)..where((t) => t.id.equals(row.id))).write(
          TasksCompanion(deletedAt: Value(now)),
        );
        await _outbox.enqueue(
          entity: 'task',
          op: 'delete',
          entityId: row.id,
          baseVersion: row.version,
          payload: const {},
        );
      }
    });
  }

  /// 实体化(或更新)某发生点的 override 行 + 入 outbox。completedAt / deletedAt
  /// 任意组合:完成→completedAt 非空;取消完成→都为空;删某次→deletedAt 非空。
  Future<void> _upsertOverride({
    required Task template,
    required DateTime occurrence,
    DateTime? completedAt,
    DateTime? deletedAt,
  }) async {
    final id = occurrenceId(template.id, occurrence);
    DateTime? remindAt;
    if (template.remindAt != null && template.dueAt != null) {
      remindAt = occurrence.add(template.remindAt!.difference(template.dueAt!));
    }
    await _db.transaction(() async {
      final existing = await getById(id);
      final now = DateTime.now();
      await _db
          .into(_db.tasks)
          .insertOnConflictUpdate(
            TasksCompanion.insert(
              id: id,
              userId: _userId,
              listId: template.listId,
              title: template.title,
              notes: Value(template.notes),
              priority: Value(template.priority),
              dueAt: Value(occurrence),
              remindAt: Value(remindAt),
              starred: Value(template.starred),
              recurrenceParentId: Value(template.id),
              occurrenceDate: Value(occurrence),
              completedAt: Value(completedAt),
              deletedAt: Value(deletedAt),
              updatedAt: Value(now),
            ),
          );
      // 一律走 upsert 并携带完整字段:override 行往往是「新建即软删」(EXDATE),
      // 若发 `delete` + 空 payload,服务端对不存在的实体幂等 no-op,软删行永远
      // 不会被创建,跳过的发生点无法传播到其他端。deleted_at 显式携带(可为
      // null),与本地 insertOnConflictUpdate 覆盖 deletedAt 的语义对齐。
      await _outbox.enqueue(
        entity: 'task',
        op: 'upsert',
        entityId: id,
        baseVersion: existing?.version ?? 0,
        payload: {
          'list_id': template.listId,
          'title': template.title,
          'notes': template.notes,
          'priority': template.priority,
          'due_at': occurrence.toUtc().toIso8601String(),
          'remind_at': remindAt?.toUtc().toIso8601String(),
          'starred': template.starred,
          'recurrence_parent_id': template.id,
          'occurrence_date': occurrence.toUtc().toIso8601String(),
          'completed_at': completedAt?.toUtc().toIso8601String(),
          'deleted_at': deletedAt?.toUtc().toIso8601String(),
        },
      );
    });
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
    Value<String?> repeatRule = const Value.absent(),
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
          repeatRule: repeatRule,
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
        if (repeatRule.present) 'repeat_rule': repeatRule.value,
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

  /// 永久删除(回收站「永久删除」)。本地物理删行,并 enqueue 一条 `purge`:
  /// 服务端据此写 purged_at 墓碑,其他端 pull 到墓碑后同样物理删本地行;墓碑超过
  /// 保留期由服务端惰性 GC 物理清除。注意必须用 `purge` 而非 `delete`——`delete`
  /// 只软删(deleted_at),会被 pull 当成增量重新落库,导致已永久删除的任务又出现
  /// 在回收站(回收站视图正是 `deletedAt 非空`)。
  Future<void> hardDelete(String id) async {
    await _db.transaction(() async {
      // 递归收集自身 + 全部后代子任务,逐个 purge:服务端 GC 物理删父行时
      // FK CASCADE 带走的子行**不会留墓碑**,其他端收不到;必须由发起端为
      // 每一行显式发 purge。标签关联行同步物理清理(服务端侧随 task 墓碑
      // 在各端落地时一并清)。
      final rows = <Task>[];
      var frontier = <String>[id];
      while (frontier.isNotEmpty) {
        final batch =
            await (_db.select(_db.tasks)..where(
                  (t) =>
                      t.userId.equals(_userId) &
                      (t.id.isIn(frontier) | t.parentId.isIn(frontier)),
                ))
                .get();
        final known = {for (final r in rows) r.id};
        final fresh = [
          for (final r in batch)
            if (!known.contains(r.id)) r,
        ];
        rows.addAll(fresh);
        frontier = [for (final r in fresh) r.id];
      }
      for (final row in rows) {
        await (_db.delete(
          _db.taskTags,
        )..where((tt) => tt.taskId.equals(row.id))).go();
        await (_db.delete(
          _db.tasks,
        )..where((t) => t.id.equals(row.id) & t.userId.equals(_userId))).go();
        await _outbox.enqueue(
          entity: 'task',
          op: 'purge',
          entityId: row.id,
          baseVersion: row.version,
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

  /// 监听单个任务行。详情面板订阅此流,任意字段(星标/完成/日期等)更新后
  /// 实时反映到 UI,无需手动 invalidate。
  Stream<Task?> watchById(String taskId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.id.equals(taskId) & t.userId.equals(_userId)))
        .watchSingleOrNull();
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
