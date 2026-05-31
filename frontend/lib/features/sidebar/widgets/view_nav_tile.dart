import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// 通用顶部导航条目(日历 / 专注 / 统计 / 成就)。
/// 对应 AppView 切换,而不是清单切换。
///
/// 带动画选中指示条 + 悬停效果 + 图标缩放弹性。
class ViewNavTile extends StatefulWidget {
  const ViewNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<ViewNavTile> createState() => _ViewNavTileState();
}

class _ViewNavTileState extends State<ViewNavTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    final bgColor = widget.selected
        ? scheme.secondaryContainer
        : _hovering
        ? (isLight
              ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
              : scheme.surfaceContainerHigh.withValues(alpha: 0.3))
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: MotionDurations.fast,
          curve: MotionCurves.gentleSpring,
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(Radii.input),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.input),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.input),
              onTap: () {
                widget.onTap();
                final scaffold = Scaffold.maybeOf(context);
                if ((scaffold?.hasDrawer ?? false) && scaffold!.isDrawerOpen) {
                  Navigator.of(context).pop();
                }
              },
              child: Row(
                children: [
                  // ── 左侧指示条 ──
                  AnimatedContainer(
                    duration: MotionDurations.fast,
                    curve: MotionCurves.emphasizedDecelerate,
                    width: widget.selected ? 3 : 0,
                    height: 20,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        widget.selected ? Spacing.sm : Spacing.md,
                        Spacing.sm + 2,
                        Spacing.md,
                        Spacing.sm + 2,
                      ),
                      child: Row(
                        children: [
                          AnimatedScale(
                            scale: widget.selected ? 1.08 : 1.0,
                            duration: MotionDurations.fast,
                            curve: MotionCurves.bouncySpring,
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: widget.icon,
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Text(
                            widget.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: widget.selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: widget.selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
