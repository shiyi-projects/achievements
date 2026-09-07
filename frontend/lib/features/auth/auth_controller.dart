import 'dart:async';

import 'package:achievements/data/remote/api_client.dart';
import 'package:achievements/features/auth/account_operation_gate.dart';
import 'package:achievements/features/auth/auth_repository.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:achievements/features/auth/token_expiry.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/expanded_lists.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(dio: ref.watch(authApiClientProvider));
});

final currentAuthSessionProvider = Provider<AuthSession?>((ref) {
  final state = ref.watch(authControllerProvider);
  return switch (state) {
    AuthAuthenticated(:final session) => session,
    AuthSwitching(:final previousSession) => previousSession,
    _ => null,
  };
});

final currentUserIdProvider = Provider<String>((ref) {
  final session = ref.watch(currentAuthSessionProvider);
  if (session == null) {
    throw StateError('No authenticated user');
  }
  return session.appUserId;
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._ref) : super(const AuthLoading()) {
    // 用 AppLifecycleListener 而不是 mixin WidgetsBindingObserver:后者会把
    // 18 个生命周期回调并进本类的接口面,implements AuthController 的测试替身
    // 全得跟着实现一遍。
    _lifecycle = AppLifecycleListener(
      // 进程被挂起时周期计时器不一定还在走(移动端尤其),恢复前台补检一次,
      // 否则可能整段后台时间都没续上,回来正好撞过期。
      onResume: () => unawaited(_maybeRenewToken()),
    );
    _load();
  }

  final AuthRepository _repository;
  final Ref _ref;
  Future<void>? _authBoundaryOperation;
  Timer? _renewTimer;
  Future<void>? _renewInFlight;
  late final AppLifecycleListener _lifecycle;

  /// 长时间挂着不关的桌面端也要能续上,所以除了启动时那次还得周期性检查。
  /// 线上 TTL 只有 8h,间隔取 1h 留足重试余量(单次失败还有 7 次机会)。
  static const _renewCheckInterval = Duration(hours: 1);

  Future<void> _load() async {
    final session = await _repository.loadSession();
    if (session == null) {
      state = const AuthUnauthenticated();
      return;
    }
    if (isTokenExpired(session.token)) {
      // 已过期的 token 续不回来了(SCC 续期端点同样回 401),直接清掉进登录页,
      // 免得带着死 token 跑一轮业务请求、再被 401 拦截器绕路登出。
      await _repository.clearSession();
      state = const AuthUnauthenticated();
      return;
    }
    state = AuthAuthenticated(session);
    _ensureRenewTimer();
    unawaited(_maybeRenewToken());
  }

  /// 续期检查是全局单例的:启动时带着会话进来、或扫码登录后,都从这里起一次。
  void _ensureRenewTimer() {
    _renewTimer ??= Timer.periodic(
      _renewCheckInterval,
      (_) => unawaited(_maybeRenewToken()),
    );
  }

  /// token 进入续期窗口时换发新的;失败静默沿用旧 token,不打断使用。
  ///
  /// 公众号扫码没法静默重复,不续期的话线上 8h TTL 一到就得重新扫码。
  Future<void> _maybeRenewToken() {
    return _renewInFlight ??= _renewToken().whenComplete(() {
      _renewInFlight = null;
    });
  }

  Future<void> _renewToken() async {
    final session = switch (state) {
      AuthAuthenticated(:final session) => session,
      _ => null,
    };
    // 切换账号 / 登出过程中不续期:此时会话正在变更,续完也会被覆盖。
    if (session == null) return;
    if (!shouldRenew(session.token)) return;
    try {
      final token = await _repository.renew(session.token);
      // 续期期间用户可能已经登出或切了账号,只有会话没变才写回。
      final current = switch (state) {
        AuthAuthenticated(:final session) => session,
        _ => null,
      };
      if (current == null || current.token != session.token) return;
      final renewed = current.withToken(token);
      await _repository.saveSession(renewed);
      state = AuthAuthenticated(renewed);
    } catch (_) {
      // 网络不通 / SCC 暂时不可用:沿用旧 token 到期,下次检查再试。
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _renewTimer?.cancel();
    super.dispose();
  }

  Future<void> setSession(AuthSession session) {
    _ensureRenewTimer();
    final currentSession = switch (state) {
      AuthAuthenticated(:final session) => session,
      AuthSwitching(:final previousSession) => previousSession,
      _ => null,
    };
    if (currentSession?.appUserId == session.appUserId) {
      return _serializeAuthBoundary(() async {
        await _repository.saveSession(session);
        state = AuthAuthenticated(session);
      });
    }

    return _serializeAuthBoundary(() async {
      state = AuthSwitching(currentSession);
      final gate = _ref.read(accountOperationGateProvider);
      // 临界区:先 drain 掉旧账号已开始的操作,再写入新会话。
      await gate.runAccountSwitch(() => _repository.saveSession(session));
      _resetAccountScopedState();
      // 切到新 session 后,所有账号作用域 provider(appDatabase / syncEngine /
      // syncCoordinator / outbox / appBootstrap)会因为 watch(currentUserIdProvider)
      // 自动按新 userId 重建,旧账号实例随之 dispose——无需手动 invalidate。
      state = AuthAuthenticated(session);
    });
  }

  Future<void> logout() {
    final currentSession = switch (state) {
      AuthAuthenticated(:final session) => session,
      AuthSwitching(:final previousSession) => previousSession,
      _ => null,
    };
    return _serializeAuthBoundary(() async {
      state = AuthSwitching(currentSession);
      try {
        final gate = _ref.read(accountOperationGateProvider);
        // 临界区只负责:等已开始的账号作用域操作 drain 结束,再清除本地凭证。
        // 加超时兜底:即使 drain / secure storage 意外卡住,也保证 UI 能离开
        // splash,不会永远停在登出过场。
        await gate
            .runAccountSwitch(_repository.clearSession)
            .timeout(const Duration(seconds: 8), onTimeout: () {});
      } catch (_) {
        // Best-effort: still try to clear the session even if the gate
        // or drain threw.
        try {
          await _repository.clearSession();
        } catch (_) {}
      }
      state = const AuthUnauthenticated();
      _resetAccountScopedState();
      // 不要从这里手动 invalidate appDatabase / syncEngine / syncCoordinator /
      // appBootstrap:它们都 watch(currentUserIdProvider),而 currentUserId 依赖
      // authControllerProvider 自身。从 AuthController 自己的 ref 去 invalidate
      // 这些下游 provider 会触发 CircularDependencyError;该检查只是 debug 断言,
      // release 下被跳过,invalidate 反而会在旧 session 仍在时强制重算 appBootstrap,
      // 针对正在登出的旧账号重跑整个 bootstrap(含首次同步门 pullOnce),与正在
      // teardown 的 DB / 会话竞态,最终永远停在启动 splash。
      //
      // 正确做法:state 切到 AuthUnauthenticated 后,currentUserId 进入未登录态,
      // 这些账号作用域 provider 会自动失效 / dispose(关闭旧 DB、停掉后台 sync),
      // 重新登录时再按新 userId 重建。
    });
  }

  Future<void> _serializeAuthBoundary(Future<void> Function() action) {
    final previous = _authBoundaryOperation ?? Future<void>.value();
    final next = previous.then((_) => action());
    _authBoundaryOperation = next.whenComplete(() {
      if (identical(_authBoundaryOperation, next)) {
        _authBoundaryOperation = null;
      }
    });
    return next;
  }

  void _resetAccountScopedState() {
    _ref.invalidate(selectedListIdProvider);
    _ref.invalidate(selectedTaskIdProvider);
    _ref.invalidate(currentViewNotifierProvider);
    _ref.invalidate(expandedListsProvider);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.watch(authRepositoryProvider), ref);
  },
);
