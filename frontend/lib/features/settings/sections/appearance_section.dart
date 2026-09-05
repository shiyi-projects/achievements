import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:achievements/features/settings/widgets/settings_controls.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 外观:主题模式(浅色 / 深色 / 跟随系统)。
class ThemeModeField extends ConsumerWidget {
  const ThemeModeField({required this.current, super.key});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return SettingsField(
      label: '主题模式',
      child: SettingsSegmented<ThemeMode>(
        segments: const [
          (value: ThemeMode.system, label: '跟随系统'),
          (value: ThemeMode.light, label: '浅色'),
          (value: ThemeMode.dark, label: '深色'),
        ],
        selected: current,
        onChanged: notifier.setThemeMode,
      ),
    );
  }
}

/// 外观:主题色。
///
/// 色卡是全页唯一出现饱和色的地方,所以做成小方块而非大圆点:够点、够识别,
/// 又不至于在中性底色上砸出一片彩色。选中态用描边 + 细勾,不用发光阴影。
class SeedColorField extends ConsumerWidget {
  const SeedColorField({required this.current, super.key});

  final Color current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return SettingsField(
      label: '主题色',
      description: '只用于强调:选中项、主操作与进行中的状态',
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          for (final preset in kPresetColors)
            _ColorSwatch(
              name: preset.name,
              color: preset.color,
              selected: current.toARGB32() == preset.color.toARGB32(),
              onTap: () => notifier.setSeedColor(preset.color),
            ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Tooltip(
      message: name,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: MotionDurations.instant,
            curve: MotionCurves.decelerate,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control + 2),
              border: Border.all(
                color: selected ? scheme.onSurface : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(Radii.controlInner),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 15, color: onColor)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 桌面:关闭按钮行为(Windows only)。
class CloseActionField extends ConsumerWidget {
  const CloseActionField({required this.current, super.key});

  final CloseAction current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return SettingsField(
      label: '关闭按钮行为',
      description: '点击窗口右上角 X 时的默认动作',
      child: SettingsSegmented<CloseAction>(
        segments: const [
          (value: CloseAction.minimizeToTray, label: '最小化到托盘'),
          (value: CloseAction.exitApp, label: '退出'),
          (value: CloseAction.ask, label: '每次询问'),
        ],
        selected: current,
        onChanged: notifier.setCloseAction,
      ),
    );
  }
}
