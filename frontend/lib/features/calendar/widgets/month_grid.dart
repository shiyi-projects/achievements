import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/features/calendar/providers/calendar_providers.dart';
import 'package:achievements/features/calendar/widgets/day_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 月历网格。
///
/// 使用 [PageView.builder] 支持水平滑动切月,带平滑过渡动画。
/// Header 中的箭头按钮通过 [monthPageController] 驱动翻页。
///
/// 行高 48dp,周标签行 20dp,呼吸感布局。
class MonthGrid extends ConsumerStatefulWidget {
  const MonthGrid({super.key});

  @override
  ConsumerState<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends ConsumerState<MonthGrid> {
  static const int _kInitialPage = 1200; // 中心点: 当前月
  late final PageController _pageCtrl;
  late DateTime _anchorMonth; // PageView 初始化时的月份

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorMonth = DateTime(now.year, now.month);
    _pageCtrl = PageController(initialPage: _kInitialPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// 根据页码偏移计算月份。
  DateTime _monthForPage(int page) {
    final offset = page - _kInitialPage;
    return DateTime(_anchorMonth.year, _anchorMonth.month + offset);
  }

  /// 根据月份反算页码。
  int _pageForMonth(DateTime month) {
    final diff = (month.year - _anchorMonth.year) * 12 +
        (month.month - _anchorMonth.month);
    return _kInitialPage + diff;
  }

  @override
  Widget build(BuildContext context) {
    final focusedMonth = ref.watch(focusedMonthProvider);

    // Header 箭头触发的 focusedMonth 变化 → 驱动 PageView 翻页
    ref.listen<DateTime>(focusedMonthProvider, (prev, next) {
      final target = _pageForMonth(next);
      if (_pageCtrl.hasClients && _pageCtrl.page?.round() != target) {
        _pageCtrl.animateToPage(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });

    final selected = ref.watch(selectedDayProvider);
    final byDay = ref.watch(tasksByDayProvider);

    // 计算固定高度: 周标签 (20) + 最多 6 行 * 48 + padding
    const double headerH = 20;
    const double rowH = 48;
    const double maxRows = 6;
    const double totalH = headerH + 4 + rowH * maxRows + Spacing.sm * 2;

    return SizedBox(
      height: totalH,
      child: PageView.builder(
        controller: _pageCtrl,
        onPageChanged: (page) {
          final month = _monthForPage(page);
          // 只在用户手动滑动时同步 provider(避免循环)
          final current = ref.read(focusedMonthProvider);
          if (current.year != month.year || current.month != month.month) {
            ref.read(focusedMonthProvider.notifier).state = month;
          }
        },
        itemBuilder: (context, page) {
          final month = _monthForPage(page);
          // 只有当前聚焦月才用 live 数据, 相邻月用空数据(性能)
          final isFocused = month.year == focusedMonth.year &&
              month.month == focusedMonth.month;
          return _MonthPage(
            month: month,
            selected: selected,
            byDay: isFocused ? byDay : const {},
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Single month page
// ─────────────────────────────────────────────────────────────────────

class _MonthPage extends ConsumerWidget {
  const _MonthPage({
    required this.month,
    required this.selected,
    required this.byDay,
  });

  final DateTime month;
  final DateTime? selected;
  final Map<int, List<Task>> byDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

    final firstWeekday = DateTime(month.year, month.month).weekday;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    final flat = <int>[
      for (var i = 1; i < firstWeekday; i++) 0,
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    while (flat.length % 7 != 0) {
      flat.add(0);
    }

    final weeks = <List<int>>[];
    for (var i = 0; i < flat.length; i += 7) {
      weeks.add(flat.sublist(i, i + 7));
    }

    const double rowH = 48;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Weekday header ──
          SizedBox(
            height: 20,
            child: Row(
              children: [
                for (int i = 0; i < weekLabels.length; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekLabels[i],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: i >= 5
                              ? scheme.tertiary.withValues(alpha: 0.7)
                              : scheme.outline,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // ── Day rows ──
          for (final week in weeks)
            SizedBox(
              height: rowH,
              child: Row(
                children: [
                  for (final d in week)
                    Expanded(
                      child: d == 0
                          ? const SizedBox.shrink()
                          : DayCell(
                              day: d,
                              isSelected: selected != null &&
                                  selected!.year == month.year &&
                                  selected!.month == month.month &&
                                  selected!.day == d,
                              isToday: _isToday(month, d),
                              tasks: byDay[d] ?? const <Task>[],
                              onTap: () {
                                ref
                                    .read(selectedDayProvider.notifier)
                                    .state =
                                    DateTime(month.year, month.month, d);
                              },
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static bool _isToday(DateTime month, int day) {
    final now = DateTime.now();
    return now.year == month.year &&
        now.month == month.month &&
        now.day == day;
  }
}
