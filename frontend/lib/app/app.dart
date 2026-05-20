import 'package:achievements/app/router.dart';
import 'package:achievements/app/theme.dart';
import 'package:achievements/data/repositories/bootstrap_provider.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Achievements 根 Widget。
///
/// MaterialApp.router 驱动路由,builder 内根据 appBootstrap 状态决定:
///   - loading -> [_BootstrapSplash]
///   - error   -> [_BootstrapError]
///   - data    -> 真实页面(child!)
///
/// 主题默认跟随系统 brightness;Phase 4 设置页接入后由用户偏好驱动。
class AchievementsApp extends ConsumerWidget {
  const AchievementsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsNotifierProvider).valueOrNull ??
        kDefaultSettings;

    return MaterialApp.router(
      title: 'Achievements',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildLightTheme(settings.seedColor),
      darkTheme: buildDarkTheme(settings.seedColor),
      routerConfig: router,
      builder: (context, child) {
        final bootstrap = ref.watch(appBootstrapProvider);
        return bootstrap.when(
          loading: () => const _BootstrapSplash(),
          error: (e, st) => _BootstrapError(message: e.toString()),
          data: (_) => child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '初始化失败:$message',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
    );
  }
}
