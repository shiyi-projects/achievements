import 'package:achievements/platform/windows/shell_commands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 系统托盘服务。
///
/// 调用 [init] 完成注册,此后托盘图标常驻系统通知区:
/// - 单击图标 → 显示/聚焦主窗口
/// - 右键菜单 → 显示/隐藏 / 今天 / 专注 / 设置 / 退出
class TrayService with TrayListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  late ProviderContainer _container;
  bool _windowVisible = true;

  Future<void> init(ProviderContainer container) async {
    if (!_isWindows) return;
    _container = container;
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

  /// 重建右键菜单。窗口可见状态变化时调用,可以刷新"显示/隐藏"那一项的文案。
  Future<void> _rebuildMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'toggle',
            label: _windowVisible ? '隐藏主窗口' : '显示主窗口',
          ),
          MenuItem.separator(),
          MenuItem(key: 'today', label: '今天'),
          MenuItem(key: 'focus', label: '开始专注'),
          MenuItem(key: 'settings', label: '设置…'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => _bringToFront();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle':
        _toggleWindow();
      case 'today':
        _bringToFront();
        _container.read(shellCommandProvider.notifier).state =
            const ShowTodayCommand();
      case 'focus':
        _bringToFront();
        _container.read(shellCommandProvider.notifier).state =
            const ShowFocusCommand();
      case 'settings':
        _bringToFront();
        _container.read(shellCommandProvider.notifier).state =
            const OpenSettingsCommand();
      case 'quit':
        // 用户在托盘里主动选退出 → 真退。绕过 preventClose,以免被关闭设置拦截。
        windowManager.setPreventClose(false).then((_) {
          windowManager.destroy();
        });
    }
  }

  Future<void> _toggleWindow() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
      _windowVisible = false;
    } else {
      await _bringToFront();
    }
    await _rebuildMenu();
  }

  Future<void> _bringToFront() async {
    await windowManager.show();
    await windowManager.focus();
    _windowVisible = true;
    await _rebuildMenu();
  }
}

bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;
