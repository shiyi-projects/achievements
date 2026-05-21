import 'dart:async';

import 'package:achievements/core/sync/sync_coordinator.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:achievements/platform/windows/shell_commands.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// 监听 Windows 窗口事件。
///
/// 两个职责:
/// - **关闭按钮**:`onWindowClose` 读用户偏好,决定 hide / destroy / ask
/// - **窗口聚焦**:`onWindowFocus` 节流地触发一次同步(Alt+Tab 回到 app 或
///   点了一下窗口时,把云端新东西拉下来,无需用户去点"立即同步")
class AppWindowListener extends WindowListener {
  AppWindowListener(this._container);

  final ProviderContainer _container;

  @override
  Future<void> onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (!isPreventClose) return;

    final action = _container
            .read(settingsNotifierProvider)
            .valueOrNull
            ?.closeAction ??
        kDefaultSettings.closeAction;

    switch (action) {
      case CloseAction.minimizeToTray:
        await windowManager.hide();
      case CloseAction.exitApp:
        await _destroy();
      case CloseAction.ask:
        await _askAndAct();
    }
  }

  @override
  void onWindowFocus() {
    // 节流由 coordinator.triggerIfStale 处理,这里不用 await。
    unawaited(_container.read(syncCoordinatorProvider).triggerIfStale());
  }

  Future<void> _askAndAct() async {
    final completer = Completer<CloseAction>();
    _container.read(shellCommandProvider.notifier).state =
        AskCloseCommand(completer);
    final picked = await completer.future;
    switch (picked) {
      case CloseAction.minimizeToTray:
        await windowManager.hide();
      case CloseAction.exitApp:
        await _destroy();
      case CloseAction.ask:
        // 防御:ask dialog 不应把 ask 自身作为结果,理论上不会走到
        await windowManager.hide();
    }
  }

  Future<void> _destroy() async {
    // preventClose=true 下需先关掉拦截,destroy 才能正常进入退出路径
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
