import 'package:achievements/app/shell.dart';
import 'package:achievements/features/today/today_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// 应用顶层路由配置。
///
/// Phase 1 step 1 只暴露根路径 `/`,渲染 [AppShell] 嵌套 [TodayPage]。
/// 后续 Phase 在此基础上追加 list / task / calendar / focus / stats 等。
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'today',
        builder: (context, state) =>
            const AppShell(title: 'Today', child: TodayPage()),
      ),
    ],
  );
}
