import 'dart:convert';

import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/connection.dart';
import 'package:achievements/data/local/tables.dart';
import 'package:drift/drift.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Folders, TaskLists, Tasks, Tags, TaskTags, Outbox, SyncCursors, FocusSessions, AppPreferences],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openLocalConnection());

  /// 测试用:注入内存 / 自定义 executor。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _createSystemKindUniqueIndex();
      },
      onUpgrade: (m, from, to) async {
        // v1 -> v2:为 Phase 2 同步引擎新增 Outbox 与 SyncCursors
        if (from < 2) {
          await m.createTable(outbox);
          await m.createTable(syncCursors);
        }
        // v2 -> v3:同一 user 同一 system_kind 只能有一行(忽略软删行)。
        // 与后端 alembic d6579144a12c 同步,Sidebar 不会再出现两份系统清单。
        if (from < 3) {
          await _createSystemKindUniqueIndex();
        }
        // v3 -> v4:把旧随机 UUID 系统清单的主键统一修正为前后端共用的固定 UUID。
        // 修复场景:旧版本用随机 UUID 种入系统清单,任务 list_id 指向旧 UUID;
        // push 时服务端只有固定 UUID,触发 FK violation → rejected。
        if (from < 4) {
          await _normalizeSystemListIds();
        }
        // v4 -> v5:新增专注会话表(Phase 3)。
        if (from < 5) {
          await m.createTable(focusSessions);
        }
        // v5 -> v6:新增本地偏好设置表(Phase 4)。
        if (from < 6) {
          await m.createTable(appPreferences);
        }
      },
    );
  }

  Future<void> _createSystemKindUniqueIndex() async {
    // 先把每个 (user_id, system_kind) 重复组里的 keeper(created_at 最早) 与 duplicate
    // 收集到临时表;再把所有指向 duplicate 的 tasks.list_id 改写到 keeper;最后删
    // duplicate 行。这样既消重又不丢任务(否则任务的 list_id 会变成悬挂引用)。
    await customStatement('''
      CREATE TEMP TABLE _dup_system_lists AS
      SELECT tl.id AS dup_id,
             (SELECT k.id FROM task_lists k
               WHERE k.user_id = tl.user_id
                 AND k.system_kind = tl.system_kind
                 AND k.deleted_at IS NULL
               ORDER BY k.created_at ASC LIMIT 1) AS keeper_id
      FROM task_lists tl
      WHERE tl.deleted_at IS NULL AND tl.system_kind IS NOT NULL
    ''');
    await customStatement('''
      UPDATE tasks
         SET list_id = (SELECT keeper_id FROM _dup_system_lists
                         WHERE dup_id = tasks.list_id)
       WHERE list_id IN (SELECT dup_id FROM _dup_system_lists
                          WHERE dup_id <> keeper_id)
    ''');
    await customStatement('''
      DELETE FROM task_lists
       WHERE id IN (SELECT dup_id FROM _dup_system_lists
                     WHERE dup_id <> keeper_id)
    ''');
    await customStatement('DROP TABLE _dup_system_lists');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_task_lists_user_system_kind_active '
      'ON task_lists (user_id, system_kind) '
      'WHERE deleted_at IS NULL AND system_kind IS NOT NULL',
    );
  }

  /// v3→v4:把旧随机 UUID 系统清单迁移到前后端共用的固定 UUID。
  ///
  /// 对每个 [SystemListKind]:若本地存在 system_kind 匹配但 id 不等于固定 UUID 的行,
  /// 则把所有 tasks.list_id 改写到固定 UUID,更新 outbox payload 里的 list_id 引用,
  /// 删除旧行并以固定 UUID 写入替代行。对没有 outbox entry 的受影响 tasks 补录一条
  /// 完整 upsert,使其在下次 push 时能正确同步到服务端。
  Future<void> _normalizeSystemListIds() async {
    for (final kind in SystemListKind.values) {
      final fixedId = kind.id;

      // 找出 system_kind 匹配但 id 不是固定值的行(可能有多条旧随机 UUID)
      final wrongs =
          await (select(taskLists)
                ..where(
                  (t) =>
                      t.systemKind.equals(kind.value) &
                      t.deletedAt.isNull() &
                      t.id.equals(fixedId).not(),
                ))
              .get();

      for (final old in wrongs) {
        // 1. 记录受影响的 tasks(用于后续补录 outbox)
        final affected =
            await (select(tasks)
                  ..where(
                    (t) =>
                        t.listId.equals(old.id) & t.deletedAt.isNull(),
                  ))
                .get();

        // 2. 把 tasks.list_id 从旧 UUID 改为固定 UUID
        await (update(tasks)..where((t) => t.listId.equals(old.id)))
            .write(TasksCompanion(listId: Value(fixedId)));

        // 3. 修正 outbox 中 task 类型条目的 payload.list_id
        await customStatement(
          r"UPDATE outbox SET payload = json_replace(payload, '$.list_id', ?1) "
          r"WHERE entity = 'task' AND json_extract(payload, '$.list_id') = ?2",
          [fixedId, old.id],
        );

        // 4. 修正 outbox 中 list 类型条目的 entity_id
        await customStatement(
          "UPDATE outbox SET entity_id = ?1 WHERE entity = 'list' AND entity_id = ?2",
          [fixedId, old.id],
        );

        // 5. 删除旧系统清单行(tasks.list_id 已改写,无悬挂引用)
        await (delete(taskLists)..where((t) => t.id.equals(old.id))).go();

        // 6. 以固定 UUID 写入系统清单(若固定 UUID 行已存在则更新 meta)
        await into(taskLists).insertOnConflictUpdate(
          TaskListsCompanion.insert(
            id: fixedId,
            userId: old.userId,
            name: old.name,
            isSystem: const Value(true),
            systemKind: Value(old.systemKind),
            sortOrder: Value(old.sortOrder),
            version: Value(old.version),
          ),
        );

        // 7. 对没有 pending outbox entry 的 tasks 补录完整 upsert
        //    (防止先前因 FK rejected 而丢失 outbox 的任务永远无法同步)
        for (final task in affected) {
          final existing =
              await (select(outbox)
                    ..where(
                      (t) =>
                          t.entity.equals('task') &
                          t.entityId.equals(task.id),
                    )
                    ..limit(1))
                  .get();
          if (existing.isEmpty) {
            await into(outbox).insert(
              OutboxCompanion.insert(
                entity: 'task',
                op: 'upsert',
                entityId: task.id,
                payload: _taskPayloadJson(task, fixedId),
                baseVersion: Value(task.version),
              ),
            );
          }
        }
      }
    }
  }

  static String _taskPayloadJson(Task task, String listId) {
    return jsonEncode(<String, dynamic>{
      'list_id': listId,
      'title': task.title,
      'parent_id': task.parentId,
      'notes': task.notes,
      'priority': task.priority,
      'due_at': task.dueAt?.toUtc().toIso8601String(),
      'remind_at': task.remindAt?.toUtc().toIso8601String(),
      'repeat_rule': task.repeatRule,
      'sort_order': task.sortOrder,
      'completed_at': task.completedAt?.toUtc().toIso8601String(),
      'archived_at': task.archivedAt?.toUtc().toIso8601String(),
      'starred': task.starred,
      'deleted_at': task.deletedAt?.toUtc().toIso8601String(),
    });
  }
}
