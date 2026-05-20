import 'package:achievements/app/router.dart';
import 'package:achievements/app/theme.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/repositories/bootstrap_provider.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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

/// 品牌启动画面 — 渐变背景 + Logo 弹入 + 脉冲加载环
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLight
                ? [scheme.surface, scheme.primaryContainer.withValues(alpha: 0.3)]
                : [scheme.surface, scheme.primaryContainer.withValues(alpha: 0.1)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo ──
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppIcons.svgIcon(AppIcons.appIcon, size: 64),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    duration: MotionDurations.bouncy,
                    curve: MotionCurves.bouncySpring,
                  )
                  .fadeIn(duration: MotionDurations.normal),
              const SizedBox(height: 24),
              Text(
                'Achievements',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: MotionDurations.normal,
                    delay: const Duration(milliseconds: 200),
                  ),
              const SizedBox(height: 32),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.primary.withValues(alpha: 0.6),
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: MotionDurations.normal,
                    delay: const Duration(milliseconds: 400),
                  ),
            ],
          ),
        ),
      ),
    );
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '初始化失败',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
