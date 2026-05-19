import 'package:achievements/core/constants.dart';
import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'folder_repository.g.dart';

class FolderRepository {
  FolderRepository(this._db);

  final AppDatabase _db;

  Stream<List<Folder>> watchAll() {
    return (_db.select(_db.folders)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .watch();
  }

  Future<String> create({required String name}) async {
    final id = newId();
    final lastSort = await (_db.selectOnly(
      _db.folders,
    )..addColumns([_db.folders.sortOrder.max()])).getSingleOrNull();
    final nextSort = (lastSort?.read(_db.folders.sortOrder.max()) ?? -1) + 1;
    await _db
        .into(_db.folders)
        .insert(
          FoldersCompanion.insert(
            id: id,
            userId: kLocalUserId,
            name: name,
            sortOrder: Value(nextSort),
          ),
        );
    return id;
  }

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(name: Value(name)),
    );
  }

  /// 软删文件夹。其下清单的 folder_id 一并清掉(上浮回根目录),
  /// 避免出现"清单挂在已删文件夹下"的孤儿状态。
  Future<void> softDelete(Folder folder) async {
    await _db.transaction(() async {
      await (_db.update(_db.taskLists)
            ..where((t) => t.folderId.equals(folder.id)))
          .write(const TaskListsCompanion(folderId: Value(null)));
      await (_db.update(_db.folders)..where((t) => t.id.equals(folder.id)))
          .write(FoldersCompanion(deletedAt: Value(DateTime.now())));
    });
  }
}

@Riverpod(keepAlive: true)
FolderRepository folderRepository(Ref ref) {
  return FolderRepository(ref.watch(appDatabaseProvider));
}

@riverpod
Stream<List<Folder>> allFolders(Ref ref) {
  return ref.watch(folderRepositoryProvider).watchAll();
}
