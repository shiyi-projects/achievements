import 'package:achievements/core/app_info.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/core/update/update_checker.dart';
import 'package:achievements/features/settings/widgets/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionRow extends StatelessWidget {
  const VersionRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsRow(
      title: 'Achievements',
      subtitle: 'by $kAuthor',
      value: 'v$kAppVersion',
    );
  }
}

class CheckUpdateRow extends ConsumerStatefulWidget {
  const CheckUpdateRow({super.key});

  @override
  ConsumerState<CheckUpdateRow> createState() => _CheckUpdateRowState();
}

class _CheckUpdateRowState extends ConsumerState<CheckUpdateRow> {
  bool _checking = false;

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final info = await ref.read(updateCheckerProvider).check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已是最新版本(或暂时无法连接 GitHub)')));
    } else {
      await _showUpdateDialog(info);
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.panel),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '发现新版本 v${info.version}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  '前往下载页面获取最新版:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                SelectableText(
                  info.url,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: Spacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SettingsMiniButton(
                      label: '稍后',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(width: Spacing.sm),
                    SettingsMiniButton(
                      label: '复制链接',
                      accent: true,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: info.url));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('下载链接已复制')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      title: '检查更新',
      trailing: _checking ? const SettingsSpinner() : null,
      showChevron: !_checking,
      onTap: _checking ? null : _checkUpdate,
    );
  }
}

/// 一行外链(点击调系统默认浏览器打开)。打开失败时回退到复制链接并提示。
///
/// [tinted] 为 true 时把单色 SVG 着成中性色(GitHub 纯黑标志在深色模式需要跟随
/// 前景色);否则保留品牌原色(如哔哩哔哩品牌蓝)。
class LinkRow extends StatelessWidget {
  const LinkRow({
    required this.asset,
    required this.label,
    required this.url,
    this.tinted = false,
    super.key,
  });

  final String asset;
  final String label;
  final String url;
  final bool tinted;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened) return;
    // 回退:打不开浏览器就复制链接,并明确告知用户(不静默失败)。
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(SnackBar(content: Text('未能打开浏览器,$label 链接已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 不显示 URL:一行长链接会把行高撑成两行,而它对用户没有信息量 —— 点开
    // 就知道去哪。打不开时的回退提示里会带上链接。
    return SettingsRow(
      title: label,
      trailing: SizedBox(
        width: 16,
        height: 16,
        child: AppIcons.svgIcon(
          asset,
          size: 16,
          color: tinted ? scheme.onSurfaceVariant : null,
        ),
      ),
      showChevron: true,
      onTap: () => _open(context),
    );
  }
}

class LicenseRow extends StatelessWidget {
  const LicenseRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      title: '开源许可',
      showChevron: true,
      onTap: () => showLicensePage(context: context),
    );
  }
}
