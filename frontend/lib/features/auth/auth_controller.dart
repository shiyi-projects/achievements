import 'package:achievements/data/remote/api_client.dart';
import 'package:achievements/features/auth/account_operation_gate.dart';
import 'package:achievements/features/auth/auth_repository.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/expanded_lists.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:achievements/state/selected_task.dart';
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
    _load();
  }

  final AuthRepository _repository;
  final Ref _ref;
  Future<void>? _authBoundaryOperation;

  Future<void> _load() async {
    final session = await _repository.loadSession();
    state = session == null
        ? const AuthUnauthenticated()
        : AuthAuthenticated(session);
  }

  Future<void> setSession(AuthSession session) {
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
