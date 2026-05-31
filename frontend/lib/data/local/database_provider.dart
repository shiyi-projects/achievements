import 'package:achievements/data/local/database.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// 当前登录用户专属 [AppDatabase] 单例。
///
/// 每个 appUserId 使用独立 SQLite 文件,避免遗漏 userId 过滤时跨账号串数据。
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final userId = ref.watch(currentUserIdProvider);
  final db = AppDatabase(userId: userId);
  ref.onDispose(db.close);
  return db;
}
