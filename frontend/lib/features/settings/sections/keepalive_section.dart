import 'package:achievements/features/settings/widgets/settings_controls.dart';
import 'package:achievements/platform/android/keepalive_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 提醒与后台保活(Android)。
///
/// 两行共享一份「是否已豁免电池优化」的探测结果,所以合成一个块,内部自绘
/// 分隔线。
class KeepAliveBlock extends ConsumerStatefulWidget {
  const KeepAliveBlock({super.key});

  @override
  ConsumerState<KeepAliveBlock> createState() => _KeepAliveBlockState();
}

class _KeepAliveBlockState extends ConsumerState<KeepAliveBlock>
    with WidgetsBindingObserver {
  bool? _ignoring; // null = 检测中

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置页返回时重新检测豁免状态。
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final v = await ref
        .read(keepAliveServiceProvider)
        .isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _ignoring = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final service = ref.read(keepAliveServiceProvider);
    final detecting = _ignoring == null;
    final exempt = _ignoring ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          title: '电池优化豁免',
          subtitle: detecting
              ? '检测中…'
              : exempt
              ? '已豁免,提醒不会被省电策略掐断'
              : '未豁免,后台可能延迟或拦截提醒',
          leadingDot: detecting
              ? scheme.outline
              : exempt
              ? scheme.primary
              : scheme.error,
          trailing: detecting
              ? const SettingsSpinner()
              : exempt
              ? null
              : SettingsMiniButton(
                  label: '允许',
                  accent: true,
                  onPressed: () async {
                    await service.requestIgnoreBatteryOptimizations();
                    // 返回后由 didChangeAppLifecycleState 刷新状态。
                  },
                ),
          value: exempt && !detecting ? '已豁免' : null,
        ),
        const SettingsHairline(inset: true),
        SettingsRow(
          title: '自启动管理',
          subtitle: '在系统里允许本应用自启动(部分品牌需手动开启)',
          trailing: SettingsMiniButton(
            label: '前往',
            onPressed: () async {
              final ok = await service.openAutoStartSettings();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未能打开系统设置,请手动前往「设置」开启自启动')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
