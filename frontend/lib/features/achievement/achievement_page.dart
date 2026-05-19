import 'package:achievements/features/achievement/models/achievement_def.dart';
import 'package:achievements/features/achievement/providers/achievement_providers.dart';
import 'package:achievements/features/achievement/widgets/achievement_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AchievementPage extends ConsumerWidget {
  const AchievementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(achievementStatusProvider);

    return statusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('错误: $e')),
      data: (status) {
        final unlocked = kAchievementDefs.where((d) => status[d.code] ?? false).toList();
        final locked = kAchievementDefs.where((d) => !(status[d.code] ?? false)).toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Summary banner ──
            _SummaryBanner(unlocked: unlocked.length, total: kAchievementDefs.length),
            const SizedBox(height: 24),

            // ── Unlocked ──
            if (unlocked.isNotEmpty) ...[
              _SectionLabel(
                '已解锁 (${unlocked.length})',
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              _AchievementGrid(defs: unlocked, status: status, animate: true),
              const SizedBox(height: 24),
            ],

            // ── Locked ──
            if (locked.isNotEmpty) ...[
              _SectionLabel('未解锁 (${locked.length})'),
              const SizedBox(height: 12),
              _AchievementGrid(defs: locked, status: status),
            ],
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.unlocked, required this.total});
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = unlocked / total;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unlocked / $total 个成就',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}% 已解锁',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: color ?? theme.colorScheme.outline,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({
    required this.defs,
    required this.status,
    this.animate = false,
  });

  final List<AchievementDef> defs;
  final Map<String, bool> status;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: defs.length,
      itemBuilder: (_, i) => AchievementCard(
        def: defs[i],
        unlocked: status[defs[i].code] ?? false,
        animateIn: animate,
      ),
    );
  }
}
