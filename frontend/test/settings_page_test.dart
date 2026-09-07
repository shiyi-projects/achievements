import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:achievements/features/settings/settings_page.dart';
import 'package:achievements/features/settings/widgets/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 设置页拆成 sections/ 之后,接线错误(漏 provider、错 import)只会在打开
/// 设置时炸。这里把整页渲染一遍兜底。
void main() {
  Future<void> pumpSettings(WidgetTester tester) async {
    // 整页一屏放得下,断言不受视口裁剪影响。
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsNotifierProvider.overrideWith(_FakeSettingsNotifier.new),
          syncFailureCountProvider.overrideWith((ref) => Stream.value(0)),
          lastSyncAtProvider.overrideWith(
            (ref) => Stream<DateTime?>.value(DateTime(2026, 9, 5)),
          ),
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
        ],
        child: const MaterialApp(home: SettingsPage(showCloseButton: true)),
      ),
    );
    await tester.pump();
  }

  testWidgets('设置页渲染出全部分节', (tester) async {
    await pumpSettings(tester);

    expect(find.text('设置'), findsOneWidget);
    // 分节标题渲染为全大写(中文不受影响)。
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('同步'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
  });

  testWidgets('用的是极简控件,而不是 Material 的 SegmentedButton', (tester) async {
    await pumpSettings(tester);

    expect(find.byType(SettingsSegmented<ThemeMode>), findsOneWidget);
    expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('点分段项切换主题模式', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('深色'));
    await tester.pump();

    expect(_FakeSettingsNotifier.lastMode, ThemeMode.dark);
  });

  testWidgets('同步区显示状态与账户信息', (tester) async {
    await pumpSettings(tester);

    expect(find.text('已同步'), findsOneWidget);
    expect(find.text('立即同步'), findsOneWidget);
    expect(find.text('微信用户'), findsOneWidget);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  static ThemeMode? lastMode;

  @override
  Future<AppSettingsData> build() async => (
    themeMode: ThemeMode.system,
    seedColor: AppColors.seedTechBlue,
    closeAction: CloseAction.minimizeToTray,
  );

  @override
  Future<void> setThemeMode(ThemeMode mode) async => lastMode = mode;

  @override
  Future<void> setSeedColor(Color color) async {}

  @override
  Future<void> setCloseAction(CloseAction action) async {}
}

class _TestAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _TestAuthController()
    : super(
        const AuthAuthenticated(
          AuthSession(
            token: 'test-token',
            appUserId: '00000000-0000-0000-0000-000000000001',
            profile: AuthProfile(id: 1),
          ),
        ),
      );

  @override
  Future<void> logout() async {}

  @override
  Future<void> setSession(AuthSession session) async {
    state = AuthAuthenticated(session);
  }
}
