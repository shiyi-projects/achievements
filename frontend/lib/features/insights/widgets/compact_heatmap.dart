import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 紧凑版 12 周热力图 + 「本周最活跃」统计。
///
/// 使用 LayoutBuilder 让格子自适应填满容器宽度。
class CompactHeatmap extends StatelessWidget {
  const CompactHeatmap({required this.data, super.key});

  /// Map from ISO date string ('2025-01-15') to task completion count.
  final Map<String, int> data;

  static const int _weeks = 12;
  static const int _days = _weeks * 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final maxCount = data.values.fold(0, (m, v) => v > m ? v : m);

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
    final cells = List.generate(_days, (i) {
      final d = today.subtract(Duration(days: _days - 1 - i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return _Cell(date: d, count: data[key] ?? 0);
    });

    // Padding for Monday start
    final firstDay = today.subtract(const Duration(days: _days - 1));
    final paddingBefore = (firstDay.weekday - 1) % 7;
    final totalCells = paddingBefore + cells.length;
    final weekCount = (totalCells / 7).ceil();

    // Most active day this week
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    var bestDay = '';
    var bestCount = 0;
    for (var i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final c = data[key] ?? 0;
      if (c > bestCount) {
        bestCount = c;
        bestDay = _weekdayName(d.weekday);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                '活跃记录',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '过去 12 周',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
              const Spacer(),
              // Most active day (inline in header)
              if (bestCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '本周最活跃  ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      bestDay,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '  完成 $bestCount 项',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Heatmap — auto-sized cells via LayoutBuilder
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              // gap between cells
              const gap = 3.0;
              // Calculate cell size to fill the width exactly
              final cellSize =
                  (availableWidth - (weekCount - 1) * gap) / weekCount;
              // Clamp to reasonable range
              final size = cellSize.clamp(6.0, 16.0);
              final actualGap = weekCount > 1
                  ? (availableWidth - size * weekCount) / (weekCount - 1)
                  : 0.0;

              return SizedBox(
                height: size * 7 + actualGap * 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var w = 0; w < weekCount; w++)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var d = 0; d < 7; d++)
                            () {
                              final idx = w * 7 + d - paddingBefore;
                              if (idx < 0 || idx >= cells.length) {
                                return SizedBox(
                                  width: size,
                                  height: size +
                                      (d < 6 ? actualGap.clamp(1.0, 4.0) : 0),
                                );
                              }
                              final cell = cells[idx];
                              final color = cell.count == 0
                                  ? emptyColor
                                  : _levelColor(
                                      cell.count, maxCount, levelColors);
                              return Tooltip(
                                message:
                                    '${_fmtDate(cell.date)}: ${cell.count} 个任务',
                                child: Container(
                                  width: size,
                                  height: size,
                                  margin: EdgeInsets.only(
                                    bottom:
                                        d < 6 ? actualGap.clamp(1.0, 4.0) : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius:
                                        BorderRadius.circular(size * 0.2),
                                  ),
                                ),
                              );
                            }(),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: MotionDurations.normal)
        .slideY(
          begin: 0.04,
          duration: MotionDurations.normal,
          curve: MotionCurves.emphasizedDecelerate,
        );
  }

  Color _levelColor(int count, int maxCount, List<Color> colors) {
    if (maxCount == 0 || count == 0) return colors.first;
    final ratio = count / maxCount;
    final idx =
        (ratio * (colors.length - 1)).round().clamp(0, colors.length - 1);
    return colors[idx];
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _weekdayName(int wd) => switch (wd) {
        1 => '周一',
        2 => '周二',
        3 => '周三',
        4 => '周四',
        5 => '周五',
        6 => '周六',
        7 => '周日',
        _ => '',
      };
}

class _Cell {
  const _Cell({required this.date, required this.count});
  final DateTime date;
  final int count;
}
