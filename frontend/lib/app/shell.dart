import 'package:achievements/core/constants.dart';
import 'package:achievements/features/list_view/list_page.dart';
import 'package:achievements/features/sidebar/sidebar.dart';
import 'package:achievements/features/task_detail/task_detail_panel.dart';
import 'package:achievements/features/today/today_page.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 响应式应用外壳。
///
/// 三档断点:
/// - 移动(< 720):Sidebar 进 Drawer;任务详情走 modal bottom sheet
/// - 平板(720–1023):Sidebar 常驻;任务详情走 modal bottom sheet
/// - 桌面(>= 1024):Sidebar + 主视图 + 任务详情面板 三列并存
///
/// 主视图根据 [currentListProvider] 在 [TodayPage] / [ListPage] 间切换。
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const double _kSidebarBreakpoint = 720;
  static const double _kDetailDockBreakpoint = 1024;
  static const double _kSidebarWidth = 280;
  static const double _kDetailWidth = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final showSidebarInline = width >= _kSidebarBreakpoint;
    final dockDetail = width >= _kDetailDockBreakpoint;

    final currentAsync = ref.watch(currentListProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);

    // 非桌面:监听选中任务变化,触发 bottom sheet
    if (!dockDetail) {
      ref.listen<String?>(selectedTaskIdProvider, (prev, next) {
        if (next != null && prev != next) {
          _openTaskSheet(context, ref);
        }
      });
    }

    final title = currentAsync.maybeWhen(
      data: (list) => list?.name ?? 'Achievements',
      orElse: () => 'Achievements',
    );
    final mainBody = currentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Sidebar 选中态加载失败:$e'),
        ),
      ),
      data: (list) {
        final kind = SystemListKind.fromValue(list?.systemKind);
        if (kind == SystemListKind.today) return const TodayPage();
        return const ListPage();
      },
    );

    if (showSidebarInline) {
      return Scaffold(
        body: Row(
          children: [
            const SizedBox(width: _kSidebarWidth, child: Sidebar()),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  AppBar(title: Text(title), automaticallyImplyLeading: false),
                  Expanded(child: mainBody),
                ],
              ),
            ),
            if (dockDetail && selectedTaskId != null) ...[
              const VerticalDivider(width: 1),
              const SizedBox(width: _kDetailWidth, child: TaskDetailPanel()),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: const Drawer(
        child: SizedBox(width: _kSidebarWidth, child: Sidebar()),
      ),
      body: mainBody,
    );
  }

  Future<void> _openTaskSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: TaskDetailPanel(),
      ),
    );
    // sheet 关闭(无论是 close 按钮 / 滑动 / 系统返回)后清空选中
    ref.read(selectedTaskIdProvider.notifier).clear();
  }
}
