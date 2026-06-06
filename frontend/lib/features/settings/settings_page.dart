import 'dart:async';

import 'package:achievements/core/app_info.dart';
import 'package:achievements/core/sync/sync_coordinator.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/update/update_checker.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:achievements/platform/android/keepalive_service.dart';
import 'package:achievements/shared/widgets/surface_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      showDragHandle: true,
      builder: (_) =>
          const FractionallySizedBox(heightFactor: 0.9, child: SettingsPage()),
    );
  }
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sheet),
          child: const SettingsPage(showCloseButton: true),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Settings Page
// ─────────────────────────────────────────────────────────────────────

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showCloseButton = false});

  final bool showCloseButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('设置'),
        automaticallyImplyLeading: false,
        actions: [
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            Spacing.xl,
          ),
          children: [
            const _SectionHeader('外观'),
            SurfaceCard(
              children: [
                _ThemeModeSection(current: settings.themeMode),
                const SizedBox(height: Spacing.base),
                _ColorSection(current: settings.seedColor),
              ],
            ),
            if (defaultTargetPlatform == TargetPlatform.windows) ...[
              const _SectionHeader('桌面'),
              SurfaceCard(
                children: [_CloseActionSection(current: settings.closeAction)],
              ),
            ],
            if (defaultTargetPlatform == TargetPlatform.android) ...[
              const _SectionHeader('提醒与后台'),
              const SurfaceCard(children: [_KeepAliveSection()]),
            ],
            const _SectionHeader('同步'),
            const SurfaceCard(children: [_SyncSection()]),
            const _SectionHeader('关于'),
            const SurfaceCard(
              padding: EdgeInsets.symmetric(vertical: Spacing.xs),
              children: [_AboutSection()],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xs,
        Spacing.lg,
        Spacing.xs,
        Spacing.sm,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Theme mode
// ─────────────────────────────────────────────────────────────────────

class _ThemeModeSection extends ConsumerWidget {
  const _ThemeModeSection({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: Text('主题模式', style: theme.textTheme.titleSmall),
        ),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('跟随系统'),
              icon: Icon(Icons.brightness_auto_rounded),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('浅色'),
              icon: Icon(Icons.light_mode_rounded),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('深色'),
              icon: Icon(Icons.dark_mode_rounded),
            ),
          ],
          selected: {current},
          onSelectionChanged: (sel) => notifier.setThemeMode(sel.first),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Seed color picker
// ─────────────────────────────────────────────────────────────────────

class _ColorSection extends ConsumerWidget {
  const _ColorSection({required this.current});

  final Color current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: Text('主题色', style: theme.textTheme.titleSmall),
        ),
        Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.md,
          children: kPresetColors.map((preset) {
            final isSelected = current.toARGB32() == preset.color.toARGB32();
            return Tooltip(
              message: preset.name,
              child: GestureDetector(
                onTap: () => notifier.setSeedColor(preset.color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: preset.color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.onSurface,
                            width: 2.5,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: preset.color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color:
                              ThemeData.estimateBrightnessForColor(
                                    preset.color,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 桌面:关闭按钮行为(Windows only)
// ─────────────────────────────────────────────────────────────────────

class _CloseActionSection extends ConsumerWidget {
  const _CloseActionSection({required this.current});

  final CloseAction current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.xs),
          child: Text('关闭按钮行为', style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: Text(
            '点击窗口右上角 X 时的默认动作',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SegmentedButton<CloseAction>(
          segments: const [
            ButtonSegment(
              value: CloseAction.minimizeToTray,
              label: Text('托盘'),
              icon: Icon(Icons.minimize_rounded),
            ),
            ButtonSegment(
              value: CloseAction.exitApp,
              label: Text('退出'),
              icon: Icon(Icons.power_settings_new_rounded),
            ),
            ButtonSegment(
              value: CloseAction.ask,
              label: Text('询问'),
              icon: Icon(Icons.help_outline_rounded),
            ),
          ],
          selected: {current},
          onSelectionChanged: (sel) => notifier.setCloseAction(sel.first),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 提醒与后台保活(Android)
// ─────────────────────────────────────────────────────────────────────

class _KeepAliveSection extends ConsumerStatefulWidget {
  const _KeepAliveSection();

  @override
  ConsumerState<_KeepAliveSection> createState() => _KeepAliveSectionState();
}

class _KeepAliveSectionState extends ConsumerState<_KeepAliveSection>
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final service = ref.read(keepAliveServiceProvider);
    final detecting = _ignoring == null;
    final exempt = _ignoring ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '为保证提醒准时触发,建议关闭对本应用的电池优化,并在系统里允许自启动。'
          '提醒本身由系统闹钟驱动,App 被后台清理也能到点提醒。',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: Spacing.base),

        // ── 电池优化豁免 ──
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            exempt
                ? Icons.battery_charging_full_rounded
                : Icons.battery_alert_rounded,
            color: exempt ? scheme.primary : scheme.error,
          ),
          title: const Text('电池优化豁免'),
          subtitle: Text(
            detecting
                ? '检测中…'
                : exempt
                ? '已豁免,提醒不会被省电策略掐断'
                : '未豁免,后台可能延迟或拦截提醒',
          ),
          trailing: exempt
              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
              : FilledButton.tonal(
                  onPressed: () async {
                    await service.requestIgnoreBatteryOptimizations();
                    // 返回后由 didChangeAppLifecycleState 刷新状态。
                  },
                  child: const Text('允许后台运行'),
                ),
        ),
        const Divider(height: Spacing.base),

        // ── 厂商自启动 ──
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.restart_alt_rounded, color: scheme.onSurface),
          title: const Text('自启动管理'),
          subtitle: const Text('在系统里允许本应用自启动(部分品牌需手动开启)'),
          trailing: OutlinedButton(
            onPressed: () async {
              final ok = await service.openAutoStartSettings();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未能打开系统设置,请手动前往「设置」开启自启动')),
                );
              }
            },
            child: const Text('前往设置'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sync (状态 + 上次同步 + 手动触发 + user_id)
// ─────────────────────────────────────────────────────────────────────

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ref.watch(syncStatusControllerProvider);
    final lastSyncAtAsync = ref.watch(lastSyncAtProvider);
    final lastSyncAt = lastSyncAtAsync.valueOrNull;
    final isSyncing = status == SyncStatus.syncing;

    final (statusIcon, statusColor, statusText) = switch (status) {
      SyncStatus.idle => (Icons.cloud_done_rounded, scheme.primary, '已同步'),
      SyncStatus.syncing => (Icons.cloud_sync_rounded, scheme.primary, '同步中…'),
      SyncStatus.error => (Icons.error_outline_rounded, scheme.error, '同步失败'),
      SyncStatus.offline => (Icons.cloud_off_rounded, scheme.outline, '离线'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 状态 + 上次同步 ──
        Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 20),
            const SizedBox(width: Spacing.sm),
            Text(
              statusText,
              style: theme.textTheme.titleSmall?.copyWith(color: statusColor),
            ),
            const Spacer(),
            Text(
              _formatLastSync(lastSyncAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),

        // ── 手动同步 ──
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: isSyncing
                ? null
                : () => unawaited(
                    ref.read(syncCoordinatorProvider).runFullSync(),
                  ),
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(isSyncing ? '同步中…' : '立即同步'),
          ),
        ),

        const SizedBox(height: Spacing.base),

        const _AccountSection(),
      ],
    );
  }

  /// 把 ISO 时间格式化为"X 分钟前"。
  String _formatLastSync(DateTime? at) {
    if (at == null) return '从未同步';
    final diff = DateTime.now().difference(at);
    if (diff.isNegative) return '刚刚';
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final session = switch (auth) {
      AuthAuthenticated(:final session) => session,
      _ => null,
    };
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (session == null) {
      return Text('未登录', style: TextStyle(color: scheme.onSurfaceVariant));
    }
    final nickname = session.profile.nickname?.trim();
    final avatarUrl = session.profile.avatarUrl?.trim();
    final avatarUri = avatarUrl == null ? null : Uri.tryParse(avatarUrl);
    final hasRemoteAvatar =
        avatarUri != null && avatarUri.hasScheme && avatarUri.hasAuthority;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundImage: hasRemoteAvatar
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: hasRemoteAvatar ? null : const Icon(Icons.person_rounded),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname == null || nickname.isEmpty ? '微信用户' : nickname,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    'OLib #${session.olibUserId} · ${session.profile.role}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('退出'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                session.appUserId,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: '复制 Achievements 用户 ID',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: session.appUserId));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已复制到剪贴板'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// About
// ─────────────────────────────────────────────────────────────────────

class _AboutSection extends ConsumerStatefulWidget {
  const _AboutSection();

  @override
  ConsumerState<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<_AboutSection> {
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded),
        title: Text('发现新版本 v${info.version}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('前往下载页面获取最新版:'),
            const SizedBox(height: Spacing.sm),
            SelectableText(info.url, style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: info.url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('下载链接已复制')));
            },
            child: const Text('复制链接'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('版本'),
          subtitle: Text('by $kAuthor'),
          trailing: Text(
            'v$kAppVersion',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          leading: _checking
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update_rounded),
          title: const Text('检查更新'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _checking ? null : _checkUpdate,
        ),
        _LinkTile(icon: Icons.code_rounded, label: 'GitHub', url: kGithubUrl),
        _LinkTile(
          icon: Icons.smart_display_outlined,
          label: '哔哩哔哩',
          url: kBilibiliUrl,
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('开源许可'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showLicensePage(context: context),
        ),
      ],
    );
  }
}

/// 一行可复制的链接(点击复制到剪贴板)。桌面无统一打开浏览器依赖,这里用复制方案。
class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: const Icon(Icons.copy_rounded, size: 18),
      onTap: () {
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label 链接已复制')));
      },
    );
  }
}
