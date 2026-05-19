import 'dart:async';

import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/data/remote/api_client.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_engine.g.dart';

/// 同步状态。Sidebar / AppBar 指示器据此显示 icon + 文案。
enum SyncStatus { idle, syncing, error, offline }

/// 客户端同步引擎(Phase 2 step 1.c)。
///
/// 现阶段提供 [pullOnce]:启动期一次性增量 pull,把服务端 delta 落进本地
/// Drift。push 与 watch-outbox 循环留给下一 commit。
class SyncEngine {
  SyncEngine({
    required Dio dio,
    required OutboxRepository outbox,
    required AppDatabase db,
  }) : _dio = dio,
       _outbox = outbox,
       _db = db;

  final Dio _dio;
  final OutboxRepository _outbox;
  final AppDatabase _db;

  /// 拉一次增量。失败不抛(网络断 / 服务端 5xx),由 [SyncStatus] 上报。
  Future<SyncStatus> pullOnce() async {
    final since = await _outbox.getCursor(SyncCursorKey.lastPulledAt);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/sync/pull',
        queryParameters: since == null ? null : {'since': since},
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
      debugPrint('sync pull failed: ${e.type} ${e.message}');
      return e.type == DioExceptionType.connectionError
          ? SyncStatus.offline
          : SyncStatus.error;
    } catch (e, st) {
      debugPrint('sync pull threw: $e\n$st');
      return SyncStatus.error;
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
        await _db
            .into(_db.taskTags)
            .insertOnConflictUpdate(
              TaskTagsCompanion.insert(
                taskId: raw['task_id'] as String,
                tagId: raw['tag_id'] as String,
              ),
            );
      }
    });
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

  static FoldersCompanion _foldersCompanion(Map<String, dynamic> r) {
    return FoldersCompanion(
      id: Value(r['id'] as String),
      userId: const Value('00000000-0000-0000-0000-000000000001'),
      name: Value(r['name'] as String),
      sortOrder: Value(r['sort_order'] as int? ?? 0),
      createdAt: Value(_dt(r['created_at']) ?? DateTime.now()),
      updatedAt: Value(_dt(r['updated_at']) ?? DateTime.now()),
      deletedAt: Value(_dt(r['deleted_at'])),
      version: Value(r['version'] as int? ?? 1),
    );
  }

  static TaskListsCompanion _taskListsCompanion(Map<String, dynamic> r) {
    return TaskListsCompanion(
      id: Value(r['id'] as String),
      userId: const Value('00000000-0000-0000-0000-000000000001'),
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

  static TasksCompanion _tasksCompanion(Map<String, dynamic> r) {
    return TasksCompanion(
      id: Value(r['id'] as String),
      userId: const Value('00000000-0000-0000-0000-000000000001'),
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

  static TagsCompanion _tagsCompanion(Map<String, dynamic> r) {
    return TagsCompanion(
      id: Value(r['id'] as String),
      userId: const Value('00000000-0000-0000-0000-000000000001'),
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
