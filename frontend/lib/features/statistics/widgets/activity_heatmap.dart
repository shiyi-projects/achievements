import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// GitHub-style contribution heatmap for the last [days] days.
///
/// 采用多层绿色渐变色阶，紧凑布局，带月份标签和图例。
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
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final maxCount = data.values.fold(0, (m, v) => v > m ? v : m);

    // Color palette (GitHub-style greens)
    final emptyColor = isLight
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.3);

    final levelColors = isLight
        ? const [
            Color(0xFFD4EDDA),
            Color(0xFF82D89E),
            Color(0xFF40C463),
            Color(0xFF30A14E),
            Color(0xFF216E39),
          ]
        : const [
            Color(0xFF0E4429),
            Color(0xFF006D32),
            Color(0xFF26A641),
            Color(0xFF39D353),
            Color(0xFF5AE67E),
          ];

    // Build cells
    final cells = List.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return _Cell(date: d, count: data[key] ?? 0);
    });

    // Padding so first cell starts on Monday
    final firstDay = today.subtract(Duration(days: days - 1));
    final paddingBefore = (firstDay.weekday - 1) % 7;
    final totalCells = paddingBefore + cells.length;
    final weeks = (totalCells / 7).ceil();

    // Month labels
    final monthLabels = <int, String>{};
    for (var w = 0; w < weeks; w++) {
      final idx = w * 7 - paddingBefore;
      if (idx >= 0 && idx < cells.length) {
        final d = cells[idx].date;
        if (d.day <= 7) {
          monthLabels[w] = _monthName(d.month);
        }
      }
    }

    const cellSize = 10.0;
    const cellGap = 2.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels row
        SizedBox(
          height: 14,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var w = 0; w < weeks; w++)
                  SizedBox(
                    width: cellSize + cellGap,
                    child: monthLabels.containsKey(w)
                        ? Text(
                            monthLabels[w]!,
                            style: TextStyle(
                              fontSize: 9,
                              color: scheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),

        // Heatmap grid
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var w = 0; w < weeks; w++)
                Padding(
                  padding: const EdgeInsets.only(right: cellGap),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var d = 0; d < 7; d++)
                        () {
                          final idx = w * 7 + d - paddingBefore;
                          if (idx < 0 || idx >= cells.length) {
                            return SizedBox(
                              width: cellSize,
                              height: cellSize + cellGap,
                            );
                          }
                          final cell = cells[idx];
                          final color = cell.count == 0
                              ? emptyColor
                              : _levelColor(
                                  cell.count, maxCount, levelColors);
                          return Tooltip(
                            message:
                                '${_formatDate(cell.date)}: ${cell.count} 个任务',
                            child: Container(
                              width: cellSize,
                              height: cellSize,
                              margin: const EdgeInsets.only(bottom: cellGap),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
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
                      delay: Duration(
                        milliseconds: (w * 6).clamp(0, 250),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '少',
              style: TextStyle(fontSize: 9, color: scheme.outline),
            ),
            const SizedBox(width: 4),
            _LegendCell(color: emptyColor),
            for (final c in levelColors) _LegendCell(color: c),
            const SizedBox(width: 4),
            Text(
              '多',
              style: TextStyle(fontSize: 9, color: scheme.outline),
            ),
          ],
        ),
      ],
    );
  }

  Color _levelColor(int count, int maxCount, List<Color> colors) {
    if (maxCount == 0 || count == 0) return colors.first;
    final ratio = count / maxCount;
    final idx = (ratio * (colors.length - 1)).round().clamp(0, colors.length - 1);
    return colors[idx];
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _monthName(int month) {
    return switch (month) {
      1 => '1月',
      2 => '2月',
      3 => '3月',
      4 => '4月',
      5 => '5月',
      6 => '6月',
      7 => '7月',
      8 => '8月',
      9 => '9月',
      10 => '10月',
      11 => '11月',
      12 => '12月',
      _ => '',
    };
  }
}

class _LegendCell extends StatelessWidget {
  const _LegendCell({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _Cell {
  const _Cell({required this.date, required this.count});
  final DateTime date;
  final int count;
}
