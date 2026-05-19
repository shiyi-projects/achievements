import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/calendar/providers/calendar_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 日历月份导航头部。
///
/// 渐变卡片背景，包含:
/// - 左右箭头切换月份
/// - 中间月份标题
/// - "今天" 胶囊按钮
class CalendarHeader extends ConsumerWidget {
  const CalendarHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(focusedMonthProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = '${month.year} 年 ${month.month} 月';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        Spacing.base, Spacing.sm, Spacing.base, Spacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.45),
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => ref.read(focusedMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => ref.read(focusedMonthProvider.notifier).state =
                DateTime(month.year, month.month + 1),
          ),
          const SizedBox(width: Spacing.xs),
          _TodayPill(
            onTap: () {
              final now = DateTime.now();
              ref.read(focusedMonthProvider.notifier).state =
                  DateTime(now.year, now.month);
              ref.read(selectedDayProvider.notifier).state =
                  DateTime(now.year, now.month, now.day);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.circle),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(Radii.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.xs + 2,
          ),
          child: Text(
            '今天',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
