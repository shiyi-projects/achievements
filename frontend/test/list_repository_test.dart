import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/models/list_tree.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userId = 'u-1';
  late AppDatabase db;
  late ListRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ListRepository(db, OutboxRepository(db), userId);
  });
  tearDown(() => db.close());

  Future<String> addTask(String listId, String title) async {
    final id = 'task-$title';
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            userId: userId,
            listId: listId,
            title: title,
          ),
        );
    return id;
  }

  Future<Task> taskById(String id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();

  Future<TaskList> listById(String id) =>
      (db.select(db.taskLists)..where((t) => t.id.equals(id))).getSingle();

  group('create', () {
    test('同级 sortOrder 从 0 起连续,不与系统清单序号纠缠', () async {
      await repo.ensureSystemLists();
      final first = await repo.create(name: 'A');
      final second = await repo.create(name: 'B');

      expect((await listById(first)).sortOrder, 0);
      expect((await listById(second)).sortOrder, 1);
    });

    test('子清单的 sortOrder 在自己这一级独立编号', () async {
      final parent = await repo.create(name: 'P');
      await repo.create(name: 'sibling');
      final child = await repo.create(name: 'C', parentId: parent);

      expect((await listById(child)).sortOrder, 0);
      expect((await listById(child)).parentId, parent);
    });

    test('超过深度上限的新建被拒', () async {
      final a = await repo.create(name: 'a');
      final b = await repo.create(name: 'b', parentId: a);
      final c = await repo.create(name: 'c', parentId: b);

      expect(
        () => repo.create(name: 'd', parentId: c),
        throwsA(
          isA<ListAttachException>().having(
            (e) => e.reason,
            'reason',
            ListAttachError.tooDeep,
          ),
        ),
      );
    });
  });

  group('moveTo', () {
    test('挂到新父节点下并压平两侧同级序号', () async {
      final parent = await repo.create(name: 'P');
      final a = await repo.create(name: 'a');
      final b = await repo.create(name: 'b');

      await repo.moveTo(listId: a, parentId: parent);

      expect((await listById(a)).parentId, parent);
      // b 补上 a 留下的空洞
      expect((await listById(b)).sortOrder, 1);
      expect((await listById(a)).sortOrder, 0);
    });

    test('按 index 插到同级指定位置', () async {
      final a = await repo.create(name: 'a');
      final b = await repo.create(name: 'b');
      final c = await repo.create(name: 'c');

      await repo.moveTo(listId: c, parentId: null, index: 0);

      expect((await listById(c)).sortOrder, 0);
      expect((await listById(a)).sortOrder, 1);
      expect((await listById(b)).sortOrder, 2);
    });

    test('挂到自己的后代下被拒', () async {
      final a = await repo.create(name: 'a');
      final child = await repo.create(name: 'child', parentId: a);

      expect(
        () => repo.moveTo(listId: a, parentId: child),
        throwsA(isA<ListAttachException>()),
      );
    });
  });

  group('softDelete', () {
    test('级联软删子清单与全部任务,并记下来源清单', () async {
      final root = await repo.create(name: 'root');
      final child = await repo.create(name: 'child', parentId: root);
      final rootTask = await addTask(root, 'in-root');
      final childTask = await addTask(child, 'in-child');

      await repo.softDelete(await listById(root));

      expect((await listById(root)).deletedAt, isNotNull);
      expect((await listById(root)).trashedWith, isNull); // 回收站里露出的那条
      expect((await listById(child)).deletedAt, isNotNull);
      expect((await listById(child)).trashedWith, root);
      expect((await taskById(rootTask)).trashedWith, root);
      expect((await taskById(childTask)).trashedWith, root);
    });

    test('系统清单不可删', () async {
      await repo.ensureSystemLists();
      final inbox = (await db.select(db.taskLists).get()).firstWhere(
        (l) => l.systemKind == 'inbox',
      );
      expect(() => repo.softDelete(inbox), throwsA(isA<StateError>()));
    });

    test('回收站只列出被直接删除的清单', () async {
      final root = await repo.create(name: 'root');
      await repo.create(name: 'child', parentId: root);
      await repo.softDelete(await listById(root));

      final trashed = await repo.watchTrashed().first;
      expect(trashed.map((l) => l.id), [root]);
    });
  });

  group('restore', () {
    test('把随它一起删掉的清单与任务一并带回来', () async {
      final root = await repo.create(name: 'root');
      final child = await repo.create(name: 'child', parentId: root);
      final task = await addTask(child, 'x');

      await repo.softDelete(await listById(root));
      await repo.restore(await listById(root));

      expect((await listById(root)).deletedAt, isNull);
      expect((await listById(child)).deletedAt, isNull);
      expect((await listById(child)).trashedWith, isNull);
      expect((await taskById(task)).deletedAt, isNull);
    });

    test('不会复活先前单独删掉的任务', () async {
      final root = await repo.create(name: 'root');
      final keep = await addTask(root, 'keep');
      final gone = await addTask(root, 'gone');
      // 用户先单独删掉一条(trashedWith 为 null)
      await (db.update(db.tasks)..where((t) => t.id.equals(gone))).write(
        TasksCompanion(deletedAt: Value(DateTime(2026))),
      );

      await repo.softDelete(await listById(root));
      await repo.restore(await listById(root));

      expect((await taskById(keep)).deletedAt, isNull);
      expect((await taskById(gone)).deletedAt, isNotNull);
    });

    test('原父清单已不在时上浮到顶层,不留孤儿', () async {
      final parent = await repo.create(name: 'parent');
      final child = await repo.create(name: 'child', parentId: parent);

      await repo.softDelete(await listById(child));
      await repo.softDelete(await listById(parent));
      await repo.restore(await listById(child));

      expect((await listById(child)).parentId, isNull);
      expect((await listById(child)).deletedAt, isNull);
    });
  });

  group('hardDelete', () {
    test('物理删清单子树及其任务', () async {
      final root = await repo.create(name: 'root');
      final child = await repo.create(name: 'child', parentId: root);
      final task = await addTask(child, 'x');
      await repo.softDelete(await listById(root));

      await repo.hardDelete(await listById(root));

      expect(await db.select(db.taskLists).get(), isEmpty);
      expect(await db.select(db.tasks).get(), isEmpty);
      expect(child, isNotEmpty);
      expect(task, isNotEmpty);
    });
  });

  group('findById', () {
    test('已软删的清单一律视为不存在', () async {
      final id = await repo.create(name: 'gone');
      await repo.softDelete(await listById(id));

      expect(await repo.findById(id), isNull);
      expect(await repo.findByIdIncludingTrashed(id), isNotNull);
    });
  });
}
