import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/state/current_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Calendar Nav Tile
// ─────────────────────────────────────────────────────────────────────

class CalendarNavTile extends ConsumerWidget {
  const CalendarNavTile({required this.selected, super.key});
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            ref.read(currentViewNotifierProvider.notifier).showCalendar();
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
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.md),
                Text(
                  '日历',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
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
