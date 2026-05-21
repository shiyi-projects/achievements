import 'dart:convert';

import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'outbox_repository.g.dart';

/// 已知的 SyncCursors key。
class SyncCursorKey {
  static const String lastPulledAt = 'last_pulled_at';

  /// 本设备已完成"首次同步门"。值为 `'true'` 表示首次 pull 曾成功(或用户
  /// 主动选择了"离线使用"绕过门控);为空/其他值则下次启动会重新走门。
  static const String firstSyncDone = 'first_sync_done';

  /// 上次同步成功的**本地** ISO 时间戳(`DateTime.now().toIso8601String()`)。
  /// SyncCoordinator 在 pull+push 双双 idle 时写入,设置页据此显示"X 分钟前"。
  /// 注意是本地时钟,跨设备不可比较。
  static const String lastSyncAt = 'last_sync_at';
}

class OutboxRepository {
  OutboxRepository(this._db);

  final AppDatabase _db;

  /// 在已开启的事务里入队一条 mutation。调用方必须自己开 transaction;
  /// 这样业务表更新与 outbox 行原子可见。
  Future<int> enqueueIn(Insertable<OutboxData> Function() builder) {
    return _db.into(_db.outbox).insert(builder());
  }

  /// 便利方法:构造 OutboxCompanion 并入队。
  Future<int> enqueue({
    required String entity,
    required String op,
    required String entityId,
    required int baseVersion,
    required Map<String, dynamic> payload,
  }) {
    return _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion.insert(
            entity: entity,
            op: op,
            entityId: entityId,
            payload: jsonEncode(payload),
            baseVersion: Value(baseVersion),
          ),
        );
  }

  /// 按 createdAt 升序拿出当前未处理的所有 outbox 行(retry_count < limit)。
  Future<List<OutboxData>> pending({int retryLimit = 5}) {
    return (_db.select(_db.outbox)
          ..where((t) => t.retryCount.isSmallerThanValue(retryLimit))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// applied / conflict 已由服务端处理完毕,本地删除。
  Future<void> deleteById(int id) {
    return (_db.delete(_db.outbox)..where((t) => t.id.equals(id))).go();
  }

  /// rejected 或网络错:retryCount + 1,记录最近一次 error。
  Future<void> markFailed(int id, String error) {
    return _db.customUpdate(
      'UPDATE outbox SET retry_count = retry_count + 1, last_error = ? '
      'WHERE id = ?',
      variables: [Variable.withString(error), Variable.withInt(id)],
      updates: {_db.outbox},
    );
  }

  /// LWW 冲突:本地新但 base_version 已陈旧。把 outbox 行的 baseVersion
  /// 改为服务端最新 version,等下一轮 push 再发。createdAt 保留,排序不变。
  Future<void> updateBaseVersion(int id, int newBaseVersion) {
    return (_db.update(_db.outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(baseVersion: Value(newBaseVersion)),
    );
  }

  /// 监听 outbox 行数:SyncEngine 据此触发批量推送。
  Stream<int> watchPendingCount() {
    final countExpr = _db.outbox.id.count();
    return (_db.selectOnly(_db.outbox)..addColumns([countExpr]))
        .map((row) => row.read(countExpr) ?? 0)
        .watchSingle();
  }

  // ---- cursor 工具 -----------------------------------------------------

  Future<String?> getCursor(String key) async {
    final row = await (_db.select(
      _db.syncCursors,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setCursor(String key, String value) {
    return _db
        .into(_db.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion.insert(key: key, value: value),
        );
  }
}

@Riverpod(keepAlive: true)
OutboxRepository outboxRepository(Ref ref) {
  return OutboxRepository(ref.watch(appDatabaseProvider));
}
