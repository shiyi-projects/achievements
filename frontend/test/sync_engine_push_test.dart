import 'dart:convert';

import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:dio/dio.dart';
// drift 也导出 isNull / isNotNull(列表达式版),与 matcher 的同名匹配器冲突。
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// push 响应的假服务端:按调用序号返回预设的 results,并把每次收到的请求体
/// 记下来,好断言重发时带的 base_version。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.responses);

  /// 每次调用依次取一个;取完后重复最后一个。
  final List<List<Map<String, dynamic>>> responses;
  final List<List<Map<String, dynamic>>> sentMutations = [];

  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data as Map<String, dynamic>;
    sentMutations.add([
      for (final m in body['mutations'] as List) m as Map<String, dynamic>,
    ]);
    final idx = calls < responses.length ? calls : responses.length - 1;
    calls++;
    return ResponseBody.fromString(
      jsonEncode({'cursor': '2026-01-01T00:00:00Z', 'results': responses[idx]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const userId = 'u-1';
  const taskId = 't-7f3a';

  late AppDatabase db;
  late OutboxRepository outbox;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
  });
  tearDown(() => db.close());

  Future<void> seedTask({
    int version = 1,
    DateTime? deletedAt,
    String title = '交年报',
  }) async {
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: taskId,
            userId: userId,
            listId: 'l-1',
            title: title,
            version: Value(version),
            deletedAt: Value(deletedAt),
          ),
        );
  }

  Future<Task> readTask() =>
      (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingle();

  SyncEngine engineWith(_FakeAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = adapter;
    return SyncEngine(dio: dio, outbox: outbox, db: db, userId: userId);
  }

  test('applied 的 delete 会回写服务端 version(不再永久落后一格)', () async {
    await seedTask(version: 1);
    await outbox.enqueue(
      entity: 'task',
      op: 'delete',
      entityId: taskId,
      baseVersion: 1,
      payload: const {},
    );

    final adapter = _FakeAdapter([
      [
        {'entity': 'task', 'id': taskId, 'status': 'applied', 'version': 2},
      ],
    ]);
    final status = await engineWith(adapter).pushOnce();

    expect(status, SyncStatus.idle);
    expect((await readTask()).version, 2, reason: 'delete 的新 version 必须回写');
    expect(await outbox.pending(), isEmpty);
  });

  test('applied 的 purge 回写不报错(本地行已物理删除,UPDATE 影响 0 行)', () async {
    // 本地行已被 hardDelete 物理删除,只剩 outbox 里的 purge。
    await outbox.enqueue(
      entity: 'task',
      op: 'purge',
      entityId: taskId,
      baseVersion: 2,
      payload: const {},
    );

    final adapter = _FakeAdapter([
      [
        {'entity': 'task', 'id': taskId, 'status': 'applied', 'version': 3},
      ],
    ]);
    final status = await engineWith(adapter).pushOnce();

    expect(status, SyncStatus.idle);
    expect(await outbox.pending(), isEmpty);
  });

  test('delete 撞 conflict 时跟随服务端 version 重发,并在同一次 pushOnce 内收敛', () async {
    await seedTask(version: 1, deletedAt: DateTime.now());
    await outbox.enqueue(
      entity: 'task',
      op: 'delete',
      entityId: taskId,
      baseVersion: 1,
      payload: const {},
    );

    final adapter = _FakeAdapter([
      // 第 1 轮:服务端已被推到 v2 且**未**删除 → conflict
      [
        {
          'entity': 'task',
          'id': taskId,
          'status': 'conflict',
          'version': 2,
          'server_value': {
            'id': taskId,
            'title': '交年报(终版)',
            'list_id': 'l-1',
            'version': 2,
            'updated_at': '2026-01-01T10:31:00Z',
            'deleted_at': null,
            'purged_at': null,
          },
        },
      ],
      // 第 2 轮:base 对上 → applied
      [
        {'entity': 'task', 'id': taskId, 'status': 'applied', 'version': 3},
      ],
    ]);
    final status = await engineWith(adapter).pushOnce();

    expect(status, SyncStatus.idle);
    expect(adapter.calls, 2, reason: '重发必须发生在同一次 pushOnce 内');
    expect(
      adapter.sentMutations[1].single['base_version'],
      2,
      reason: '重发应带服务端的 version',
    );
    expect(await outbox.pending(), isEmpty, reason: '删除最终生效,outbox 清空');
    final row = await readTask();
    expect(row.version, 3);
    expect(row.deletedAt, isNotNull, reason: '本地软删态不该被 server_value 覆盖回来');
  });

  test('delete 撞 conflict 但服务端已软删 → 目标达成,收下 version 并清 outbox', () async {
    await seedTask(version: 1, deletedAt: DateTime.now());
    await outbox.enqueue(
      entity: 'task',
      op: 'delete',
      entityId: taskId,
      baseVersion: 1,
      payload: const {},
    );

    final adapter = _FakeAdapter([
      [
        {
          'entity': 'task',
          'id': taskId,
          'status': 'conflict',
          'version': 5,
          'server_value': {
            'id': taskId,
            'title': '交年报',
            'list_id': 'l-1',
            'version': 5,
            'updated_at': '2026-01-01T10:31:00Z',
            'deleted_at': '2026-01-01T10:30:00Z',
            'purged_at': null,
          },
        },
      ],
    ]);
    final status = await engineWith(adapter).pushOnce();

    expect(status, SyncStatus.idle);
    expect(adapter.calls, 1, reason: '目标已达成,无需重发');
    expect(await outbox.pending(), isEmpty);
    expect((await readTask()).version, 5);
  });

  test('upsert 的 LWW 未受影响:服务端更晚仍然服务端赢', () async {
    await seedTask(version: 1);
    await outbox.enqueue(
      entity: 'task',
      op: 'upsert',
      entityId: taskId,
      baseVersion: 1,
      payload: const {'title': '本地改的'},
    );

    final adapter = _FakeAdapter([
      [
        {
          'entity': 'task',
          'id': taskId,
          'status': 'conflict',
          'version': 2,
          'server_value': {
            'id': taskId,
            'title': '服务端改的',
            'list_id': 'l-1',
            'version': 2,
            // 远在未来 → 服务端赢
            'updated_at': '2099-01-01T00:00:00Z',
            'deleted_at': null,
            'purged_at': null,
          },
        },
      ],
    ]);
    final status = await engineWith(adapter).pushOnce();

    expect(status, SyncStatus.idle);
    expect(adapter.calls, 1);
    expect(await outbox.pending(), isEmpty);
    final row = await readTask();
    expect(row.title, '服务端改的');
    expect(row.version, 2);
  });

  test('upsert 本地赢时同样在本次调用内重发', () async {
    // 真实路径下本地行与 outbox 在同一事务里写入,所以本地已是新标题。
    await seedTask(version: 1, title: '本地改的');
    await outbox.enqueue(
      entity: 'task',
      op: 'upsert',
      entityId: taskId,
      baseVersion: 1,
      payload: const {'title': '本地改的'},
    );

    final adapter = _FakeAdapter([
      [
        {
          'entity': 'task',
          'id': taskId,
          'status': 'conflict',
          'version': 2,
          'server_value': {
            'id': taskId,
            'title': '服务端改的',
            'list_id': 'l-1',
            'version': 2,
            // 远在过去 → 本地赢
            'updated_at': '2000-01-01T00:00:00Z',
            'deleted_at': null,
            'purged_at': null,
          },
        },
      ],
      [
        {'entity': 'task', 'id': taskId, 'status': 'applied', 'version': 3},
      ],
    ]);
    final status = await engineWith(adapter).pushOnce();

    expect(status, SyncStatus.idle);
    expect(adapter.calls, 2);
    expect(adapter.sentMutations[1].single['base_version'], 2);
    expect(await outbox.pending(), isEmpty);
    final row = await readTask();
    expect(row.title, '本地改的', reason: '本地赢,不该被 server_value 覆盖');
    expect(row.version, 3);
  });
}
