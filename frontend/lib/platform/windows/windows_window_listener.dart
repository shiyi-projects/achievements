import 'package:window_manager/window_manager.dart';

/// 拦截窗口关闭事件:点 X 时最小化到托盘而非真正退出。
///
/// 在 [WindowManager.setPreventClose] = true 后需要手动处理关闭。
class AppWindowListener extends WindowListener {

  @override
  Future<void> onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }
}
