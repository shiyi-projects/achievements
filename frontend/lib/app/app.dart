import 'package:achievements/app/router.dart';
import 'package:achievements/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Achievements 根 Widget。
///
/// 监听 `routerProvider` 取得 GoRouter,使用 Material 3 主题
/// (浅色 / 深色由系统 brightness 决定;Phase 4 接入设置页后改由用户偏好驱动)。
class AchievementsApp extends ConsumerWidget {
  const AchievementsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Achievements',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
    );
  }
}
