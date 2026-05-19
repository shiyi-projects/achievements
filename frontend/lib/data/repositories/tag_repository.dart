import 'package:achievements/core/constants.dart';
import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tag_repository.g.dart';

class TagRepository {
  TagRepository(this._db);

  final AppDatabase _db;

  /// 监听所有未软删的标签。
  Stream<List<Tag>> watchAll() {
    return (_db.select(_db.tags)
          ..where((t) => t.deletedAt.isNull())
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
    ])..where(_db.tags.deletedAt.isNull());
    return query.map((row) => row.readTable(_db.tags)).watch();
  }

  /// 创建标签(若同名活跃标签已存在则复用)。
  Future<String> create(String name, {String? color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name must not be blank');
    }
    final existing =
        await (_db.select(_db.tags)
              ..where((t) => t.name.equals(trimmed) & t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = newId();
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(
            id: id,
            userId: kLocalUserId,
            name: trimmed,
            color: Value(color),
          ),
        );
    return id;
  }

  /// 软删标签(同步引擎后再单独广播)。
  Future<void> softDelete(String id) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> addToTask(String taskId, String tagId) async {
    await _db
        .into(_db.taskTags)
        .insertOnConflictUpdate(
          TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
        );
  }

  Future<void> removeFromTask(String taskId, String tagId) async {
    await (_db.delete(
      _db.taskTags,
    )..where((tt) => tt.taskId.equals(taskId) & tt.tagId.equals(tagId))).go();
  }
}

@Riverpod(keepAlive: true)
TagRepository tagRepository(Ref ref) {
  return TagRepository(ref.watch(appDatabaseProvider));
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
