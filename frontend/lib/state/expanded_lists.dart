import 'dart:async';
import 'dart:convert';

import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expanded_lists.g.dart';

/// 侧栏里已展开的清单 ID 集合(有子清单的那些)。
///
/// 持久化到本地 `app_preferences`,冷启动后保持上次的展开状态——清单一多,
/// 每次开机全部折叠会让侧栏不可用。不入 outbox:展开与否是本机视图偏好。
@Riverpod(keepAlive: true)
class ExpandedLists extends _$ExpandedLists {
  static const _prefKey = 'expanded_lists';

  @override
  Set<String> build() {
    // 首帧先给空集合,读盘完成后再推一次状态。
    unawaited(_restore());
    return <String>{};
  }

  void toggle(String listId) {
    final next = {...state};
    if (!next.add(listId)) next.remove(listId);
    state = next;
    unawaited(_persist(next));
  }

  void expand(String listId) {
    if (state.contains(listId)) return;
    final next = {...state, listId};
    state = next;
    unawaited(_persist(next));
  }

  Future<void> _restore() async {
    final db = _db;
    if (db == null) return;
    final row = await (db.select(
      db.appPreferences,
    )..where((t) => t.key.equals(_prefKey))).getSingleOrNull();
    if (row == null) return;
    final decoded = jsonDecode(row.value);
    if (decoded is! List) return;
    state = {
      for (final item in decoded)
        if (item is String) item,
    };
  }

  Future<void> _persist(Set<String> ids) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.appPreferences)
        .insertOnConflictUpdate(
          AppPreferencesCompanion(
            key: const Value(_prefKey),
            value: Value(jsonEncode(ids.toList())),
          ),
        );
  }

  AppDatabase? get _db {
    if (ref.read(currentAuthSessionProvider) == null) return null;
    return ref.read(appDatabaseProvider);
  }
}
