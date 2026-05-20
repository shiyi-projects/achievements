import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 通用空状态组件。
///
/// 居中布局,64dp 淡色图标(带浮动动画) + titleMedium 主文案 + bodySmall 副文案。
/// 可选操作按钮(ui_design_spec §7.6)。
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final Widget icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon with floating animation ──
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 36, height: 36, child: icon),
              )
                  .animate(
                    onPlay: (ctrl) => ctrl.repeat(reverse: true),
                  )
                  .moveY(
                    begin: 0,
                    end: -6,
                    duration: 2000.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: Spacing.base),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: MotionDurations.normal, delay: 200.ms),
              if (subtitle != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: MotionDurations.normal, delay: 350.ms),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Spacing.base),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                )
                    .animate()
                    .fadeIn(duration: MotionDurations.normal, delay: 500.ms)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      duration: MotionDurations.normal,
                      delay: 500.ms,
                      curve: MotionCurves.bouncySpring,
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
