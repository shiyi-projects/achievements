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
    // 先删除重复行：保留 created_at 最早的那一条，删掉其余的。
    await customStatement('''
      DELETE FROM task_lists
      WHERE id IN (
        SELECT tl.id FROM task_lists tl
        WHERE tl.deleted_at IS NULL AND tl.system_kind IS NOT NULL
          AND tl.id != (
            SELECT tl2.id FROM task_lists tl2
            WHERE tl2.user_id = tl.user_id
              AND tl2.system_kind = tl.system_kind
              AND tl2.deleted_at IS NULL
            ORDER BY tl2.created_at ASC
            LIMIT 1
          )
      )
    ''');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_task_lists_user_system_kind_active '
      'ON task_lists (user_id, system_kind) '
      'WHERE deleted_at IS NULL AND system_kind IS NOT NULL',
    );
  }
}
