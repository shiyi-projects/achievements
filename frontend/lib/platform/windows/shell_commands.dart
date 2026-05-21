import 'dart:async';

import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 由托盘/窗口监听器发往主 widget 树的命令。
///
/// 这些组件运行在 Riverpod 容器内但缺少 BuildContext,无法直接弹 dialog
/// 或调用 GoRouter,因此通过 [shellCommandProvider] 把意图扔进状态流,由
/// AppShell `ref.listen` 后真正执行。
sealed class ShellCommand {
  const ShellCommand();
}

/// 显示主窗口并切到"今天"清单视图。
class ShowTodayCommand extends ShellCommand {
  const ShowTodayCommand();
}

/// 显示主窗口并切到"专注"视图。
class ShowFocusCommand extends ShellCommand {
  const ShowFocusCommand();
}

/// 显示主窗口并打开设置面板。
class OpenSettingsCommand extends ShellCommand {
  const OpenSettingsCommand();
}

/// 用户点 X 时,关闭行为设置为 [CloseAction.ask],
/// 让 shell 弹 dialog 询问用户;完成后通过 [completer] 把选择回传给
/// WindowListener,后者据此 hide 或 destroy。
class AskCloseCommand extends ShellCommand {
  AskCloseCommand(this.completer);
  final Completer<CloseAction> completer;
}

/// AppShell 监听此 provider;每当其值变为非 null 就执行对应动作并立即
/// 重置为 null(单次触发)。
final shellCommandProvider = StateProvider<ShellCommand?>((ref) => null);
