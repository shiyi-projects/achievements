import 'dart:convert';

import 'package:achievements/core/sync/outbox_grouping.dart';
import 'package:achievements/data/local/database.dart';
import 'package:flutter_test/flutter_test.dart';

OutboxData _row({
  required int id,
  String entity = 'task',
  String op = 'upsert',
  String entityId = 'T1',
  Map<String, dynamic> payload = const {},
  int baseVersion = 1,
}) {
  return OutboxData(
    id: id,
    entity: entity,
    op: op,
    entityId: entityId,
    payload: jsonEncode(payload),
    baseVersion: baseVersion,
    retryCount: 0,
    lastError: null,
    createdAt: DateTime(2026, 1, 1, 12, 0, id),
  );
}

void main() {
  test('同实体连续 upsert 合并:payload 后者覆盖、base 取首、时戳取末', () {
    final groups = groupPending([
      _row(id: 1, payload: {'title': 'A', 'starred': false}, baseVersion: 3),
      _row(id: 2, payload: {'starred': true}, baseVersion: 3),
      _row(id: 3, payload: {'completed_at': null}, baseVersion: 3),
    ]);
    expect(groups, hasLength(1));
    final g = groups.single;
    expect(g.rows, hasLength(3));
    expect(g.baseVersion, 3);
    expect(g.latestCreatedAt, DateTime(2026, 1, 1, 12, 0, 3));
    expect(g.mergedPayload(), {
      'title': 'A',
      'starred': true,
      'completed_at': null,
    });
  });

  test('delete / purge 自成一组并封闭该实体的开放组', () {
    final groups = groupPending([
      _row(id: 1, payload: {'title': 'A'}),
      _row(id: 2, op: 'delete'),
      _row(id: 3, payload: {'deleted_at': null}),
    ]);
    expect(groups, hasLength(3));
    expect([for (final g in groups) g.op], ['upsert', 'delete', 'upsert']);
  });

  test('跨实体交错不阻断合并', () {
    final groups = groupPending([
      _row(id: 1, entityId: 'T1', payload: {'title': 'A'}),
      _row(id: 2, entity: 'list', entityId: 'L1', payload: {'name': 'Inbox'}),
      _row(id: 3, entityId: 'T1', payload: {'starred': true}),
    ]);
    expect(groups, hasLength(2));
    expect(groups.first.entityId, 'T1');
    expect(groups.first.rows, hasLength(2));
    expect(groups.first.mergedPayload(), {'title': 'A', 'starred': true});
    expect(groups.last.entityId, 'L1');
  });

  test('不同实体 id 各自成组', () {
    final groups = groupPending([
      _row(id: 1, entityId: 'T1'),
      _row(id: 2, entityId: 'T2'),
    ]);
    expect(groups, hasLength(2));
  });

  test('task_tag 永不合并(entityId 是 task_id 占位,主键在 payload)', () {
    final groups = groupPending([
      _row(
        id: 1,
        entity: 'task_tag',
        entityId: 'T1',
        payload: {'task_id': 'T1', 'tag_id': 'G1'},
      ),
      _row(
        id: 2,
        entity: 'task_tag',
        entityId: 'T1',
        payload: {'task_id': 'T1', 'tag_id': 'G2'},
      ),
    ]);
    expect(groups, hasLength(2));
  });

  test('单行组的 toMutation 与原行等价', () {
    final groups = groupPending([_row(id: 1, op: 'purge', baseVersion: 4)]);
    expect(groups.single.toMutation(), {
      'entity': 'task',
      'op': 'purge',
      'id': 'T1',
      'base_version': 4,
      'payload': <String, dynamic>{},
    });
  });
}
