import 'dart:io';

import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/connection.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LegacyImportService {
  LegacyImportService(
    this._target,
    this._outbox,
    this._lists,
    this._userId, {
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final AppDatabase _target;
  final OutboxRepository _outbox;
  final ListRepository _lists;
  final String _userId;
  final FlutterSecureStorage _storage;

  static const _marker = 'legacy_import_done';
  static const _skippedForeignMarker = 'legacy_import_skipped_foreign';
  static const _ownerKey = 'legacy_import_owner_user_id';

  Future<void> importIfNeeded() async {
    if ((await _outbox.getCursor(_marker)) == 'true') return;
    if ((await _outbox.getCursor(_skippedForeignMarker)) == 'true') return;

    final docs = await getApplicationDocumentsDirectory();
    final legacyFile = File(p.join(docs.path, kLegacyDatabaseFileName));
    if (!legacyFile.existsSync()) {
      await _outbox.setCursor(_marker, 'true');
      return;
    }

    final decision = await _autoImportDecision();
    switch (decision) {
      case _LegacyAutoImportDecision.import:
        await _importLegacy();
      case _LegacyAutoImportDecision.skipForeign:
        await _outbox.setCursor(_skippedForeignMarker, 'true');
      case _LegacyAutoImportDecision.skipUnclaimed:
        // 无归属旧库不能静默导入任意账号；保持可显式导入状态。
        return;
    }
  }

  Future<_LegacyAutoImportDecision> _autoImportDecision() async {
    final owner = await _storage.read(key: _ownerKey);
    if (owner != null && owner.isNotEmpty) {
      return owner == _userId
          ? _LegacyAutoImportDecision.import
          : _LegacyAutoImportDecision.skipForeign;
    }

    final legacy = AppDatabase();
    try {
      final ownerIds = await _legacyOwnerIds(legacy);
      if (ownerIds.isEmpty) {
        await _storage.write(key: _ownerKey, value: _userId);
        return _LegacyAutoImportDecision.import;
      }
      if (ownerIds.length == 1 && ownerIds.single == _userId) {
        await _storage.write(key: _ownerKey, value: _userId);
        return _LegacyAutoImportDecision.import;
      }
      if (ownerIds.isNotEmpty && !ownerIds.contains(_userId)) {
        return _LegacyAutoImportDecision.skipForeign;
      }
      return _LegacyAutoImportDecision.skipUnclaimed;
    } finally {
      await legacy.close();
    }
  }

  Future<Set<String>> _legacyOwnerIds(AppDatabase legacy) async {
    final ids = <String>{};
    ids.addAll(
      (await legacy.select(legacy.folders).get()).map((row) => row.userId),
    );
    ids.addAll(
      (await legacy.select(legacy.taskLists).get()).map((row) => row.userId),
    );
    ids.addAll(
      (await legacy.select(legacy.tasks).get()).map((row) => row.userId),
    );
    ids.addAll(
      (await legacy.select(legacy.tags).get()).map((row) => row.userId),
    );
    ids.addAll(
      (await legacy.select(legacy.focusSessions).get()).map(
        (row) => row.userId,
      ),
    );
    ids.removeWhere((id) => id.isEmpty);
    return ids;
  }

  Future<void> _importLegacy() async {
    final legacy = AppDatabase();
    try {
      await _lists.ensureSystemLists();
      await _target.transaction(() async {
        await _copyFolders(legacy);
        await _copyLists(legacy);
        await _copyTags(legacy);
        await _copyTasks(legacy);
        await _copyTaskTags(legacy);
        await _copyFocusSessions(legacy);
        await _outbox.setCursor(SyncCursorKey.firstSyncDone, 'false');
        await _outbox.setCursor(_marker, 'true');
      });
    } finally {
      await legacy.close();
    }
  }

  Future<void> _copyFolders(AppDatabase legacy) async {
    final rows = await legacy.select(legacy.folders).get();
    for (final row in rows) {
      await _target
          .into(_target.folders)
          .insertOnConflictUpdate(
            FoldersCompanion(
              id: Value(row.id),
              userId: Value(_userId),
              name: Value(row.name),
              sortOrder: Value(row.sortOrder),
              createdAt: Value(row.createdAt),
              updatedAt: Value(row.updatedAt),
              deletedAt: Value(row.deletedAt),
              version: Value(row.version),
            ),
          );
      await _outbox.enqueue(
        entity: 'folder',
        op: row.deletedAt == null ? 'upsert' : 'delete',
        entityId: row.id,
        baseVersion: 0,
        payload: row.deletedAt == null
            ? {'name': row.name, 'sort_order': row.sortOrder}
            : const {},
      );
    }
  }

  Future<void> _copyLists(AppDatabase legacy) async {
    final rows = await legacy.select(legacy.taskLists).get();
    for (final row in rows) {
      final kind = SystemListKind.fromValue(row.systemKind);
      final id = kind == null ? row.id : systemListIdForUser(_userId, kind);
      if (kind != null) continue;
      await _target
          .into(_target.taskLists)
          .insertOnConflictUpdate(
            TaskListsCompanion(
              id: Value(id),
              userId: Value(_userId),
              folderId: Value(row.folderId),
              name: Value(row.name),
              color: Value(row.color),
              icon: Value(row.icon),
              sortOrder: Value(row.sortOrder),
              isSystem: Value(row.isSystem),
              systemKind: Value(row.systemKind),
              createdAt: Value(row.createdAt),
              updatedAt: Value(row.updatedAt),
              deletedAt: Value(row.deletedAt),
              version: Value(row.version),
            ),
          );
      await _outbox.enqueue(
        entity: 'list',
        op: row.deletedAt == null ? 'upsert' : 'delete',
        entityId: id,
        baseVersion: 0,
        payload: row.deletedAt == null
            ? {
                'name': row.name,
                'folder_id': row.folderId,
                'color': row.color,
                'icon': row.icon,
                'sort_order': row.sortOrder,
                'is_system': false,
              }
            : const {},
      );
    }
  }

  Future<void> _copyTags(AppDatabase legacy) async {
    final rows = await legacy.select(legacy.tags).get();
    for (final row in rows) {
      await _target
          .into(_target.tags)
          .insertOnConflictUpdate(
            TagsCompanion(
              id: Value(row.id),
              userId: Value(_userId),
              name: Value(row.name),
              color: Value(row.color),
              createdAt: Value(row.createdAt),
              updatedAt: Value(row.updatedAt),
              deletedAt: Value(row.deletedAt),
              version: Value(row.version),
            ),
          );
      await _outbox.enqueue(
        entity: 'tag',
        op: row.deletedAt == null ? 'upsert' : 'delete',
        entityId: row.id,
        baseVersion: 0,
        payload: row.deletedAt == null
            ? {'name': row.name, 'color': row.color}
            : const {},
      );
    }
  }

  Future<void> _copyTasks(AppDatabase legacy) async {
    final rows = await legacy.select(legacy.tasks).get();
    for (final row in rows) {
      final listId = _mappedListId(row.listId);
      await _target
          .into(_target.tasks)
          .insertOnConflictUpdate(
            TasksCompanion(
              id: Value(row.id),
              userId: Value(_userId),
              listId: Value(listId),
              parentId: Value(row.parentId),
              title: Value(row.title),
              notes: Value(row.notes),
              priority: Value(row.priority),
              dueAt: Value(row.dueAt),
              remindAt: Value(row.remindAt),
              repeatRule: Value(row.repeatRule),
              color: Value(row.color),
              sortOrder: Value(row.sortOrder),
              completedAt: Value(row.completedAt),
              archivedAt: Value(row.archivedAt),
              starred: Value(row.starred),
              estimatedMinutes: Value(row.estimatedMinutes),
              focusedSeconds: Value(row.focusedSeconds),
              createdAt: Value(row.createdAt),
              updatedAt: Value(row.updatedAt),
              deletedAt: Value(row.deletedAt),
              version: Value(row.version),
            ),
          );
      await _outbox.enqueue(
        entity: 'task',
        op: row.deletedAt == null ? 'upsert' : 'delete',
        entityId: row.id,
        baseVersion: 0,
        payload: row.deletedAt == null
            ? {
                'list_id': listId,
                'parent_id': row.parentId,
                'title': row.title,
                'notes': row.notes,
                'priority': row.priority,
                'due_at': row.dueAt?.toUtc().toIso8601String(),
                'remind_at': row.remindAt?.toUtc().toIso8601String(),
                'repeat_rule': row.repeatRule,
                'color': row.color,
                'sort_order': row.sortOrder,
                'completed_at': row.completedAt?.toUtc().toIso8601String(),
                'archived_at': row.archivedAt?.toUtc().toIso8601String(),
                'starred': row.starred,
                'estimated_minutes': row.estimatedMinutes,
              }
            : const {},
      );
    }
  }

  Future<void> _copyTaskTags(AppDatabase legacy) async {
    final rows = await legacy.select(legacy.taskTags).get();
    for (final row in rows) {
      await _target
          .into(_target.taskTags)
          .insertOnConflictUpdate(
            TaskTagsCompanion.insert(taskId: row.taskId, tagId: row.tagId),
          );
    }
  }

  Future<void> _copyFocusSessions(AppDatabase legacy) async {
    final rows = await legacy.select(legacy.focusSessions).get();
    for (final row in rows) {
      await _target
          .into(_target.focusSessions)
          .insertOnConflictUpdate(
            FocusSessionsCompanion(
              id: Value(row.id),
              userId: Value(_userId),
              taskId: Value(row.taskId),
              startedAt: Value(row.startedAt),
              endedAt: Value(row.endedAt),
              durationSeconds: Value(row.durationSeconds),
              mode: Value(row.mode),
              completed: Value(row.completed),
              createdAt: Value(row.createdAt),
            ),
          );
    }
  }

  String _mappedListId(String legacyListId) {
    for (final entry in kLegacySystemListIds.entries) {
      if (entry.value == legacyListId) {
        final kind = SystemListKind.fromValue(entry.key)!;
        return systemListIdForUser(_userId, kind);
      }
    }
    return legacyListId;
  }
}

enum _LegacyAutoImportDecision { import, skipForeign, skipUnclaimed }

final legacyImportServiceProvider = Provider<LegacyImportService>((ref) {
  return LegacyImportService(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxRepositoryProvider),
    ref.watch(listRepositoryProvider),
    ref.watch(currentUserIdProvider),
  );
});
