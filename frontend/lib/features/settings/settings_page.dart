import 'dart:async';

import 'package:achievements/core/app_info.dart';
import 'package:achievements/core/sync/sync_coordinator.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/core/update/update_checker.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:achievements/features/settings/widgets/settings_group.dart';
import 'package:achievements/platform/android/keepalive_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
// Main Settings Page — iOS 风格分组列表
// ─────────────────────────────────────────────────────────────────────

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showCloseButton = false});

  final bool showCloseButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final syncFailureCount =
        ref.watch(syncFailureCountProvider).valueOrNull ?? 0;
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
            0,
            Spacing.lg,
            Spacing.xl,
          ),
          children: [
            SettingsGroup(
              title: '外观',
              children: [
                _ThemeModeSection(current: settings.themeMode),
                _ColorSection(current: settings.seedColor),
              ],
            ),
            if (defaultTargetPlatform == TargetPlatform.windows)
              SettingsGroup(
                title: '桌面',
                children: [_CloseActionSection(current: settings.closeAction)],
              ),
            if (defaultTargetPlatform == TargetPlatform.android)
              const SettingsGroup(
                title: '提醒与后台',
                footer: '提醒由系统闹钟驱动,App 被后台清理也能到点提醒;为保证准时,建议关闭电池优化并允许自启动。',
                children: [_KeepAliveSection()],
              ),
            SettingsGroup(
              title: '同步',
              children: [
                const _SyncStatusTile(),
                // 只在真有推不上去的改动时出现,避免平时占位。
                if (syncFailureCount > 0)
                  _SyncFailuresTile(count: syncFailureCount),
                const _SyncActionTile(),
                const _AccountSection(),
              ],
            ),
            const SettingsGroup(
              title: '关于',
              children: [
                _VersionTile(),
                _CheckUpdateTile(),
                _LinkTile(
                  asset: AppIcons.github,
                  tinted: true,
                  label: 'GitHub',
                  url: kGithubUrl,
                ),
                _LinkTile(
                  asset: AppIcons.bilibili,
                  label: '哔哩哔哩',
                  url: kBilibiliUrl,
                ),
                _LicenseTile(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 外观:主题模式
// ─────────────────────────────────────────────────────────────────────

class _ThemeModeSection extends ConsumerWidget {
  const _ThemeModeSection({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return SettingsBlock(
      label: '主题模式',
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ThemeMode>(
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 外观:主题色
// ─────────────────────────────────────────────────────────────────────

class _ColorSection extends ConsumerWidget {
  const _ColorSection({required this.current});

  final Color current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return SettingsBlock(
      label: '主题色',
      child: Wrap(
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
    final notifier = ref.read(settingsNotifierProvider.notifier);
    return SettingsBlock(
      label: '关闭按钮行为',
      description: '点击窗口右上角 X 时的默认动作',
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<CloseAction>(
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
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final service = ref.read(keepAliveServiceProvider);
    final detecting = _ignoring == null;
    final exempt = _ignoring ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 电池优化豁免 ──
        SettingsTile(
          leading: exempt
              ? Icons.battery_charging_full_rounded
              : Icons.battery_alert_rounded,
          leadingColor: exempt ? scheme.primary : scheme.error,
          title: '电池优化豁免',
          subtitle: detecting
              ? '检测中…'
              : exempt
              ? '已豁免,提醒不会被省电策略掐断'
              : '未豁免,后台可能延迟或拦截提醒',
          trailing: exempt
              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
              : FilledButton.tonal(
                  onPressed: () async {
                    await service.requestIgnoreBatteryOptimizations();
                    // 返回后由 didChangeAppLifecycleState 刷新状态。
                  },
                  child: const Text('允许'),
                ),
        ),
        const Divider(height: 1, indent: Spacing.base, endIndent: Spacing.base),
        // ── 厂商自启动 ──
        SettingsTile(
          leading: Icons.restart_alt_rounded,
          title: '自启动管理',
          subtitle: '在系统里允许本应用自启动(部分品牌需手动开启)',
          trailing: OutlinedButton(
            onPressed: () async {
              final ok = await service.openAutoStartSettings();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('未能打开系统设置,请手动前往「设置」开启自启动')),
                );
              }
            },
            child: const Text('前往'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 同步:状态 / 立即同步 / 账户
// ─────────────────────────────────────────────────────────────────────

class _SyncStatusTile extends ConsumerWidget {
  const _SyncStatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(syncStatusControllerProvider);
    final lastSyncAt = ref.watch(lastSyncAtProvider).valueOrNull;

    final (icon, color, text) = switch (status) {
      SyncStatus.idle => (Icons.cloud_done_rounded, scheme.primary, '已同步'),
      SyncStatus.syncing => (Icons.cloud_sync_rounded, scheme.primary, '同步中…'),
      SyncStatus.error => (Icons.error_outline_rounded, scheme.error, '同步失败'),
      SyncStatus.offline => (Icons.cloud_off_rounded, scheme.outline, '离线'),
      SyncStatus.upgradeRequired => (
        Icons.system_update_rounded,
        scheme.error,
        '版本过旧，升级后才能同步',
      ),
    };

    return SettingsTile(
      leading: icon,
      leadingColor: color,
      title: text,
      titleColor: color,
      value: _formatLastSync(lastSyncAt),
    );
  }

  /// 把时间格式化为"X 分钟前"。
  String _formatLastSync(DateTime? at) {
    if (at == null) return '从未同步';
    final diff = DateTime.now().difference(at);
    if (diff.isNegative || diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  }
}

class _SyncActionTile extends ConsumerWidget {
  const _SyncActionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isSyncing =
        ref.watch(syncStatusControllerProvider) == SyncStatus.syncing;

    return SettingsTile(
      leading: isSyncing ? null : Icons.sync_rounded,
      leadingColor: scheme.primary,
      title: isSyncing ? '同步中…' : '立即同步',
      titleColor: scheme.primary,
      trailing: isSyncing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: isSyncing
          ? null
          : () => unawaited(ref.read(syncCoordinatorProvider).runFullSync()),
    );
  }
}

/// 推不上去的本地改动(重试预算耗尽)。给用户一个看得见、能处置的出口——
/// 否则这些改动只会静默留在本地,用户永远不知道它们没上云。
class _SyncFailuresTile extends ConsumerWidget {
  const _SyncFailuresTile({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsTile(
      leading: Icons.sync_problem_rounded,
      leadingColor: scheme.error,
      title: '$count 条本地改动没能同步',
      titleColor: scheme.error,
      value: '查看',
      onTap: () => unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const _SyncFailuresDialog(),
        ),
      ),
    );
  }
}

class _SyncFailuresDialog extends ConsumerWidget {
  const _SyncFailuresDialog();

  static const _entityLabels = {
    'folder': '文件夹',
    'list': '清单',
    'task': '任务',
    'tag': '标签',
    'task_tag': '标签关联',
  };

  static const _opLabels = {'upsert': '新建/修改', 'delete': '删除', 'purge': '永久删除'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(syncFailureListProvider).valueOrNull ?? const [];

    return AlertDialog(
      title: const Text('没能同步的改动'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '这些改动重试多次仍被服务端拒绝,已停止自动重试。'
              '重试会重新排队发送;丢弃后本地这几行会在下次同步时被云端的值覆盖。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final row = rows[i];
                  final entity = _entityLabels[row.entity] ?? row.entity;
                  final op = _opLabels[row.op] ?? row.op;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('$entity · $op'),
                    subtitle: Text(
                      row.lastError ?? '未知原因',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ref.read(outboxRepositoryProvider).discardDeadLettered();
            ref.invalidate(syncFailureListProvider);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text('全部丢弃', style: TextStyle(color: theme.colorScheme.error)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: () async {
            await ref.read(outboxRepositoryProvider).retryDeadLettered();
            ref.invalidate(syncFailureListProvider);
            if (context.mounted) Navigator.of(context).pop();
            unawaited(ref.read(syncCoordinatorProvider).runFullSync());
          },
          child: const Text('全部重试'),
        ),
      ],
    );
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
    if (session == null) {
      return const SettingsTile(
        leading: Icons.person_off_rounded,
        title: '未登录',
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nickname = session.profile.nickname?.trim();
    final avatarUrl = session.profile.avatarUrl?.trim();
    final avatarUri = avatarUrl == null ? null : Uri.tryParse(avatarUrl);
    final hasRemoteAvatar =
        avatarUri != null && avatarUri.hasScheme && avatarUri.hasAuthority;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 账户头像 + 昵称 + 退出 ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.base,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: hasRemoteAvatar
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: hasRemoteAvatar
                    ? null
                    : const Icon(Icons.person_rounded),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname == null || nickname.isEmpty ? '微信用户' : nickname,
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      session.profile.inWecom ? '微信登录 · 社群成员' : '微信登录',
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
        ),
        const Divider(height: 1, indent: Spacing.base, endIndent: Spacing.base),
        // ── 用户 ID(可复制) ──
        SettingsTile(
          title: session.appUserId,
          trailing: const Icon(Icons.copy_rounded, size: 20),
          onTap: () async {
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 关于
// ─────────────────────────────────────────────────────────────────────

class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      leading: Icons.info_outline_rounded,
      title: '版本',
      subtitle: 'by $kAuthor',
      value: 'v$kAppVersion',
    );
  }
}

class _CheckUpdateTile extends ConsumerStatefulWidget {
  const _CheckUpdateTile();

  @override
  ConsumerState<_CheckUpdateTile> createState() => _CheckUpdateTileState();
}

class _CheckUpdateTileState extends ConsumerState<_CheckUpdateTile> {
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
    return SettingsTile(
      leading: _checking ? null : Icons.system_update_rounded,
      title: '检查更新',
      trailing: _checking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      showChevron: !_checking,
      onTap: _checking ? null : _checkUpdate,
    );
  }
}

/// 一行外链(点击调系统默认浏览器打开)。打开失败时回退到复制链接并提示。
///
/// [tinted] 为 true 时把单色 SVG 着成主题色(GitHub 纯黑标志在深色模式需跟随主题);
/// 否则保留品牌原色(如哔哩哔哩品牌蓝)。
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.asset,
    required this.label,
    required this.url,
    this.tinted = false,
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
    return SettingsTile(
      leadingWidget: AppIcons.svgIcon(
        asset,
        size: 20,
        color: tinted ? Theme.of(context).colorScheme.onSurfaceVariant : null,
      ),
      title: label,
      subtitle: url,
      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
      onTap: () => _open(context),
    );
  }
}

class _LicenseTile extends StatelessWidget {
  const _LicenseTile();

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      leading: Icons.description_outlined,
      title: '开源许可',
      showChevron: true,
      onTap: () => showLicensePage(context: context),
    );
  }
}
