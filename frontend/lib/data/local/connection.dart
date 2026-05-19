import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

const String _kDatabaseFileName = 'achievements.db';

/// 打开本地 SQLite 数据库文件。
///
/// 使用 [LazyDatabase] 延迟初始化,避免在路径解析完成前阻塞应用启动。
/// Android 老版本需要先应用 sqlite3_flutter_libs 提供的兼容补丁。
QueryExecutor openLocalConnection() {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, _kDatabaseFileName));

    final cacheDir = await getTemporaryDirectory();
    sqlite3.tempDirectory = cacheDir.path;

    return NativeDatabase.createInBackground(file);
  });
}
