import 'package:achievements/features/sidebar/sidebar.dart';
import 'package:flutter/material.dart';

/// 响应式应用外壳。
///
/// - 桌面(width >= [_kSplitBreakpoint]):左侧 [Sidebar] 常驻,无 AppBar
///   leading;右侧渲染 [child]
/// - 移动:AppBar 自带汉堡按钮打开 [Sidebar] Drawer,body 全屏渲染 [child]
///
/// child 必须是"纯 body"(不要再嵌套 Scaffold / AppBar)。
class AppShell extends StatelessWidget {
  const AppShell({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  static const double _kSplitBreakpoint = 720;
  static const double _kSidebarWidth = 280;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _kSplitBreakpoint;
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
                  Expanded(child: child),
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
      body: child,
    );
  }
}
