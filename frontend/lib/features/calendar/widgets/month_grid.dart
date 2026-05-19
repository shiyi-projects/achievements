import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/features/calendar/providers/calendar_providers.dart';
import 'package:achievements/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 月历网格。
///
/// 使用 Column + Row 手动布局（避免 GridView.shrinkWrap 的溢出问题），
/// 每行固定高度。支持水平滑动切换月份。
class MonthGrid extends ConsumerWidget {
  const MonthGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(focusedMonthProvider);
    final selected = ref.watch(selectedDayProvider);
    final byDay = ref.watch(tasksByDayProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

    // 当月第一天是周几 (1=Mon … 7=Sun)
    final firstWeekday = DateTime(month.year, month.month).weekday;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    // Build flat list of day numbers; 0 = empty placeholder
    final flat = <int>[
      for (var i = 1; i < firstWeekday; i++) 0,
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    // Pad to full weeks
    while (flat.length % 7 != 0) {
      flat.add(0);
    }

    // Split into weeks
    final weeks = <List<int>>[];
    for (var i = 0; i < flat.length; i += 7) {
      weeks.add(flat.sublist(i, i + 7));
    }

    const double rowH = 40;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -200) {
          // Swipe left → next month
          ref.read(focusedMonthProvider.notifier).state =
              DateTime(month.year, month.month + 1);
        } else if (details.primaryVelocity! > 200) {
          // Swipe right → previous month
          ref.read(focusedMonthProvider.notifier).state =
              DateTime(month.year, month.month - 1);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Weekday header row
            SizedBox(
              height: 22,
              child: Row(
                children: [
                  for (int i = 0; i < weekLabels.length; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          weekLabels[i],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: i >= 5
                                ? scheme.tertiary.withValues(alpha: 0.7)
                                : scheme.outline,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Day rows
            for (final week in weeks)
              SizedBox(
                height: rowH,
                child: Row(
                  children: [
                    for (final d in week)
                      Expanded(
                        child: d == 0
                            ? const SizedBox.shrink()
                            : DayCell(
                                day: d,
                                isSelected: selected != null &&
                                    selected.year == month.year &&
                                    selected.month == month.month &&
                                    selected.day == d,
                                isToday: _isToday(month, d),
                                tasks: byDay[d] ?? const <Task>[],
                                onTap: () {
                                  ref
                                      .read(selectedDayProvider.notifier)
                                      .state =
                                      DateTime(month.year, month.month, d);
                                },
                              ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static bool _isToday(DateTime month, int day) {
    final now = DateTime.now();
    return now.year == month.year &&
        now.month == month.month &&
        now.day == day;
  }
}
