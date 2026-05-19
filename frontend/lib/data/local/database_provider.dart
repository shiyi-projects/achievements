import 'package:achievements/data/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// 应用全局 [AppDatabase] 单例。
///
/// keepAlive 保持整个 App 生命周期都共享一个数据库连接;
/// dispose 时(应用退出 / 测试覆盖)关闭连接释放文件句柄。
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
