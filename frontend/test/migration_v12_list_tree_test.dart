import 'package:achievements/data/local/database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// schema v11 → v12:`folders` 并入 `task_lists`(清单自引用树)。
///
/// 这条迁移动的是既有用户的真实数据,出错就是「文件夹连同里面的清单一起
/// 消失」,所以在这里按旧结构造一份库跑一遍真迁移。
void main() {
  const userId = 'u-1';
  const ts = 1767225600; // 2026-01-01,drift 的 datetime 默认存 unix 秒

  /// 按 v11 结构建库并塞入数据,user_version=11 让 drift 走 onUpgrade。
  AppDatabase openLegacy() {
    return AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute('''
              CREATE TABLE folders (
                id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted_at INTEGER,
                version INTEGER NOT NULL DEFAULT 1,
                name TEXT NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (id)
              )
            ''')
            ..execute('''
              CREATE TABLE task_lists (
                id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted_at INTEGER,
                version INTEGER NOT NULL DEFAULT 1,
                folder_id TEXT,
                name TEXT NOT NULL,
                color TEXT,
                icon TEXT,
                sort_order INTEGER NOT NULL DEFAULT 0,
                is_system INTEGER NOT NULL DEFAULT 0,
                system_kind TEXT,
                PRIMARY KEY (id)
              )
            ''')
            ..execute('''
              CREATE TABLE tasks (
                id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted_at INTEGER,
                version INTEGER NOT NULL DEFAULT 1,
                list_id TEXT NOT NULL,
                title TEXT NOT NULL,
                priority INTEGER NOT NULL DEFAULT 0,
                sort_order INTEGER NOT NULL DEFAULT 0,
                starred INTEGER NOT NULL DEFAULT 0,
                focused_seconds INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (id)
              )
            ''')
            // 文件夹「Work」,下挂清单「Sprint」;另有一个根清单「Later」。
            ..execute('''
              INSERT INTO folders (id, user_id, created_at, updated_at, name, sort_order)
              VALUES ('f1', '$userId', $ts, $ts, 'Work', 0)
            ''')
            ..execute('''
              INSERT INTO task_lists
                (id, user_id, created_at, updated_at, folder_id, name, sort_order, is_system)
              VALUES ('l1', '$userId', $ts, $ts, 'f1', 'Sprint', 5, 0)
            ''')
            ..execute('''
              INSERT INTO task_lists
                (id, user_id, created_at, updated_at, folder_id, name, sort_order, is_system)
              VALUES ('l2', '$userId', $ts, $ts, NULL, 'Later', 6, 0)
            ''')
            ..execute('''
              INSERT INTO tasks (id, user_id, created_at, updated_at, list_id, title)
              VALUES ('t1', '$userId', $ts, $ts, 'l1', 'Ship it')
            ''')
            ..execute('PRAGMA user_version = 11');
        },
      ),
    );
  }

  late AppDatabase db;

  setUp(() async {
    db = openLegacy();
    // 任意一次查询触发 drift 打开连接并跑迁移。
    await db.select(db.taskLists).get();
  });
  tearDown(() => db.close());

  test('文件夹变成顶层清单,原 id 保留(同步主键不错位)', () async {
    final folderAsList = await (db.select(
      db.taskLists,
    )..where((t) => t.id.equals('f1'))).getSingle();

    expect(folderAsList.name, 'Work');
    expect(folderAsList.parentId, isNull);
    expect(folderAsList.isSystem, isFalse);
  });

  test('原先挂在文件夹下的清单成为它的子清单', () async {
    final sprint = await (db.select(
      db.taskLists,
    )..where((t) => t.id.equals('l1'))).getSingle();
    expect(sprint.parentId, 'f1');
  });

  test('顶层重编号为连续序号,文件夹仍排在原根清单之前', () async {
    final tops =
        await (db.select(db.taskLists)
              ..where((t) => t.parentId.isNull())
              ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
            .get();

    expect(tops.map((l) => l.id), ['f1', 'l2']);
    expect(tops.map((l) => l.sortOrder), [0, 1]);
  });

  test('folders 表与 folder_id 列都已消失', () async {
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(tables.map((r) => r.data['name']), isNot(contains('folders')));

    final columns = await db
        .customSelect('PRAGMA table_info(task_lists)')
        .get();
    final names = columns.map((r) => r.data['name']).toSet();
    expect(names, isNot(contains('folder_id')));
    expect(names, contains('parent_id'));
    expect(names, contains('trashed_with'));
  });

  test('任务不受影响,仍挂在原清单上', () async {
    final task = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals('t1'))).getSingle();
    expect(task.listId, 'l1');
    expect(task.trashedWith, isNull);
  });
}
