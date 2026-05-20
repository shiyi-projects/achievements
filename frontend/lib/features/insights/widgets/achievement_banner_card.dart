import 'package:achievements/features/achievement/models/achievement_def.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 成就卡片 — 左侧 SVG 图标 + 右侧名称描述。
///
/// 所有 SVG 均为 220×220 方形图标风格，卡片以图标 + 文字横排展示。
class AchievementBannerCard extends StatefulWidget {
  const AchievementBannerCard({
    required this.def,
    required this.index,
    super.key,
  });

  final AchievementDef def;

  /// Index for staggered animation.
  final int index;

  @override
  State<AchievementBannerCard> createState() => _AchievementBannerCardState();
}

class _AchievementBannerCardState extends State<AchievementBannerCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    Widget card = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: MotionDurations.fast,
        curve: MotionCurves.gentleSpring,
        transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
        child: Card(
          elevation: _hovering ? 2 : 0,
          color: isLight
              ? scheme.primaryContainer
              : scheme.primaryContainer.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ── SVG icon ──
                if (widget.def.hasSvg)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SvgPicture.asset(
                      widget.def.svgAsset,
                      width: 72,
                      height: 72,
                    ),
                  )
                else
                  // Fallback: emoji circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.def.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                const SizedBox(width: 14),

                // ── Text info ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.def.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.def.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Unlocked badge ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '已解锁',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Shimmer effect
    card = card
        .animate(onPlay: (ctrl) => ctrl.repeat())
        .shimmer(
          delay: Duration(milliseconds: 3000 + widget.index * 500),
          duration: 1500.ms,
          color: (isLight ? Colors.amber.shade200 : Colors.amber.shade700)
              .withValues(alpha: 0.25),
        );

    // Staggered entrance
    return card
        .animate()
        .fadeIn(
          duration: MotionDurations.normal,
          delay: Duration(milliseconds: 80 * widget.index),
        )
        .slideY(
          begin: 0.06,
          duration: MotionDurations.normal,
          delay: Duration(milliseconds: 80 * widget.index),
          curve: MotionCurves.emphasizedDecelerate,
        );
  }
}
