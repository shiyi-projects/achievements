import 'package:achievements/features/achievement/models/achievement_def.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 已解锁成就列表 — 圆形 SVG 图标 + 名称描述 + 「已解锁」徽章。
class UnlockedAchievementList extends StatelessWidget {
  const UnlockedAchievementList({
    required this.unlocked,
    required this.total,
    super.key,
  });

  final List<AchievementDef> unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    '已获得成就',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${unlocked.length} / $total',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (unlocked.isEmpty)
                _EmptyState()
              else
                Column(
                  children: [
                    for (var i = 0; i < unlocked.length; i++) ...[
                      _AchievementTile(def: unlocked[i], index: i),
                      if (i < unlocked.length - 1)
                        Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.15),
                        ),
                    ],
                  ],
                ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: MotionDurations.normal)
        .slideY(
          begin: 0.04,
          duration: MotionDurations.normal,
          curve: MotionCurves.emphasizedDecelerate,
        );
  }
}

class _AchievementTile extends StatefulWidget {
  const _AchievementTile({required this.def, required this.index});

  final AchievementDef def;
  final int index;

  @override
  State<_AchievementTile> createState() => _AchievementTileState();
}

class _AchievementTileState extends State<_AchievementTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: MotionDurations.fast,
            color: _hovering
                ? scheme.primary.withValues(alpha: 0.04)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                // SVG icon in circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF0F4FF)
                        : scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.def.hasSvg
                      ? SvgPicture.asset(
                          widget.def.svgAsset,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            widget.def.icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Name + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.def.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.def.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFF1B5E20).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '已解锁',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isLight
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF81C784),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(
          duration: MotionDurations.normal,
          delay: Duration(milliseconds: 60 * widget.index),
        )
        .slideX(
          begin: 0.03,
          duration: MotionDurations.normal,
          delay: Duration(milliseconds: 60 * widget.index),
          curve: MotionCurves.emphasizedDecelerate,
        );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              '完成任务来解锁成就吧',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
