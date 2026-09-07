import 'dart:async';

import 'package:achievements/core/sync/sync_coordinator.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:achievements/features/settings/widgets/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 同步状态。状态用一个小圆点表达(而不是彩色图标),文字保持中性,
/// 只有异常态才染成错误色。
class SyncStatusRow extends ConsumerWidget {
  const SyncStatusRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(syncStatusControllerProvider);
    final lastSyncAt = ref.watch(lastSyncAtProvider).valueOrNull;

    final (dot, text, isError) = switch (status) {
      SyncStatus.idle => (scheme.primary, '已同步', false),
      SyncStatus.syncing => (scheme.primary, '同步中…', false),
      SyncStatus.error => (scheme.error, '同步失败', true),
      SyncStatus.offline => (scheme.outline, '离线', false),
      SyncStatus.upgradeRequired => (scheme.error, '版本过旧,升级后才能同步', true),
    };

    return SettingsRow(
      title: text,
      titleColor: isError ? scheme.error : null,
      leadingDot: dot,
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

class SyncActionRow extends ConsumerWidget {
  const SyncActionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing =
        ref.watch(syncStatusControllerProvider) == SyncStatus.syncing;

    final scheme = Theme.of(context).colorScheme;
    // 整行即操作:极简列表里不再为一个动作单独摆一颗按钮,标题用品牌色表明
    // 它是可点的主操作。
    return SettingsRow(
      title: isSyncing ? '同步中…' : '立即同步',
      subtitle: '把本地改动推送到云端并拉取最新数据',
      titleColor: isSyncing ? null : scheme.primary,
      trailing: isSyncing ? const SettingsSpinner() : null,
      onTap: isSyncing
          ? null
          : () => unawaited(ref.read(syncCoordinatorProvider).runFullSync()),
    );
  }
}

/// 推不上去的本地改动(重试预算耗尽)。给用户一个看得见、能处置的出口——
/// 否则这些改动只会静默留在本地,用户永远不知道它们没上云。
class SyncFailuresRow extends ConsumerWidget {
  const SyncFailuresRow({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsRow(
      title: '$count 条本地改动没能同步',
      titleColor: scheme.error,
      leadingDot: scheme.error,
      trailing: SettingsMiniButton(
        label: '查看',
        onPressed: () => unawaited(
          showDialog<void>(
            context: context,
            builder: (_) => const _SyncFailuresDialog(),
          ),
        ),
      ),
    );
  }
}

class _SyncFailuresDialog extends ConsumerWidget {
  const _SyncFailuresDialog();

  static const _entityLabels = {
    'list': '清单',
    'task': '任务',
    'tag': '标签',
    'task_tag': '标签关联',
  };

  static const _opLabels = {'upsert': '新建/修改', 'delete': '删除', 'purge': '永久删除'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = ref.watch(syncFailureListProvider).valueOrNull ?? const [];

    return Dialog(
      backgroundColor: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.panel),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
                Spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '没能同步的改动',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    '这些改动重试多次仍被服务端拒绝,已停止自动重试。'
                    '重试会重新排队发送;丢弃后本地这几行会在下次同步时被云端的值覆盖。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.5,
                      color: scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SettingsHairline(),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SettingsHairline(inset: true),
                itemBuilder: (_, i) {
                  final row = rows[i];
                  final entity = _entityLabels[row.entity] ?? row.entity;
                  final op = _opLabels[row.op] ?? row.op;
                  return SettingsRow(
                    title: '$entity · $op',
                    subtitle: row.lastError ?? '未知原因',
                  );
                },
              ),
            ),
            const SettingsHairline(),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SettingsMiniButton(
                    label: '全部丢弃',
                    danger: true,
                    onPressed: () async {
                      await ref
                          .read(outboxRepositoryProvider)
                          .discardDeadLettered();
                      ref.invalidate(syncFailureListProvider);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: Spacing.sm),
                  SettingsMiniButton(
                    label: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: Spacing.sm),
                  SettingsMiniButton(
                    label: '全部重试',
                    accent: true,
                    onPressed: () async {
                      await ref
                          .read(outboxRepositoryProvider)
                          .retryDeadLettered();
                      ref.invalidate(syncFailureListProvider);
                      if (context.mounted) Navigator.of(context).pop();
                      unawaited(
                        ref.read(syncCoordinatorProvider).runFullSync(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 账户块:头像 + 昵称 + 退出,下面挂一行可复制的用户 ID。
class AccountBlock extends ConsumerWidget {
  const AccountBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final session = switch (auth) {
      AuthAuthenticated(:final session) => session,
      _ => null,
    };
    if (session == null) return const SettingsRow(title: '未登录');

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
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSettingsHPad,
            vertical: Spacing.md,
          ),
          child: Row(
            children: [
              // 方形圆角头像,与色卡、分段控件共用同一套小圆角语言。
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.control),
                child: Container(
                  width: 34,
                  height: 34,
                  color: scheme.surfaceContainerHigh,
                  child: hasRemoteAvatar
                      ? Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: scheme.outline,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: scheme.outline,
                        ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname == null || nickname.isEmpty ? '微信用户' : nickname,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.profile.inWecom ? '微信登录 · 社群成员' : '微信登录',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              SettingsMiniButton(
                label: '退出登录',
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) Navigator.of(context).maybePop();
                },
              ),
            ],
          ),
        ),
        const SettingsHairline(inset: true),
        SettingsRow(
          title: session.appUserId,
          monospaceTitle: true,
          value: '复制',
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
