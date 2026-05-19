import 'package:achievements/data/local/connection.dart';
import 'package:achievements/data/local/tables.dart';
import 'package:drift/drift.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Folders, TaskLists, Tasks, Tags, TaskTags, Outbox, SyncCursors],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openLocalConnection());

  /// 测试用:注入内存 / 自定义 executor。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

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
}
