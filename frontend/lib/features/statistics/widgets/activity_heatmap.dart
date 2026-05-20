import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// GitHub-style contribution heatmap for the last [days] days.
///
/// 美化: 列从左到右交错淡入,带微弱的缩放效果。
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    required this.data,
    this.days = 365,
    super.key,
  });

  /// Map from ISO date string ('2025-01-15') to task completion count.
  final Map<String, int> data;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Determine max count for color scaling
    final maxCount = data.values.fold(0, (m, v) => v > m ? v : m);

    // Build list of cells from oldest to newest
    final cells = List.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final count = data[key] ?? 0;
      return _Cell(date: d, count: count, maxCount: maxCount);
    });

    // Pad so first cell starts on Monday (weekday 1)
    final firstDay = today.subtract(Duration(days: days - 1));
    final paddingBefore = (firstDay.weekday - 1) % 7;

    final totalCells = paddingBefore + cells.length;
    final weeks = (totalCells / 7).ceil();

    final baseColor = theme.colorScheme.primary;
    final isLight = theme.colorScheme.brightness == Brightness.light;
    final emptyColor = isLight
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var w = 0; w < weeks; w++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var d = 0; d < 7; d++)
                    () {
                      final idx = w * 7 + d - paddingBefore;
                      if (idx < 0 || idx >= cells.length) {
                        return const SizedBox(width: 11, height: 11 + 3);
                      }
                      final cell = cells[idx];
                      final opacity = maxCount == 0
                          ? 0.0
                          : (cell.count / maxCount).clamp(0.1, 1.0);
                      final filled = cell.count > 0;
                      return Tooltip(
                        message: '${_formatDate(cell.date)}: ${cell.count} 个任务',
                        child: Container(
                          width: 11,
                          height: 11,
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(
                            color: filled
                                ? baseColor.withValues(alpha: opacity)
                                : emptyColor,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      );
                    }(),
                ],
              ),
            )
                .animate()
                .fadeIn(
                  duration: MotionDurations.fast,
                  delay: Duration(milliseconds: (w * 8).clamp(0, 300)),
                )
                .scaleY(
                  begin: 0.8,
                  duration: MotionDurations.fast,
                  delay: Duration(milliseconds: (w * 8).clamp(0, 300)),
                  curve: MotionCurves.emphasizedDecelerate,
                ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Cell {
  const _Cell({required this.date, required this.count, required this.maxCount});
  final DateTime date;
  final int count;
  final int maxCount;
}
