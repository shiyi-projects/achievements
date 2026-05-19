import 'package:achievements/features/statistics/providers/stats_providers.dart';
import 'package:achievements/features/statistics/widgets/activity_heatmap.dart';
import 'package:achievements/features/statistics/widgets/focus_bar_chart.dart';
import 'package:achievements/features/statistics/widgets/overview_cards.dart';
import 'package:achievements/features/statistics/widgets/trends_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(statsOverviewProvider);
    final heatmap = ref.watch(statsHeatmapProvider);
    final focus = ref.watch(statsFocusProvider);
    final trends = ref.watch(statsTrendsProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Overview ──
        _Section(
          title: '总览',
          child: overview.when(
            loading: () => const _Loading(),
            error: (e, _) => _ErrorText(e),
            data: (d) => OverviewCards(
              totalCompleted: d.totalCompleted,
              todayCompleted: d.todayCompleted,
              streakDays: d.streakDays,
              totalFocusMinutes: d.totalFocusMinutes,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Activity Heatmap ──
        _Section(
          title: '任务热力图 (近一年)',
          child: heatmap.when(
            loading: () => const _Loading(),
            error: (e, _) => _ErrorText(e),
            data: (d) => ActivityHeatmap(data: d),
          ),
        ),
        const SizedBox(height: 24),

        // ── Focus bar chart ──
        _Section(
          title: '专注时长 (近 30 天)',
          child: focus.when(
            loading: () => const _Loading(),
            error: (e, _) => _ErrorText(e),
            data: (d) => FocusBarChart(data: d),
          ),
        ),
        const SizedBox(height: 24),

        // ── Trends line chart ──
        _Section(
          title: '任务趋势 (近 30 天)',
          child: trends.when(
            loading: () => const _Loading(),
            error: (e, _) => _ErrorText(e),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrendsLineChart(data: d),
                const SizedBox(height: 8),
                _Legend(
                  items: [
                    (color: Theme.of(context).colorScheme.primary, label: '已完成'),
                    (color: Theme.of(context).colorScheme.secondary, label: '新建'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);
  final Object error;
  @override
  Widget build(BuildContext context) =>
      Text('错误: $error', style: const TextStyle(color: Colors.red));
}

class _Legend extends StatelessWidget {
  const _Legend({required this.items});
  final List<({Color color, String label})> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 3,
                  color: item.color,
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
