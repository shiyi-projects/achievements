import 'dart:async';
import 'dart:io';

import 'package:achievements/platform/windows/tray_service.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 端"真退出"的统一入口。
///
/// X 按钮的 exit 分支和托盘的"退出"菜单都走这里。
///
/// 步骤:
/// 1. 销毁托盘图标,释放 Shell_NotifyIcon 资源(避免残留)
/// 2. 关掉 preventClose 拦截
/// 3. fire-and-forget 调用 windowManager.destroy(),让原生窗口立刻消失
/// 4. exit(0) 强制 ExitProcess
///
/// 为什么不 await destroy:window_manager.destroy() 在 preventClose=true 路径上
/// 会和引擎关闭流程死锁——Dart 这边 await 永远收不到回执,主消息循环虽然
/// 收到了 WM_QUIT,但 Dart isolate 还在等 → 进程不退出。所以全部步骤都加
/// 超时,最终用 exit(0) 直接调 Windows ExitProcess 兜底。
Future<void> quitApp() async {
  try {
    await TrayService.instance.dispose().timeout(
      const Duration(seconds: 1),
      onTimeout: () {},
    );
    await windowManager
        .setPreventClose(false)
        .timeout(const Duration(milliseconds: 500), onTimeout: () {});
    unawaited(windowManager.destroy());
  } catch (_) {
    // 任何异常都忽略,exit(0) 兜底
  }
  exit(0);
}
