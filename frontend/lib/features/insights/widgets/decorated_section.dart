import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 美化版段落标题 — 左侧 4px 圆角装饰色条 + 标题文字。
class DecoratedSection extends StatelessWidget {
  const DecoratedSection({
    required this.title,
    required this.child,
    this.accentColor,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;

  /// Accent bar color. Falls back to primary.
  final Color? accentColor;

  /// Optional trailing widget (e.g. a "查看更多" button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    )
        .animate()
        .fadeIn(duration: MotionDurations.normal)
        .slideY(
          begin: 0.03,
          duration: MotionDurations.normal,
          curve: MotionCurves.emphasizedDecelerate,
        );
  }
}
