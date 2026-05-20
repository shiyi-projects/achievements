import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 系统托盘服务。
///
/// 调用 [init] 完成注册,此后托盘图标常驻系统通知区:
/// - 单击 → 显示/聚焦主窗口
/// - 右键菜单 → 显示 / 退出
class TrayService with TrayListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  Future<void> init() async {
    if (!_isWindows) return;
    trayManager.addListener(this);
    await trayManager.setIcon('assets/app_icon.ico');
    await trayManager.setToolTip('Achievements');
    await _rebuildMenu();
  }

  Future<void> dispose() async {
    if (!_isWindows) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  Future<void> _rebuildMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show',
            label: '显示主窗口',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: '退出',
          ),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => _bringToFront();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _bringToFront();
      case 'quit':
        windowManager.destroy();
    }
  }

  Future<void> _bringToFront() async {
    await windowManager.show();
    await windowManager.focus();
  }
}

bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;
