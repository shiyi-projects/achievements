import 'package:achievements/app/app.dart';
import 'package:achievements/platform/windows/windows_app_init.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 在 runApp 之前创建,这样 Windows 端的托盘/窗口监听器和 widget 树共享
  // 同一个 Riverpod 容器,可以互相读写状态。
  final container = ProviderContainer();
  await initWindowsApp(container);
  await initializeDateFormatting('zh_CN');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AchievementsApp(),
    ),
  );
}
