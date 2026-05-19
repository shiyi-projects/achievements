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
}

@Riverpod(keepAlive: true)
FolderRepository folderRepository(Ref ref) {
  return FolderRepository(ref.watch(appDatabaseProvider));
}

@riverpod
Stream<List<Folder>> allFolders(Ref ref) {
  return ref.watch(folderRepositoryProvider).watchAll();
}
