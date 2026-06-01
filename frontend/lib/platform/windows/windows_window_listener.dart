import 'dart:async';

import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:achievements/platform/windows/quit_app.dart';
import 'package:achievements/platform/windows/shell_commands.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// 监听 Windows 窗口事件。
///
/// 职责:
/// - **关闭按钮**:`onWindowClose` 读用户偏好,决定 hide / destroy / ask
///
/// 注:窗口聚焦不再自动触发同步——按「不每次打开都同」的策略,远端变更靠启动
/// 拉取或用户手动「立即同步」/下拉刷新获取。
class AppWindowListener extends WindowListener {
  AppWindowListener(this._container);

  final ProviderContainer _container;

  @override
  Future<void> onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) return;

    final action =
        _container.read(settingsNotifierProvider).valueOrNull?.closeAction ??
        kDefaultSettings.closeAction;

    switch (action) {
      case CloseAction.minimizeToTray:
        await windowManager.hide();
      case CloseAction.exitApp:
        await quitApp();
      case CloseAction.ask:
        await _askAndAct();
    }
  }

  Future<void> _askAndAct() async {
    final completer = Completer<CloseAction>();
    _container.read(shellCommandProvider.notifier).state = AskCloseCommand(
      completer,
    );
    // 安全超时:如果 dialog 无法弹出(上下文已销毁等),30 秒后自动 fallback 到最小化,
    // 避免 completer 永远不 complete 导致卡死。
    final picked = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => CloseAction.minimizeToTray,
    );
    switch (picked) {
      case CloseAction.minimizeToTray:
        await windowManager.hide();
      case CloseAction.exitApp:
        await quitApp();
      case CloseAction.ask:
        // 防御:ask dialog 不应把 ask 自身作为结果,理论上不会走到
        await windowManager.hide();
    }
  }
}
