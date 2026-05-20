import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'step_repository.g.dart';

class StepRepository {
  StepRepository(this._db);

  final AppDatabase _db;

  Stream<List<TaskStep>> watchStepsForTask(String taskId) {
    return (_db.select(_db.taskSteps)
          ..where((s) => s.taskId.equals(taskId))
          ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
        .watch();
  }

  Future<String> createStep(String taskId, String title) async {
    final id = newId();
    final lastSort = await (_db.selectOnly(_db.taskSteps)
          ..addColumns([_db.taskSteps.sortOrder.max()])
          ..where(_db.taskSteps.taskId.equals(taskId)))
        .getSingleOrNull();
    final nextSort =
        (lastSort?.read(_db.taskSteps.sortOrder.max()) ?? -1) + 1;
    await _db.into(_db.taskSteps).insert(
      TaskStepsCompanion.insert(
        id: id,
        taskId: taskId,
        title: title,
        sortOrder: Value(nextSort),
      ),
    );
    return id;
  }

  Future<void> toggleStep(String id, {required bool completed}) {
    return (_db.update(_db.taskSteps)..where((s) => s.id.equals(id))).write(
      TaskStepsCompanion(
        completedAt: Value(completed ? DateTime.now() : null),
      ),
    );
  }

  Future<void> renameStep(String id, String title) {
    return (_db.update(_db.taskSteps)..where((s) => s.id.equals(id)))
        .write(TaskStepsCompanion(title: Value(title)));
  }

  Future<void> deleteStep(String id) {
    return (_db.delete(_db.taskSteps)..where((s) => s.id.equals(id))).go();
  }

  /// 批量更新排序(拖拽结束后调用)。
  Future<void> reorderSteps(List<({String id, int sortOrder})> updates) {
    return _db.transaction(() async {
      for (final u in updates) {
        await (_db.update(_db.taskSteps)..where((s) => s.id.equals(u.id)))
            .write(TaskStepsCompanion(sortOrder: Value(u.sortOrder)));
      }
    });
  }
}

@Riverpod(keepAlive: true)
StepRepository stepRepository(Ref ref) {
  return StepRepository(ref.watch(appDatabaseProvider));
}

@riverpod
Stream<List<TaskStep>> stepsForTask(Ref ref, String taskId) {
  return ref.watch(stepRepositoryProvider).watchStepsForTask(taskId);
}

/// 仅返回计数,供 TaskTile 轻量订阅,减少不必要的 rebuild。
@riverpod
({int done, int total}) stepCount(Ref ref, String taskId) {
  final steps = ref
      .watch(stepsForTaskProvider(taskId))
      .maybeWhen(data: (s) => s, orElse: () => const <TaskStep>[]);
  return (
    done: steps.where((s) => s.completedAt != null).length,
    total: steps.length,
  );
}
