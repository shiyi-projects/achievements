import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────────────────────────────
// Brand Header — 带入场动画和 shimmer Logo
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
          // ── Logo with shimmer ──
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SvgPicture.asset(
              AppIcons.appIcon,
              width: 36,
              height: 36,
            ),
          )
              .animate(onPlay: (ctrl) => ctrl.stop())
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                duration: MotionDurations.bouncy,
                curve: MotionCurves.bouncySpring,
              )
              .rotate(
                begin: -0.1,
                end: 0,
                duration: MotionDurations.bouncy,
                curve: MotionCurves.bouncySpring,
              )
              .shimmer(
                delay: 800.ms,
                duration: 1200.ms,
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.3),
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

    final (iconPath, color, tooltip) = switch (status) {
      SyncStatus.idle => (
        AppIcons.cloudSync,
        theme.colorScheme.outline.withValues(alpha: 0.6),
        '已同步',
      ),
      SyncStatus.syncing => (
        AppIcons.sync,
        theme.colorScheme.primary,
        '同步中…',
      ),
      SyncStatus.error => (
        AppIcons.cloudError,
        theme.colorScheme.error,
        '同步失败',
      ),
      SyncStatus.offline => (
        AppIcons.cloudOff,
        theme.colorScheme.outline,
        '离线，暂存本地',
      ),
    };

    final iconWidget = SvgPicture.asset(
      iconPath,
      width: 18,
      height: 18,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
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
