import 'package:achievements/features/calendar/widgets/calendar_header.dart';
import 'package:achievements/features/calendar/widgets/day_task_list.dart';
import 'package:achievements/features/calendar/widgets/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 日历视图主页面（组装层）。
///
/// Column 布局（日历部分固定高度,只有任务列表滚动）:
/// 1. [CalendarHeader] — 月份导航 + 统计摘要(合并)
/// 2. [MonthGrid] — PageView 月历网格(支持水平滑动切月)
/// 3. [DayTaskList] — 选中日期任务面板(Expanded,内部滚动)
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      children: [
        CalendarHeader(),
        MonthGrid(),
        Expanded(child: DayTaskList()),
      ],
    );
  }
}
