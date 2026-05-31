import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tag_repository.g.dart';

class TagRepository {
  TagRepository(this._db, this._outbox, this._userId);

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final String _userId;

  /// 监听所有未软删的标签。
  Stream<List<Tag>> watchAll() {
    return (_db.select(_db.tags)
          ..where((t) => t.userId.equals(_userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// 监听某任务关联的标签(join task_tags ↔ tags)。
  Stream<List<Tag>> watchTagsForTask(String taskId) {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.taskTags,
        _db.taskTags.tagId.equalsExp(_db.tags.id) &
            _db.taskTags.taskId.equals(taskId),
      ),
    ])..where(_db.tags.userId.equals(_userId) & _db.tags.deletedAt.isNull());
    return query.map((row) => row.readTable(_db.tags)).watch();
  }

  /// 创建标签(若同名活跃标签已存在则复用)。
  Future<String> create(String name, {String? color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name must not be blank');
    }
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.tags)
                ..where(
                  (t) =>
                      t.userId.equals(_userId) &
                      t.name.equals(trimmed) &
                      t.deletedAt.isNull(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) return existing.id;

      final id = newId();
      await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(
              id: id,
              userId: _userId,
              name: trimmed,
              color: Value(color),
            ),
          );
      await _outbox.enqueue(
        entity: 'tag',
        op: 'upsert',
        entityId: id,
        baseVersion: 0,
        payload: {'name': trimmed, 'color': color},
      );
      return id;
    });
  }

  /// 重命名标签(乐观锁 baseVersion + upsert 广播)。
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name must not be blank');
    }
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.tags,
      )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).getSingle();
      await (_db.update(_db.tags)
            ..where((t) => t.id.equals(id) & t.userId.equals(_userId)))
          .write(TagsCompanion(name: Value(trimmed)));
      await _outbox.enqueue(
        entity: 'tag',
        op: 'upsert',
        entityId: id,
        baseVersion: current.version,
        payload: {'name': trimmed, 'color': current.color},
      );
    });
  }

  /// 软删标签(同步引擎后再单独广播)。
  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      final current = await (_db.select(
        _db.tags,
      )..where((t) => t.id.equals(id) & t.userId.equals(_userId))).getSingle();
      await (_db.update(_db.tags)
            ..where((t) => t.id.equals(id) & t.userId.equals(_userId)))
          .write(TagsCompanion(deletedAt: Value(DateTime.now())));
      await _outbox.enqueue(
        entity: 'tag',
        op: 'delete',
        entityId: id,
        baseVersion: current.version,
        payload: const {},
      );
    });
  }

  // TODO(sync): task_tag mutations 服务端目前直接 rejected
  //   (sync_service.py:_apply_one),addToTask/removeFromTask 暂只走本地。
  //   待后端补完 task_tag 同步后,这里再 enqueue。
  Future<void> addToTask(String taskId, String tagId) async {
    if (!await _ownsTaskAndTag(taskId, tagId)) return;
    await _db
        .into(_db.taskTags)
        .insertOnConflictUpdate(
          TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
        );
  }

  Future<void> removeFromTask(String taskId, String tagId) async {
    if (!await _ownsTaskAndTag(taskId, tagId)) return;
    await (_db.delete(
      _db.taskTags,
    )..where((tt) => tt.taskId.equals(taskId) & tt.tagId.equals(tagId))).go();
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
}

@Riverpod(keepAlive: true)
TagRepository tagRepository(Ref ref) {
  return TagRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(currentUserIdProvider),
  );
}

@riverpod
Stream<List<Tag>> allTags(Ref ref) {
  return ref.watch(tagRepositoryProvider).watchAll();
}

/// 监听某任务当前关联的标签列表。
@riverpod
Stream<List<Tag>> tagsForTask(Ref ref, String taskId) {
  return ref.watch(tagRepositoryProvider).watchTagsForTask(taskId);
}
