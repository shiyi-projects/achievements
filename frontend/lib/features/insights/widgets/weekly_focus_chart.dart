import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 7 天迷你专注柱状图。当天柱子高亮，其余半透明。
class WeeklyFocusChart extends StatelessWidget {
  const WeeklyFocusChart({required this.data, super.key});

  /// Full focus data (potentially 30 days). We take the last 7 entries.
  final List<({String date, int sessions, int minutes})> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Take last 7 days — fill with zeros if data is sparse.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekData = <_DayData>[];

    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final entry = data.where((e) => e.date == key).firstOrNull;
      weekData.add(
        _DayData(date: d, minutes: entry?.minutes ?? 0, isToday: i == 0),
      );
    }

    final maxMinutes = weekData
        .map((e) => e.minutes)
        .fold(0, (a, b) => a > b ? a : b);
    final displayMax = (maxMinutes * 1.3).clamp(10.0, double.infinity);

    if (maxMinutes == 0) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            '本周暂无专注记录',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ),
      );
    }

    return SizedBox(
          height: 100,
          child: BarChart(
            BarChartData(
              maxY: displayMax,
              barGroups: [
                for (var i = 0; i < weekData.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: weekData[i].minutes.toDouble(),
                        color: weekData[i].isToday
                            ? scheme.primary
                            : scheme.primary.withValues(alpha: 0.35),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= weekData.length) {
                        return const SizedBox();
                      }
                      final label = _weekdayLabel(weekData[idx].date.weekday);
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: weekData[idx].isToday
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: weekData[idx].isToday
                              ? scheme.primary
                              : scheme.outline,
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    '${rod.toY.toInt()} 分钟',
                    TextStyle(color: scheme.onInverseSurface, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: MotionDurations.normal)
        .slideY(
          begin: 0.05,
          duration: MotionDurations.normal,
          curve: MotionCurves.emphasizedDecelerate,
        );
  }

  static String _weekdayLabel(int weekday) {
    return switch (weekday) {
      1 => '一',
      2 => '二',
      3 => '三',
      4 => '四',
      5 => '五',
      6 => '六',
      7 => '日',
      _ => '',
    };
  }
}

class _DayData {
  const _DayData({
    required this.date,
    required this.minutes,
    required this.isToday,
  });
  final DateTime date;
  final int minutes;
  final bool isToday;
}
