import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 通用顶部导航条目(日历 / 专注 / 搜索)。对应 AppView 切换,而不是清单切换。
class ViewNavTile extends StatelessWidget {
  const ViewNavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 1),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.input),
          onTap: () {
            onTap();
            final scaffold = Scaffold.maybeOf(context);
            if ((scaffold?.hasDrawer ?? false) && scaffold!.isDrawerOpen) {
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.md),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
