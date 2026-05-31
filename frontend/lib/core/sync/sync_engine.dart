import 'dart:async';
import 'dart:convert';

import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/data/remote/api_client.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_engine.g.dart';

/// 同步状态。Sidebar / AppBar 指示器据此显示 icon + 文案。
enum SyncStatus { idle, syncing, error, offline }

/// 客户端同步引擎。
///
/// - [pullOnce]:增量 pull,服务端 delta 落本地 Drift。
/// - [pushOnce]:把 outbox 里 pending 的 mutation 批量 POST 给服务端,根据
///   返回处理 applied / conflict / rejected;conflict 走 LWW by updated_at。
///
/// SyncStatus 上报通过返回值传出,调用方(trigger / 指示器)负责写回
/// [SyncStatusController]。
class SyncEngine {
  SyncEngine({
    required Dio dio,
    required OutboxRepository outbox,
    required AppDatabase db,
    required String userId,
  }) : _dio = dio,
       _outbox = outbox,
       _db = db,
       _userId = userId;

  final Dio _dio;
  final OutboxRepository _outbox;
  final AppDatabase _db;
  final String _userId;

  /// 拉一次增量。失败不抛(网络断 / 服务端 5xx),由 [SyncStatus] 上报。
  Future<SyncStatus> pullOnce({CancelToken? cancelToken}) async {
    final since = await _outbox.getCursor(SyncCursorKey.lastPulledAt);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/sync/pull',
        queryParameters: since == null ? null : {'since': since},
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) return SyncStatus.error;
      await _applyPullResponse(data);
      await _outbox.setCursor(
        SyncCursorKey.lastPulledAt,
        data['cursor'] as String,
      );
      return SyncStatus.idle;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return SyncStatus.error;
      debugPrint('sync pull failed: ${e.type} ${e.message}');
      return e.type == DioExceptionType.connectionError
          ? SyncStatus.offline
          : SyncStatus.error;
    } catch (e, st) {
      debugPrint('sync pull threw: $e\n$st');
      return SyncStatus.error;
    }
  }

  /// 推一次:把 outbox 里所有 pending mutation 批量送给服务端。
  ///
  /// 处理 push 响应:
  /// - `applied`:本地 row.version 更新为服务端最新值,outbox 行删除。
  /// - `conflict`:对比 outbox.createdAt(本地写入时戳)与 server_value.updated_at
  ///   * 本地新 → 把 outbox.baseVersion 改为 server.version,下一轮 push 再发
  ///   * 服务端新 → 用 server_value 覆盖本地行,outbox 行删除(Phase 3 接 activities
  ///     表后再写一笔留痕)
  /// - `rejected`:服务端拒收(payload 校验失败 / 不允许的实体等),outbox 行删除。
  ///
  /// 整体网络异常:全部 mutation `markFailed`,retry_count 用尽后自然退出循环。
  Future<SyncStatus> pushOnce({CancelToken? cancelToken}) async {
    final pending = await _outbox.pending();
    if (pending.isEmpty) return SyncStatus.idle;

    final mutations = [for (final row in pending) _toMutation(row)];

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sync/push',
        data: {'mutations': mutations},
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) return SyncStatus.error;
      await _applyPushResponse(pending, data);
      return SyncStatus.idle;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return SyncStatus.error;
      debugPrint('sync push failed: ${e.type} ${e.message}');
      for (final row in pending) {
        await _outbox.markFailed(row.id, '${e.type}:${e.message ?? ""}');
      }
      return e.type == DioExceptionType.connectionError
          ? SyncStatus.offline
          : SyncStatus.error;
    } catch (e, st) {
      debugPrint('sync push threw: $e\n$st');
      for (final row in pending) {
        await _outbox.markFailed(row.id, e.toString());
      }
      return SyncStatus.error;
    }
  }

  Map<String, dynamic> _toMutation(OutboxData row) {
    return {
      'entity': row.entity,
      'op': row.op,
      'id': row.entityId,
      'base_version': row.baseVersion,
      'payload': jsonDecode(row.payload) as Map<String, dynamic>,
    };
  }

  Future<void> _applyPushResponse(
    List<OutboxData> pending,
    Map<String, dynamic> data,
  ) async {
    final results = _list(data['results']);
    // 服务端按请求顺序返回 results,因此可以按下标配对。
    for (var i = 0; i < pending.length && i < results.length; i++) {
      await _handleResult(pending[i], results[i]);
    }
  }

  Future<void> _handleResult(
    OutboxData row,
    Map<String, dynamic> result,
  ) async {
    final status = result['status'] as String?;
    switch (status) {
      case 'applied':
        await _db.transaction(() async {
          if (row.op == 'upsert') {
            final v = result['version'] as int?;
            if (v != null) {
              await _updateLocalVersion(row.entity, row.entityId, v);
            }
          }
          await _outbox.deleteById(row.id);
        });
      case 'conflict':
        await _resolveConflict(row, result);
      case 'rejected':
        debugPrint('sync: rejected ${row.entity}/${row.entityId}');
        await _outbox.markFailed(row.id, 'rejected by server');
      default:
        await _outbox.markFailed(row.id, 'unknown status: $status');
    }
  }

  Future<void> _resolveConflict(
    OutboxData row,
    Map<String, dynamic> result,
  ) async {
    final serverValue = result['server_value'];
    final serverVersion = result['version'] as int?;
    if (serverValue is! Map<String, dynamic> || serverVersion == null) {
      // 防御:服务端没给 server_value,只能放弃本地 mutation。
      debugPrint(
        'sync: conflict without server_value, dropping ${row.entity}/${row.entityId}',
      );
      await _outbox.deleteById(row.id);
      return;
    }
    final serverUpdatedAt = _dt(serverValue['updated_at']);
    final localTs = row.createdAt;
    final localWins =
        serverUpdatedAt == null || localTs.isAfter(serverUpdatedAt);

    if (localWins) {
      // 本地新:把 baseVersion 升到 server.version,下一轮 push 重发。
      await _outbox.updateBaseVersion(row.id, serverVersion);
    } else {
      // 服务端新:落 server_value,丢弃本地 mutation。
      await _db.transaction(() async {
        await _applyServerValue(row.entity, serverValue);
        await _outbox.deleteById(row.id);
      });
      debugPrint(
        'sync: server wins for ${row.entity}/${row.entityId} '
        '(local=$localTs, server=$serverUpdatedAt)',
      );
      // TODO(phase3): 写入 activities 表留痕
    }
  }

  Future<void> _updateLocalVersion(
    String entity,
    String entityId,
    int version,
  ) async {
    switch (entity) {
      case 'folder':
        await (_db.update(_db.folders)
              ..where((t) => t.id.equals(entityId) & t.userId.equals(_userId)))
            .write(FoldersCompanion(version: Value(version)));
      case 'list':
        await (_db.update(_db.taskLists)
              ..where((t) => t.id.equals(entityId) & t.userId.equals(_userId)))
            .write(TaskListsCompanion(version: Value(version)));
      case 'task':
        await (_db.update(_db.tasks)
              ..where((t) => t.id.equals(entityId) & t.userId.equals(_userId)))
            .write(TasksCompanion(version: Value(version)));
      case 'tag':
        await (_db.update(_db.tags)
              ..where((t) => t.id.equals(entityId) & t.userId.equals(_userId)))
            .write(TagsCompanion(version: Value(version)));
    }
  }

  Future<void> _applyServerValue(
    String entity,
    Map<String, dynamic> value,
  ) async {
    switch (entity) {
      case 'folder':
        await _db
            .into(_db.folders)
            .insertOnConflictUpdate(_foldersCompanion(value));
      case 'list':
        await _db
            .into(_db.taskLists)
            .insertOnConflictUpdate(_taskListsCompanion(value));
      case 'task':
        await _db
            .into(_db.tasks)
            .insertOnConflictUpdate(_tasksCompanion(value));
      case 'tag':
        await _db.into(_db.tags).insertOnConflictUpdate(_tagsCompanion(value));
    }
  }

  /// 把服务端 SyncPullResponse 落入本地 Drift。
  ///
  /// 简化策略:对每行做 insertOnConflictUpdate,服务端是 source of truth;
  /// 软删行(deleted_at 非空)同样落,本地查询会自然过滤掉。
  Future<void> _applyPullResponse(Map<String, dynamic> data) async {
    await _db.transaction(() async {
      for (final raw in _list(data['folders'])) {
        await _db
            .into(_db.folders)
            .insertOnConflictUpdate(_foldersCompanion(raw));
      }
      for (final raw in _list(data['lists'])) {
        await _db
            .into(_db.taskLists)
            .insertOnConflictUpdate(_taskListsCompanion(raw));
      }
      for (final raw in _list(data['tasks'])) {
        await _db.into(_db.tasks).insertOnConflictUpdate(_tasksCompanion(raw));
      }
      for (final raw in _list(data['tags'])) {
        await _db.into(_db.tags).insertOnConflictUpdate(_tagsCompanion(raw));
      }
      for (final raw in _list(data['task_tags'])) {
        final taskId = raw['task_id'] as String;
        final tagId = raw['tag_id'] as String;
        if (!await _ownsTaskAndTag(taskId, tagId)) continue;
        await _db
            .into(_db.taskTags)
            .insertOnConflictUpdate(
              TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
            );
      }
    });
  }

  Future<bool> _ownsTaskAndTag(String taskId, String tagId) async {
    final task =
        await (_db.select(_db.tasks)
              ..where((t) => t.id.equals(taskId) & t.userId.equals(_userId))
              ..limit(1))
            .getSingleOrNull();
    if (task == null) return false;
    final tag =
        await (_db.select(_db.tags)
              ..where((t) => t.id.equals(tagId) & t.userId.equals(_userId))
              ..limit(1))
            .getSingleOrNull();
    return tag != null;
  }

  static List<Map<String, dynamic>> _list(Object? v) {
    if (v is! List) return const [];
    return [
      for (final item in v)
        if (item is Map<String, dynamic>) item,
    ];
  }

  static DateTime? _dt(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  FoldersCompanion _foldersCompanion(Map<String, dynamic> r) {
    return FoldersCompanion(
      id: Value(r['id'] as String),
      userId: Value(_userId),
      name: Value(r['name'] as String),
      sortOrder: Value(r['sort_order'] as int? ?? 0),
      createdAt: Value(_dt(r['created_at']) ?? DateTime.now()),
      updatedAt: Value(_dt(r['updated_at']) ?? DateTime.now()),
      deletedAt: Value(_dt(r['deleted_at'])),
      version: Value(r['version'] as int? ?? 1),
    );
  }

  TaskListsCompanion _taskListsCompanion(Map<String, dynamic> r) {
    return TaskListsCompanion(
      id: Value(r['id'] as String),
      userId: Value(_userId),
      folderId: Value(r['folder_id'] as String?),
      name: Value(r['name'] as String),
      color: Value(r['color'] as String?),
      icon: Value(r['icon'] as String?),
      sortOrder: Value(r['sort_order'] as int? ?? 0),
      isSystem: Value(r['is_system'] as bool? ?? false),
      systemKind: Value(r['system_kind'] as String?),
      createdAt: Value(_dt(r['created_at']) ?? DateTime.now()),
      updatedAt: Value(_dt(r['updated_at']) ?? DateTime.now()),
      deletedAt: Value(_dt(r['deleted_at'])),
      version: Value(r['version'] as int? ?? 1),
    );
  }

  TasksCompanion _tasksCompanion(Map<String, dynamic> r) {
    return TasksCompanion(
      id: Value(r['id'] as String),
      userId: Value(_userId),
      listId: Value(r['list_id'] as String),
      parentId: Value(r['parent_id'] as String?),
      title: Value(r['title'] as String),
      notes: Value(r['notes'] as String?),
      priority: Value(r['priority'] as int? ?? 0),
      dueAt: Value(_dt(r['due_at'])),
      remindAt: Value(_dt(r['remind_at'])),
      repeatRule: Value(r['repeat_rule'] as String?),
      color: Value(r['color'] as String?),
      sortOrder: Value(r['sort_order'] as int? ?? 0),
      completedAt: Value(_dt(r['completed_at'])),
      archivedAt: Value(_dt(r['archived_at'])),
      starred: Value(r['starred'] as bool? ?? false),
      createdAt: Value(_dt(r['created_at']) ?? DateTime.now()),
      updatedAt: Value(_dt(r['updated_at']) ?? DateTime.now()),
      deletedAt: Value(_dt(r['deleted_at'])),
      version: Value(r['version'] as int? ?? 1),
    );
  }

  TagsCompanion _tagsCompanion(Map<String, dynamic> r) {
    return TagsCompanion(
      id: Value(r['id'] as String),
      userId: Value(_userId),
      name: Value(r['name'] as String),
      color: Value(r['color'] as String?),
      createdAt: Value(_dt(r['created_at']) ?? DateTime.now()),
      updatedAt: Value(_dt(r['updated_at']) ?? DateTime.now()),
      deletedAt: Value(_dt(r['deleted_at'])),
      version: Value(r['version'] as int? ?? 1),
    );
  }
}

@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) {
  return SyncEngine(
    dio: ref.watch(apiClientProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    db: ref.watch(appDatabaseProvider),
    userId: ref.watch(currentUserIdProvider),
  );
}

/// 全局 SyncStatus(后续状态指示器 watch 此 provider)。
@Riverpod(keepAlive: true)
class SyncStatusController extends _$SyncStatusController {
  @override
  SyncStatus build() => SyncStatus.idle;

  // ignore: use_setters_to_change_properties — 与 Riverpod 风格一致用 method
  void set(SyncStatus next) => state = next;
}

/// 上次同步成功的本地时间。由 SyncCoordinator 在每轮 idle 完成时写入
/// `sync_cursors.last_sync_at`,此 provider watch 该行变更并返回 DateTime?。
/// 设置页据此显示"X 分钟前"。
///
/// 用手写 StreamProvider 而不是 @Riverpod codegen,避免每次改这块都强制
/// 跑 build_runner。
final lastSyncAtProvider = StreamProvider<DateTime?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.syncCursors)
        ..where((t) => t.key.equals(SyncCursorKey.lastSyncAt)))
      .watchSingleOrNull()
      .map((row) {
        if (row == null) return null;
        return DateTime.tryParse(row.value);
      });
});
