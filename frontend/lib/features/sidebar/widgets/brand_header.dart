import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Brand Header
// ─────────────────────────────────────────────────────────────────────

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xl,
        Spacing.base,
        Spacing.base,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              'Achievements',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SyncStatusIndicator(),
        ],
      ),
    );
  }
}

/// 同步状态指示器。watch [SyncStatusController],按状态切 icon + tooltip。
/// syncing 状态下做一个简单的旋转动画;idle 态下显示极淡的 cloud_done 让用户
/// 知道"已同步";error / offline 用 colorScheme.error / outline 着色。
class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusControllerProvider);
    final theme = Theme.of(context);
    if (status == SyncStatus.syncing) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      if (_spin.isAnimating) _spin.stop();
    }

    final (icon, color, tooltip) = switch (status) {
      SyncStatus.idle => (
        Icons.cloud_done_rounded,
        theme.colorScheme.outline.withValues(alpha: 0.6),
        '已同步',
      ),
      SyncStatus.syncing => (
        Icons.sync_rounded,
        theme.colorScheme.primary,
        '同步中…',
      ),
      SyncStatus.error => (
        Icons.sync_problem_rounded,
        theme.colorScheme.error,
        '同步失败',
      ),
      SyncStatus.offline => (
        Icons.cloud_off_rounded,
        theme.colorScheme.outline,
        '离线,暂存本地',
      ),
    };

    final iconWidget = Icon(icon, size: 18, color: color);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: status == SyncStatus.syncing
              ? RotationTransition(turns: _spin, child: iconWidget)
              : iconWidget,
        ),
      ),
    );
  }
}
