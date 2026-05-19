import 'package:flutter/material.dart';

class OverviewCards extends StatelessWidget {
  const OverviewCards({
    required this.totalCompleted,
    required this.todayCompleted,
    required this.streakDays,
    required this.totalFocusMinutes,
    super.key,
  });

  final int totalCompleted;
  final int todayCompleted;
  final int streakDays;
  final int totalFocusMinutes;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          icon: Icons.task_alt_rounded,
          label: '累计完成',
          value: '$totalCompleted',
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.today_rounded,
          label: '今日完成',
          value: '$todayCompleted',
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.local_fire_department_rounded,
          label: '连续天数',
          value: '$streakDays 天',
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.timer_rounded,
          label: '累计专注',
          value: '${totalFocusMinutes ~/ 60}h ${totalFocusMinutes % 60}m',
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
