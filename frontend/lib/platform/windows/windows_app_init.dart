import 'package:achievements/platform/windows/tray_service.dart';
import 'package:achievements/platform/windows/windows_window_listener.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 平台初始化:窗口管理 + 系统托盘。
/// 必须在 `runApp` 之前调用 [initWindowsApp],在 WidgetsFlutterBinding 完成后。
Future<void> initWindowsApp() async {
  if (defaultTargetPlatform != TargetPlatform.windows) return;

  await windowManager.ensureInitialized();
  const options = WindowOptions(
    minimumSize: Size(600, 480),
    title: 'Achievements',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 关闭时最小化到托盘,不退出进程
  await windowManager.setPreventClose(true);
  windowManager.addListener(AppWindowListener());

  await TrayService.instance.init();
}
