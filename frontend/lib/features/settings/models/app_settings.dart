import 'package:achievements/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

typedef AppSettingsData = ({ThemeMode themeMode, Color seedColor});

const AppSettingsData kDefaultSettings = (
  themeMode: ThemeMode.system,
  seedColor: AppColors.seedTechBlue,
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
