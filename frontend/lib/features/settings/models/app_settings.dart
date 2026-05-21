import 'package:achievements/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 桌面端关闭按钮(右上角 X)行为。仅在 Windows 上生效。
enum CloseAction {
  /// 最小化到系统托盘,程序继续在后台运行(默认)。
  minimizeToTray('tray'),

  /// 真正退出进程。
  exitApp('exit'),

  /// 每次点 X 时弹 dialog 让用户当下选择。
  ask('ask');

  const CloseAction(this.value);
  final String value;

  static CloseAction fromValue(String? value) => switch (value) {
    'exit' => CloseAction.exitApp,
    'ask' => CloseAction.ask,
    _ => CloseAction.minimizeToTray,
  };
}

typedef AppSettingsData = ({
  ThemeMode themeMode,
  Color seedColor,
  CloseAction closeAction,
});

const AppSettingsData kDefaultSettings = (
  themeMode: ThemeMode.system,
  seedColor: AppColors.seedTechBlue,
  closeAction: CloseAction.minimizeToTray,
);

/// 预设种子色列表,顺序与设置页色板一致。
const List<({String name, Color color})> kPresetColors = [
  (name: '科技蓝', color: AppColors.seedTechBlue),
  (name: '薄荷绿', color: AppColors.seedMintGreen),
  (name: '海洋蓝', color: AppColors.seedOceanBlue),
  (name: '森林绿', color: AppColors.seedForestGreen),
  (name: '日落橙', color: AppColors.seedSunsetOrange),
  (name: '纯净灰', color: AppColors.seedNeutralGray),
];
