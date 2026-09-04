import 'dart:async';

import 'package:achievements/core/sync/outbox_grouping.dart';
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
  /// - `conflict`:
  ///   * 删除类终态(delete / purge)不参与 LWW,跟随服务端 version 重试直到生效
  ///   * 其余对比 outbox.createdAt(本地写入时戳)与 server_value.updated_at
  ///     - 本地新 → 把 outbox.baseVersion 改为 server.version,重发
  ///     - 服务端新 → 用 server_value 覆盖本地行,outbox 行删除(Phase 3 接
  ///       activities 表后再写一笔留痕)
  /// - `rejected`:服务端拒收(payload 校验失败 / 不允许的实体等),outbox 行删除。
  ///
  /// 整体网络异常:全部 mutation `markFailed`,retry_count 用尽后自然退出循环。
  ///
  /// conflict 走「跟随服务端 version 重试」时,重发必须在**本次调用内**完成:
  /// 那条路径只改 outbox 行的 baseVersion、不改行数,watchPendingCount 不保证
  /// 再次触发 push,漏掉就要等 30s 重试或下一次本地写入。
  Future<SyncStatus> pushOnce({CancelToken? cancelToken}) async {
    var status = SyncStatus.idle;
    for (var round = 0; round < _maxPushRounds; round++) {
      final outcome = await _pushRound(cancelToken: cancelToken);
      status = outcome.status;
      // 只有本轮干净结束、且确实有行等着重发,才值得再来一轮。
      if (status != SyncStatus.idle || !outcome.needsAnotherRound) break;
    }
    return status;
  }

  /// 单轮 push 的上限。防止两端持续互相改同一实体时在一次调用里空转。
  static const int _maxPushRounds = 3;

  Future<({SyncStatus status, bool needsAnotherRound})> _pushRound({
    CancelToken? cancelToken,
  }) async {
    final pending = await _outbox.pending();
    if (pending.isEmpty) {
      return (status: SyncStatus.idle, needsAnotherRound: false);
    }

    // 同一实体的连续 upsert 合并为一条 mutation 发送,消除同批链式 base
    // 陈旧导致的伪 conflict(详见 outbox_grouping.dart)。
    final groups = groupPending(pending);
    final mutations = [for (final g in groups) g.toMutation()];

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sync/push',
        data: {'mutations': mutations},
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        return (status: SyncStatus.error, needsAnotherRound: false);
      }
      final retry = await _applyPushResponse(groups, data);
      return (status: SyncStatus.idle, needsAnotherRound: retry);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return (status: SyncStatus.error, needsAnotherRound: false);
      }
      debugPrint('sync push failed: ${e.type} ${e.message}');
      // 网络类错误是暂时的:只记 lastError,不消耗 retry 预算(重试由
      // SyncCoordinator 的 30s 定时器驱动)。
      for (final row in pending) {
        await _outbox.noteError(row.id, '${e.type}:${e.message ?? ""}');
      }
      return (
        status: e.type == DioExceptionType.connectionError
            ? SyncStatus.offline
            : SyncStatus.error,
        needsAnotherRound: false,
      );
    } catch (e, st) {
      debugPrint('sync push threw: $e\n$st');
      for (final row in pending) {
        await _outbox.noteError(row.id, e.toString());
      }
      return (status: SyncStatus.error, needsAnotherRound: false);
    }
  }

  /// 返回是否有 group 被安排了重发(conflict 抬高 baseVersion 后等下一轮)。
  Future<bool> _applyPushResponse(
    List<MutationGroup> groups,
    Map<String, dynamic> data,
  ) async {
    final results = _list(data['results']);
    var needsAnotherRound = false;
    // 服务端按请求顺序返回 results,因此可以按下标配对。
    for (var i = 0; i < groups.length && i < results.length; i++) {
      if (await _handleResult(groups[i], results[i])) needsAnotherRound = true;
    }
    return needsAnotherRound;
  }

  /// 返回 true 表示该 group 已被安排重发,调用方应再跑一轮 push。
  Future<bool> _handleResult(
    MutationGroup group,
    Map<String, dynamic> result,
  ) async {
    final status = result['status'] as String?;
    switch (status) {
      case 'applied':
        await _db.transaction(() async {
          // 服务端对 delete / purge 同样 bump version 并返回新值;不回写会让
          // 本地 version 永久落后一格,此后这一行的每次操作都带着陈旧的
          // base_version,必然冲突并被 LWW 赌时间戳。purge 时本地行已被物理
          // 删除,这条 UPDATE 影响 0 行,无害。
          final v = result['version'] as int?;
          if (v != null) {
            await _updateLocalVersion(group.entity, group.entityId, v);
          }
          for (final row in group.rows) {
            await _outbox.deleteById(row.id);
          }
        });
        return false;
      case 'conflict':
        return _resolveConflict(group, result);
      case 'rejected':
        debugPrint('sync: rejected ${group.entity}/${group.entityId}');
        for (final row in group.rows) {
          await _outbox.markFailed(row.id, 'rejected by server');
        }
        return false;
      default:
        for (final row in group.rows) {
          await _outbox.markFailed(row.id, 'unknown status: $status');
        }
        return false;
    }
  }

  Future<bool> _resolveConflict(
    MutationGroup group,
    Map<String, dynamic> result,
  ) async {
    final serverValue = result['server_value'];
    final serverVersion = result['version'] as int?;
    if (serverValue is! Map<String, dynamic> || serverVersion == null) {
      // 防御:服务端没给 server_value,只能放弃本地 mutation。
      debugPrint(
        'sync: conflict without server_value, dropping '
        '${group.entity}/${group.entityId}',
      );
      for (final row in group.rows) {
        await _outbox.deleteById(row.id);
      }
      return false;
    }
    // 删除是终态,不参与 LWW。删除是用户的显式意图,不该被「服务端 updated_at
    // 更晚」吞掉 —— 尤其当那个更晚的时刻正是同批前一条 upsert 刚刚造成的:
    // 拿本地入队时刻去比,服务端恒胜,删除被静默丢弃。
    // 若服务端已达成该终态则完成,否则跟随服务端 version 重试,直到 base_version
    // 对上后 apply。
    if (group.op == 'purge' || group.op == 'delete') {
      final reached = group.op == 'purge'
          ? serverValue['purged_at'] != null
          : serverValue['deleted_at'] != null ||
                serverValue['purged_at'] != null;
      if (reached) {
        await _db.transaction(() async {
          // 目标已达成(可能是另一端先删的),把服务端 version 收下,免得本地
          // 继续拿陈旧 version 去撞下一次冲突。
          await _updateLocalVersion(
            group.entity,
            group.entityId,
            serverVersion,
          );
          for (final row in group.rows) {
            await _outbox.deleteById(row.id);
          }
        });
        return false;
      }
      await _outbox.updateBaseVersion(group.rows.first.id, serverVersion);
      return true;
    }
    final serverUpdatedAt = _dt(serverValue['updated_at']);
    // 组内最后一次本地写入的时刻代表整组意图。
    final localTs = group.latestCreatedAt;
    final localWins =
        serverUpdatedAt == null || localTs.isAfter(serverUpdatedAt);

    if (localWins) {
      // 本地新:把组首行 baseVersion 升到 server.version(下一轮重新分组时
      // 组的 baseVersion 取首行),下一轮 push 重发。
      await _outbox.updateBaseVersion(group.rows.first.id, serverVersion);
      return true;
    } else {
      // 服务端新:落 server_value,丢弃整组本地 mutation。
      await _db.transaction(() async {
        await _applyServerValue(group.entity, serverValue);
        for (final row in group.rows) {
          await _outbox.deleteById(row.id);
        }
      });
      debugPrint(
        'sync: server wins for ${group.entity}/${group.entityId} '
        '(local=$localTs, server=$serverUpdatedAt)',
      );
      // TODO(phase3): 写入 activities 表留痕
      return false;
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
    // 永久删除墓碑:物理删本地行,不再落库(否则会复活到回收站)。
    if (value['purged_at'] != null) {
      await _deleteLocalById(entity, value['id'] as String);
      return;
    }
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

  /// 物理删除本地实体行(永久删除墓碑落地)。
  Future<void> _deleteLocalById(String entity, String id) async {
    switch (entity) {
      case 'folder':
        await (_db.delete(
          _db.folders,
        )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).go();
      case 'list':
        await (_db.delete(
          _db.taskLists,
        )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).go();
      case 'task':
        // 标签关联行随任务墓碑一并物理清理:服务端 GC 靠 FK CASCADE 删关联,
        // 不会为 task_tag 单独下发墓碑。
        await (_db.delete(
          _db.taskTags,
        )..where((tt) => tt.taskId.equals(id))).go();
        await (_db.delete(
          _db.tasks,
        )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).go();
      case 'tag':
        await (_db.delete(
          _db.taskTags,
        )..where((tt) => tt.tagId.equals(id))).go();
        await (_db.delete(
          _db.tags,
        )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).go();
    }
  }

  /// 把服务端 SyncPullResponse 落入本地 Drift。
  ///
  /// 策略:
  /// - **永久删除墓碑**(purged_at 非空)物理删本地行——绝不能 insert,否则已
  ///   永久删除的任务会随 deleted_at 复活到回收站;同时清掉该实体残留的 outbox
  ///   行(实体已死,继续推送无意义)。
  /// - **脏实体**(outbox 有 pending mutation)跳过,不让服务端旧值覆盖本地
  ///   未推送的修改;两端差异交由 push 的 conflict/LWW 流程收敛。
  /// - 其余行 insertOnConflictUpdate。软删行(deleted_at 非空、purged_at 为空)
  ///   正常落,UI 查询据 deletedAt 过滤,显示在回收站。
  Future<void> _applyPullResponse(Map<String, dynamic> data) async {
    await _db.transaction(() async {
      final dirty = await _outbox.pendingEntityKeys();

      Future<void> applyRow(
        String entity,
        Map<String, dynamic> raw,
        Future<void> Function() upsert,
      ) async {
        final id = raw['id'] as String;
        if (raw['purged_at'] != null) {
          await _deleteLocalById(entity, id);
          await _outbox.deleteByEntity(entity, id);
          return;
        }
        if (dirty.contains('$entity:$id')) return;
        await upsert();
      }

      for (final raw in _list(data['folders'])) {
        await applyRow(
          'folder',
          raw,
          () => _db
              .into(_db.folders)
              .insertOnConflictUpdate(_foldersCompanion(raw)),
        );
      }
      for (final raw in _list(data['lists'])) {
        await applyRow(
          'list',
          raw,
          () => _db
              .into(_db.taskLists)
              .insertOnConflictUpdate(_taskListsCompanion(raw)),
        );
      }
      for (final raw in _list(data['tasks'])) {
        await applyRow(
          'task',
          raw,
          () =>
              _db.into(_db.tasks).insertOnConflictUpdate(_tasksCompanion(raw)),
        );
      }
      for (final raw in _list(data['tags'])) {
        await applyRow(
          'tag',
          raw,
          () => _db.into(_db.tags).insertOnConflictUpdate(_tagsCompanion(raw)),
        );
      }
      for (final raw in _list(data['task_tags'])) {
        final taskId = raw['task_id'] as String;
        final tagId = raw['tag_id'] as String;
        // 删除墓碑:物理删本地关联行(取消打标签的跨端传播)。
        if (raw['deleted_at'] != null) {
          await (_db.delete(_db.taskTags)..where(
                (tt) => tt.taskId.equals(taskId) & tt.tagId.equals(tagId),
              ))
              .go();
          continue;
        }
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
      recurrenceParentId: Value(r['recurrence_parent_id'] as String?),
      occurrenceDate: Value(_dt(r['occurrence_date'])),
      color: Value(r['color'] as String?),
      sortOrder: Value(r['sort_order'] as int? ?? 0),
      completedAt: Value(_dt(r['completed_at'])),
      archivedAt: Value(_dt(r['archived_at'])),
      starred: Value(r['starred'] as bool? ?? false),
      // 区分「key 缺失」与「显式 null」:旧版后端(迁移未部署)不返回此字段,
      // 缺失时保留本地值,避免升级窗口内被清空。
      estimatedMinutes: r.containsKey('estimated_minutes')
          ? Value(r['estimated_minutes'] as int?)
          : const Value.absent(),
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
