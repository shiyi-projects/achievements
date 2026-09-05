import 'package:achievements/core/app_info.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:achievements/features/settings/sections/about_section.dart';
import 'package:achievements/features/settings/sections/appearance_section.dart';
import 'package:achievements/features/settings/sections/keepalive_section.dart';
import 'package:achievements/features/settings/sections/sync_section.dart';
import 'package:achievements/features/settings/widgets/settings_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 显示设置页弹窗(桌面用 dialog,移动用 bottom sheet)。
void showSettingsDialog(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 600) {
    showDialog<void>(context: context, builder: (_) => const _SettingsDialog());
  } else {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.panel)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.92,
        child: SettingsPage(showCloseButton: true),
      ),
    );
  }
}

/// 桌面弹窗容器。刻意不用主题里的 Dialog 样式(28px 圆角 + 阴影)——这一页
/// 走极简语言:小圆角、无投影、只靠一条细边从背景中分离出来。
class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.panel),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: const SettingsPage(showCloseButton: true),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Settings — 极简分节列表
//
// 视觉取向见 widgets/settings_controls.dart:中性底色、发丝分割线、小圆角,
// 品牌色只出现在「当前选中」与主操作上。
// ─────────────────────────────────────────────────────────────────────

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showCloseButton = false});

  final bool showCloseButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final syncFailureCount =
        ref.watch(syncFailureCountProvider).valueOrNull ?? 0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          _Header(showCloseButton: showCloseButton),
          Expanded(
            child: settingsAsync.when(
              loading: () => const Center(child: SettingsSpinner(size: 18)),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (settings) => ListView(
                padding: const EdgeInsets.only(bottom: Spacing.xxl),
                children: [
                  SettingsSection(
                    title: '外观',
                    children: [
                      ThemeModeField(current: settings.themeMode),
                      SeedColorField(current: settings.seedColor),
                    ],
                  ),
                  if (defaultTargetPlatform == TargetPlatform.windows)
                    SettingsSection(
                      title: '桌面',
                      children: [
                        CloseActionField(current: settings.closeAction),
                      ],
                    ),
                  if (defaultTargetPlatform == TargetPlatform.android)
                    const SettingsSection(
                      title: '提醒与后台',
                      footer: '提醒由系统闹钟驱动,App 被后台清理也能到点提醒;为保证准时,建议关闭电池优化并允许自启动。',
                      children: [KeepAliveBlock()],
                    ),
                  SettingsSection(
                    title: '同步',
                    children: [
                      const SyncStatusRow(),
                      // 只在真有推不上去的改动时出现,避免平时占位。
                      if (syncFailureCount > 0)
                        SyncFailuresRow(count: syncFailureCount),
                      const SyncActionRow(),
                      const AccountBlock(),
                    ],
                  ),
                  const SettingsSection(
                    title: '关于',
                    children: [
                      VersionRow(),
                      CheckUpdateRow(),
                      LinkRow(
                        asset: AppIcons.github,
                        tinted: true,
                        label: 'GitHub',
                        url: kGithubUrl,
                      ),
                      LinkRow(
                        asset: AppIcons.bilibili,
                        label: '哔哩哔哩',
                        url: kBilibiliUrl,
                      ),
                      LicenseRow(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 页头:一行标题 + 关闭按钮 + 一条发丝线。比 AppBar 矮、无阴影、无色调层。
class _Header extends StatelessWidget {
  const _Header({required this.showCloseButton});

  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSettingsHPad),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '设置',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (showCloseButton)
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
        Container(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ],
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovering
                ? scheme.onSurface.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.controlInner),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
