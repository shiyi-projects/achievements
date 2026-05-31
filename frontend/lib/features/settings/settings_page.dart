import 'dart:async';

import 'package:achievements/core/sync/sync_coordinator.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
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
              icon: AppIcons.svgIcon(AppIcons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          children: [
            const _SectionHeader('外观'),
            _ThemeModeSection(current: settings.themeMode),
            const SizedBox(height: Spacing.sm),
            _ColorSection(current: settings.seedColor),
            if (defaultTargetPlatform == TargetPlatform.windows) ...[
              const Divider(height: Spacing.xl),
              const _SectionHeader('桌面'),
              _CloseActionSection(current: settings.closeAction),
            ],
            const Divider(height: Spacing.xl),
            const _SectionHeader('同步'),
            const _SyncSection(),
            const Divider(height: Spacing.xl),
            const _SectionHeader('关于'),
            const _AboutSection(),
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
        Spacing.lg,
        Spacing.base,
        Spacing.lg,
        Spacing.xs,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
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
      ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
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
                        ? AppIcons.svgIcon(AppIcons.check, size: 20)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
    final theme = Theme.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
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
      ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
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

          const SizedBox(height: Spacing.md),
          const Divider(height: 1),
          const SizedBox(height: Spacing.sm),

          const _AccountSection(),
        ],
      ),
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

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          leading: AppIcons.svgIcon(AppIcons.info),
          title: const Text('版本'),
          trailing: Text(
            '0.0.1',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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
