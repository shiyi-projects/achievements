import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TrendsLineChart extends StatelessWidget {
  const TrendsLineChart({required this.data, super.key});

  final List<({String date, int completed, int created})> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('暂无数据')),
      );
    }

    final maxY = data
        .map((e) => e.completed > e.created ? e.completed : e.created)
        .fold(0, (m, v) => v > m ? v : m);
    final displayMax = (maxY * 1.25).clamp(4.0, double.infinity);

    LineChartBarData makeLine(List<FlSpot> spots, Color color) => LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(color: color.withValues(alpha: 0.08)),
    );

    final completedSpots = [
      for (var i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), data[i].completed.toDouble()),
    ];
    final createdSpots = [
      for (var i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), data[i].created.toDouble()),
    ];

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          maxY: displayMax,
          minY: 0,
          lineBarsData: [
            makeLine(completedSpots, theme.colorScheme.primary),
            makeLine(createdSpots, theme.colorScheme.secondary),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
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
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    s.barIndex == 0
                        ? '完成: ${s.y.toInt()}'
                        : '新建: ${s.y.toInt()}',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontSize: 11,
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
