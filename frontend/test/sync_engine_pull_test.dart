import 'dart:convert';

import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:dio/dio.dart';
// drift 也导出 isNull / isNotNull(列表达式版),与 matcher 的同名匹配器冲突。
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// pull 响应的假服务端。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Map<String, dynamic> body;
  final List<String?> receivedSince = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    receivedSince.add(options.queryParameters['since'] as String?);
    return ResponseBody.fromString(
      jsonEncode(body),
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
  const cleanId = 't-clean';
  const dirtyId = 't-dirty';

  late AppDatabase db;
  late OutboxRepository outbox;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxRepository(db);
  });
  tearDown(() => db.close());

  SyncEngine engineWith(_FakeAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.httpClientAdapter = adapter;
    return SyncEngine(dio: dio, outbox: outbox, db: db, userId: userId);
  }

  Map<String, dynamic> task(String id, String title, String updatedAt) => {
    'id': id,
    'user_id': userId,
    'list_id': 'l-1',
    'title': title,
    'version': 2,
    'created_at': '2026-01-01T09:00:00Z',
    'updated_at': updatedAt,
    'deleted_at': null,
    'purged_at': null,
  };

  Map<String, dynamic> pullBody(List<Map<String, dynamic>> tasks) => {
    'cursor': '2026-01-01T12:00:00Z',
    'folders': <Map<String, dynamic>>[],
    'lists': <Map<String, dynamic>>[],
    'tasks': tasks,
    'tags': <Map<String, dynamic>>[],
    'task_tags': <Map<String, dynamic>>[],
  };

  test('没有跳过任何行时,游标推进到响应的 cursor', () async {
    final adapter = _FakeAdapter(
      pullBody([task(cleanId, '干净的', '2026-01-01T10:00:00Z')]),
    );
    final status = await engineWith(adapter).pullOnce();

    expect(status, SyncStatus.idle);
    expect(
      await outbox.getCursor(SyncCursorKey.lastPulledAt),
      // 未压回时是服务端 cursor 的原样透传,不经过 DateTime 往返。
      '2026-01-01T12:00:00Z',
    );
  });

  test('跳过脏实体时,游标压回被跳过行里最早的 updated_at', () async {
    // 本地对 dirtyId 还有没推上去的改动 → pull 时该行被跳过
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: dirtyId,
            userId: userId,
            listId: 'l-1',
            title: '本地改的',
          ),
        );
    await outbox.enqueue(
      entity: 'task',
      op: 'upsert',
      entityId: dirtyId,
      baseVersion: 1,
      payload: const {'title': '本地改的'},
    );

    final adapter = _FakeAdapter(
      pullBody([
        task(cleanId, '干净的', '2026-01-01T10:00:00Z'),
        task(dirtyId, '服务端的', '2026-01-01T11:00:00Z'),
      ]),
    );
    final status = await engineWith(adapter).pullOnce();

    expect(status, SyncStatus.idle);
    expect(
      await outbox.getCursor(SyncCursorKey.lastPulledAt),
      '2026-01-01T11:00:00.000Z',
      reason: '游标不能越过被跳过的行,否则那次更新永远不会再下发',
    );

    // 干净的那行照常落库
    final clean = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(cleanId))).getSingleOrNull();
    expect(clean?.title, '干净的');

    // 脏的那行保持本地值
    final dirty = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(dirtyId))).getSingle();
    expect(dirty.title, '本地改的');
  });

  test('多行被跳过时取最早的 updated_at', () async {
    for (final id in ['a', 'b']) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: id,
              userId: userId,
              listId: 'l-1',
              title: '本地 $id',
            ),
          );
      await outbox.enqueue(
        entity: 'task',
        op: 'upsert',
        entityId: id,
        baseVersion: 1,
        payload: const {'title': 'x'},
      );
    }

    final adapter = _FakeAdapter(
      pullBody([
        task('b', '服务端 b', '2026-01-01T11:30:00Z'),
        task('a', '服务端 a', '2026-01-01T10:30:00Z'),
      ]),
    );
    await engineWith(adapter).pullOnce();

    expect(
      await outbox.getCursor(SyncCursorKey.lastPulledAt),
      '2026-01-01T10:30:00.000Z',
    );
  });

  test('死信行不再让实体保持脏态,服务端的值能盖回来', () async {
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: dirtyId,
            userId: userId,
            listId: 'l-1',
            title: '推不上去的本地值',
          ),
        );
    await outbox.enqueue(
      entity: 'task',
      op: 'upsert',
      entityId: dirtyId,
      baseVersion: 1,
      payload: const {'title': 'x'},
    );
    await db.customUpdate(
      'UPDATE outbox SET retry_count = ?',
      variables: [Variable.withInt(OutboxRepository.retryLimit)],
      updates: {db.outbox},
    );

    final adapter = _FakeAdapter(
      pullBody([task(dirtyId, '服务端的', '2026-01-01T11:00:00Z')]),
    );
    await engineWith(adapter).pullOnce();

    final row = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(dirtyId))).getSingle();
    expect(row.title, '服务端的', reason: '死信不该冻结实体');
    expect(
      await outbox.getCursor(SyncCursorKey.lastPulledAt),
      // 未压回时是服务端 cursor 的原样透传,不经过 DateTime 往返。
      '2026-01-01T12:00:00Z',
      reason: '没有真正被跳过的行,游标正常推进',
    );
  });

  test('purge 墓碑物理删本地行并清掉该实体的 outbox', () async {
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: dirtyId,
            userId: userId,
            listId: 'l-1',
            title: '将被墓碑清除',
          ),
        );
    await outbox.enqueue(
      entity: 'task',
      op: 'upsert',
      entityId: dirtyId,
      baseVersion: 1,
      payload: const {'title': 'x'},
    );

    final tombstone = task(dirtyId, '将被墓碑清除', '2026-01-01T11:00:00Z')
      ..['purged_at'] = '2026-01-01T11:00:00Z';
    final adapter = _FakeAdapter(pullBody([tombstone]));
    await engineWith(adapter).pullOnce();

    expect(
      await (db.select(db.tasks)..where((t) => t.id.equals(dirtyId))).get(),
      isEmpty,
    );
    expect(await outbox.pending(), isEmpty);
    expect(
      await outbox.getCursor(SyncCursorKey.lastPulledAt),
      // 未压回时是服务端 cursor 的原样透传,不经过 DateTime 往返。
      '2026-01-01T12:00:00Z',
      reason: '墓碑不算跳过 —— 它已经落地了',
    );
  });
}
