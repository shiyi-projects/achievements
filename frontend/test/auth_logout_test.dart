import 'dart:async';

import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/features/auth/auth_repository.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:dio/dio.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = AuthSession(
  token: 't',
  appUserId: 'user-a',
  profile: AuthProfile(id: 1),
);

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.clearBlocks = false}) : super(dio: Dio());

  /// true 时 clearSession 永不返回,用来模拟登出清理在 Windows 上意外卡死。
  final bool clearBlocks;
  int clearCalls = 0;

  @override
  Future<AuthSession?> loadSession() async => _session;

  @override
  Future<void> clearSession() async {
    clearCalls++;
    if (clearBlocks) {
      await Completer<void>().future; // 永不完成
    }
  }

  /// AuthController 载入会话后会尝试滑动续期;这里断掉,免得单测走真实网络。
  @override
  Future<String> renew(String token) async {
    throw DioException.connectionError(
      requestOptions: RequestOptions(),
      reason: 'offline in tests',
    );
  }
}

void main() {
  // AuthController 用 AppLifecycleListener 监听前台恢复,需要 binding 就绪。
  TestWidgetsFlutterBinding.ensureInitialized();

  test('登出正常清理后进入未认证态', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider); // 触发构造 + _load
      async.flushMicrotasks();
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

      unawaited(container.read(authControllerProvider.notifier).logout());
      async.flushMicrotasks();

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    });
  });

  test('清理卡死时,超时兜底仍让 UI 离开登出过场(不永久停在 splash)', () {
    fakeAsync((async) {
      final repo = _FakeAuthRepository(clearBlocks: true);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider);
      async.flushMicrotasks();
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

      unawaited(container.read(authControllerProvider.notifier).logout());
      async.flushMicrotasks();
      // 登出过场:AuthSwitching → UI 显示 splash
      expect(container.read(authControllerProvider), isA<AuthSwitching>());

      // 不应永久卡:超时兜底后进入未认证态,UI 可切到二维码登录页。
      async.elapse(const Duration(seconds: 9));
      async.flushMicrotasks();
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(repo.clearCalls, greaterThan(0));
    });
  });
}
