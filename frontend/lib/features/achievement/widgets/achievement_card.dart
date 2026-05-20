import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/features/achievement/models/achievement_def.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 成就卡片 — 已解锁带金色 shimmer，未解锁灰度 + 锁图标晃动。
class AchievementCard extends StatefulWidget {
  const AchievementCard({
    required this.def,
    required this.unlocked,
    this.animateIn = false,
    super.key,
  });

  final AchievementDef def;
  final bool unlocked;
  final bool animateIn;

  @override
  State<AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;

    Widget card = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: MotionDurations.fast,
        curve: MotionCurves.gentleSpring,
        transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
        child: Card(
          elevation: _hovering ? 2 : 0,
          color: widget.unlocked
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(widget.def.icon, style: const TextStyle(fontSize: 24)),
                    const Spacer(),
                    if (!widget.unlocked)
                      AppIcons.svgIcon(AppIcons.lock, size: 14)
                          .animate(
                            onPlay: (ctrl) => ctrl.repeat(reverse: true),
                          )
                          .rotate(
                            begin: -0.02,
                            end: 0.02,
                            duration: 1500.ms,
                            curve: Curves.easeInOut,
                          ),
                  ],
                ),
                const Spacer(),
                Text(
                  widget.def.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: widget.unlocked
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.def.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.unlocked
                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.75)
                        : colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 已解锁 shimmer 效果
    if (widget.unlocked) {
      card = card.animate(
        onPlay: (ctrl) => ctrl.repeat(),
      ).shimmer(
        delay: 3000.ms,
        duration: 1500.ms,
        color: (isLight
            ? Colors.amber.shade200
            : Colors.amber.shade700
        ).withValues(alpha: 0.3),
      );
    }

    if (!widget.animateIn) return card;
    return card
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          duration: MotionDurations.bouncy,
          curve: MotionCurves.bouncySpring,
        )
        .fadeIn(duration: MotionDurations.normal);
  }
}
