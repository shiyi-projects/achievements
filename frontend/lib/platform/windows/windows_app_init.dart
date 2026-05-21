import 'package:achievements/platform/windows/tray_service.dart';
import 'package:achievements/platform/windows/windows_window_listener.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 平台初始化:窗口管理 + 系统托盘。
/// 必须在 `runApp` 之前调用 [initWindowsApp],在 WidgetsFlutterBinding 完成后。
///
/// [container] 用来让托盘/窗口监听器读写 Riverpod 状态(读用户偏好、推
/// shellCommand 给 widget 树等)。
Future<void> initWindowsApp(ProviderContainer container) async {
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

  // 拦截 X,具体动作交给 AppWindowListener 按设置分支处理。
  await windowManager.setPreventClose(true);
  windowManager.addListener(AppWindowListener(container));

  await TrayService.instance.init(container);
}
