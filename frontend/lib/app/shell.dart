import 'package:achievements/core/constants.dart';
import 'package:achievements/features/list_view/list_page.dart';
import 'package:achievements/features/sidebar/sidebar.dart';
import 'package:achievements/features/today/today_page.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 响应式应用外壳。
///
/// - 桌面(width >= [_kSplitBreakpoint]):左侧 [Sidebar] 常驻
/// - 移动:Sidebar 进 Drawer
///
/// 主视图根据 [currentListProvider] 切换:Today system 走 [TodayPage],
/// 其余走通用 [ListPage]。
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const double _kSplitBreakpoint = 720;
  static const double _kSidebarWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(currentListProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _kSplitBreakpoint;

    final title = currentAsync.maybeWhen(
      data: (list) => list?.name ?? 'Achievements',
      orElse: () => 'Achievements',
    );
    final body = currentAsync.when(
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

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            const SizedBox(width: _kSidebarWidth, child: Sidebar()),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  AppBar(title: Text(title), automaticallyImplyLeading: false),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: const Drawer(
        child: SizedBox(width: _kSidebarWidth, child: Sidebar()),
      ),
      body: body,
    );
  }
}
