import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FocusBarChart extends StatelessWidget {
  const FocusBarChart({required this.data, super.key});

  final List<({String date, int sessions, int minutes})> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('暂无专注数据')),
      );
    }

    final maxY = data.map((e) => e.minutes).fold(0, (m, v) => v > m ? v : m);
    final displayMax = (maxY * 1.25).clamp(10.0, double.infinity);

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          maxY: displayMax,
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].minutes.toDouble(),
                    color: theme.colorScheme.primary,
                    width: data.length > 20 ? 4 : 8,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}m',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: (data.length / 5).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final parts = data[idx].date.split('-');
                  return Text(
                    '${parts[1]}/${parts[2]}',
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.outline,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
          ),
          gridData: FlGridData(
            getDrawingHorizontalLine: (v) =>
                FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 0.5),
            getDrawingVerticalLine: (_) => const FlLine(color: Colors.transparent),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${rod.toY.toInt()} 分钟\n${data[group.x].date}',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
