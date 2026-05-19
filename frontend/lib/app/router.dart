import 'package:achievements/app/shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// 应用顶层路由配置。
///
/// `/` 渲染 [AppShell],主视图内由 currentListProvider 驱动切换;
/// 暂未拆出 `/list/:id` 等子路径。
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const AppShell(),
      ),
    ],
  );
}
