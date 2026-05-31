import 'package:achievements/features/achievement/models/achievement_def.dart';
import 'package:achievements/features/achievement/providers/achievement_providers.dart';
import 'package:achievements/features/insights/widgets/achievement_overview_card.dart';
import 'package:achievements/features/insights/widgets/compact_heatmap.dart';
import 'package:achievements/features/insights/widgets/unlocked_achievement_list.dart';
import 'package:achievements/features/insights/widgets/weekly_focus_chart.dart';
import 'package:achievements/features/statistics/providers/stats_providers.dart';
import 'package:achievements/features/statistics/widgets/overview_cards.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 「成就」页 — 参考设计稿的双栏布局仪表盘。
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  /// 与 shell.dart 中一致的断点。
  static const double _kTwoColumnBreakpoint = 840;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(statsOverviewProvider);
    final heatmap = ref.watch(statsHeatmapProvider);
    final focus = ref.watch(statsFocusProvider);
    final statusAsync = ref.watch(achievementStatusProvider);

    final width = MediaQuery.sizeOf(context).width;
    final twoColumn = width >= _kTwoColumnBreakpoint;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── ① Achievement overview hero card ──
        statusAsync.when(
          loading: () => const _Loading(),
          error: (e, _) => _ErrorText(e),
          data: (status) {
            final unlockedCount = kAchievementDefs
                .where((d) => status[d.code] ?? false)
                .length;
            return AchievementOverviewCard(
              unlocked: unlockedCount,
              total: kAchievementDefs.length,
            );
          },
        ),
        const SizedBox(height: 14),

        // ── ② Colorful stat cards ──
        overview.when(
          loading: () => const _Loading(),
          error: (e, _) => _ErrorText(e),
          data: (d) => OverviewCards(
            totalCompleted: d.totalCompleted,
            todayCompleted: d.todayCompleted,
            streakDays: d.streakDays,
            totalFocusMinutes: d.totalFocusMinutes,
          ),
        ),
        const SizedBox(height: 14),

        // ── ③ + ④ + ⑤ Two-column or stacked ──
        if (twoColumn)
          _TwoColumnSection(
            heatmap: heatmap,
            focus: focus,
            statusAsync: statusAsync,
          )
        else
          _StackedSection(
            heatmap: heatmap,
            focus: focus,
            statusAsync: statusAsync,
          ),

        const SizedBox(height: 24),
      ],
    );
  }
}

/// 桌面端：左栏(热力图+专注) | 右栏(成就列表)
class _TwoColumnSection extends StatelessWidget {
  const _TwoColumnSection({
    required this.heatmap,
    required this.focus,
    required this.statusAsync,
  });

  final AsyncValue<Map<String, int>> heatmap;
  final AsyncValue<List<({String date, int sessions, int minutes})>> focus;
  final AsyncValue<Map<String, bool>> statusAsync;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // Compact heatmap
              heatmap.when(
                loading: () => const _Loading(),
                error: (e, _) => _ErrorText(e),
                data: (d) => CompactHeatmap(data: d),
              ),
              const SizedBox(height: 14),
              // Weekly focus chart in card
              _FocusChartCard(focus: focus),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Right column
        Expanded(
          flex: 2,
          child: _AchievementListSection(statusAsync: statusAsync),
        ),
      ],
    );
  }
}

/// 移动端：垂直堆叠所有区块。
class _StackedSection extends StatelessWidget {
  const _StackedSection({
    required this.heatmap,
    required this.focus,
    required this.statusAsync,
  });

  final AsyncValue<Map<String, int>> heatmap;
  final AsyncValue<List<({String date, int sessions, int minutes})>> focus;
  final AsyncValue<Map<String, bool>> statusAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        heatmap.when(
          loading: () => const _Loading(),
          error: (e, _) => _ErrorText(e),
          data: (d) => CompactHeatmap(data: d),
        ),
        const SizedBox(height: 14),
        _FocusChartCard(focus: focus),
        const SizedBox(height: 14),
        _AchievementListSection(statusAsync: statusAsync),
      ],
    );
  }
}

/// 本周专注柱状图，包裹在卡片容器中。
class _FocusChartCard extends StatelessWidget {
  const _FocusChartCard({required this.focus});

  final AsyncValue<List<({String date, int sessions, int minutes})>> focus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
              Text(
                '本周专注',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              focus.when(
                loading: () => const _Loading(),
                error: (e, _) => _ErrorText(e),
                data: (d) => WeeklyFocusChart(data: d),
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
}

/// 成就列表区块 + 底部锁定提示。
class _AchievementListSection extends StatelessWidget {
  const _AchievementListSection({required this.statusAsync});

  final AsyncValue<Map<String, bool>> statusAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return statusAsync.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorText(e),
      data: (status) {
        final unlocked = kAchievementDefs
            .where((d) => status[d.code] ?? false)
            .toList();
        final lockedCount = kAchievementDefs.length - unlocked.length;

        return Column(
          children: [
            UnlockedAchievementList(
              unlocked: unlocked,
              total: kAchievementDefs.length,
            ),
            if (lockedCount > 0) ...[
              const SizedBox(height: 10),
              Center(
                child:
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '还有 $lockedCount 个成就等待解锁',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(
                      duration: MotionDurations.slow,
                      delay: Duration(milliseconds: 60 * unlocked.length + 200),
                    ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 60,
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);
  final Object error;
  @override
  Widget build(BuildContext context) =>
      Text('错误: $error', style: const TextStyle(color: Colors.red));
}
