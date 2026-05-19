import 'package:achievements/features/calendar/widgets/calendar_header.dart';
import 'package:achievements/features/calendar/widgets/day_task_list.dart';
import 'package:achievements/features/calendar/widgets/month_grid.dart';
import 'package:achievements/features/calendar/widgets/month_summary_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 日历视图主页面（组装层）。
///
/// 从上到下:
/// 1. [CalendarHeader] — 渐变月份导航
/// 2. [MonthSummaryBar] — 月度统计摘要
/// 3. [MonthGrid] — 月历网格（手势切月）
/// 4. [DayTaskList] — 选中日期任务面板 / 空态
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return const [
          SliverToBoxAdapter(child: CalendarHeader()),
          SliverToBoxAdapter(child: MonthSummaryBar()),
          SliverToBoxAdapter(child: MonthGrid()),
        ];
      },
      body: const DayTaskList(),
    );
  }
}
