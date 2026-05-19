import 'package:achievements/features/achievement/models/achievement_def.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AchievementCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final card = Card(
      color: unlocked
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(def.icon, style: const TextStyle(fontSize: 24)),
                const Spacer(),
                if (!unlocked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: colorScheme.outline,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              def.name,
              style: theme.textTheme.titleSmall?.copyWith(
                color: unlocked
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              def.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: unlocked
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.75)
                    : colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );

    if (!animateIn) return card;
    return card
        .animate()
        .scale(
          begin: const Offset(0.8, 0.8),
          duration: 400.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 250.ms);
  }
}
