import 'dart:async';

import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:achievements/features/auth/account_operation_gate.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_coordinator.g.dart';

/// 同步触发协调器。
///
/// 负责把 [SyncEngine] 的 pull / push 接到多个触发源:
///   1. **启动**:bootstrap 调用 [runFullSync] 跑 pull → push。
///   2. **本地写入**:监听 outbox.watchPendingCount,500ms debounce 后跑 push。
///   3. **网络恢复**:connectivity_plus 监听到 offline → online 后跑 pull + push。
///   4. **App 切回前台**:WidgetsBindingObserver.resumed → 节流的 full sync。
///   5. **窗口获得焦点**:由 AppWindowListener 调 [triggerIfStale] 触发。
///   6. **30s 轮询**:每轮成功后排下一次。
///
/// 全部触发都会把 [SyncStatusController] 写入 syncing → idle / error / offline。
/// 同一时间只允许一次 sync 在跑(_inFlight 闸门),并发触发被合并。
class SyncCoordinator extends WidgetsBindingObserver {
  SyncCoordinator({
    required SyncEngine engine,
    required OutboxRepository outbox,
    required SyncStatusController status,
    required AccountOperationGate gate,
    required String userId,
    required String? Function() currentUserId,
    Connectivity? connectivity,
  }) : _engine = engine,
       _outbox = outbox,
       _status = status,
       _gate = gate,
       _userId = userId,
       _currentUserId = currentUserId,
       _connectivity = connectivity ?? Connectivity();

  final SyncEngine _engine;
  final OutboxRepository _outbox;
  final SyncStatusController _status;
  final AccountOperationGate _gate;
  final String _userId;
  final String? Function() _currentUserId;
  final Connectivity _connectivity;

  // Subscriptions are intentionally stored and cancelled in stopAndDrain/dispose.
  // ignore: cancel_subscriptions
  StreamSubscription<int>? _outboxSub;
  // ignore: cancel_subscriptions
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _debounce;
  Timer? _retryTimer;
  Timer? _pollTimer;
  Future<void>? _activeRun;
  CancelToken? _cancelToken;
  bool _stopping = false;
  bool _wasOffline = false;
  bool _lifecycleObserverRegistered = false;
  DateTime? _lastFullSyncStartAt;

  static const Duration _kPollInterval = Duration(seconds: 30);

  /// 启动触发监听。bootstrap 阶段调用一次。
  void start() {
    if (_stopping) return;
    _outboxSub ??= _outbox.watchPendingCount().listen(_onOutboxChanged);
    _connectivitySub ??= _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    if (!_lifecycleObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverRegistered = true;
    }
  }

  Future<void> stopAndDrain() async {
    _stopping = true;
    _cancelToken?.cancel('stopping');
    await _cancelTriggers();
    await _activeRun;
  }

  void dispose() {
    _stopping = true;
    _cancelToken?.cancel('disposed');
    unawaited(_cancelTriggers());
  }

  Future<void> _cancelTriggers() async {
    final outboxSub = _outboxSub;
    final connectivitySub = _connectivitySub;
    _outboxSub = null;
    _connectivitySub = null;
    _debounce?.cancel();
    _debounce = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_lifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverRegistered = false;
    }
    await outboxSub?.cancel();
    await connectivitySub?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_stopping && state == AppLifecycleState.resumed) {
      unawaited(triggerIfStale());
    }
  }

  /// 节流的 full sync 触发。
  ///
  /// 若距上次 full sync 启动不到 [minAge] 不重复跑(避免短时间内 resume+focus
  /// 等多个事件叠着触发);否则跑 [runFullSync]。
  Future<void> triggerIfStale({
    Duration minAge = const Duration(seconds: 10),
  }) async {
    if (_stopping) return;
    final last = _lastFullSyncStartAt;
    if (last != null && DateTime.now().difference(last) < minAge) {
      return;
    }
    await runFullSync();
  }

  /// 完整同步:pull 增量,再把 outbox 推完。bootstrap / 网络恢复时用。
  Future<void> runFullSync() async {
    if (_stopping || _activeRun != null) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _lastFullSyncStartAt = DateTime.now();
    _activeRun = _gate
        .runForAccount(_userId, _currentUserId, () async {
          if (_stopping) return;
          try {
            _status.set(SyncStatus.syncing);
            final token = _cancelToken = CancelToken();
            final pullResult = await _engine.pullOnce(cancelToken: token);
            if (_stopping) return;
            if (pullResult != SyncStatus.idle) {
              _status.set(pullResult);
              _scheduleRetry(runFullSync);
              return;
            }
            final pushResult = await _engine.pushOnce(cancelToken: token);
            if (_stopping) return;
            _status.set(pushResult);
            if (pushResult == SyncStatus.idle) {
              await _stampLastSyncAt();
            }
            if (pushResult == SyncStatus.error ||
                pushResult == SyncStatus.offline) {
              _scheduleRetry(runFullSync);
            }
          } finally {
            // 无论成功还是失败(错误路径已有 retry),都在 30s 后再轮询。
            if (!_stopping && _retryTimer == null) _schedulePoll();
          }
        })
        .then((_) {});
    try {
      await _activeRun;
    } finally {
      _activeRun = null;
    }
  }

  /// 单独跑一次 push(本地写入 debounce 后调用)。
  Future<void> _runPush() async {
    if (_stopping || _activeRun != null) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _activeRun = _gate
        .runForAccount(_userId, _currentUserId, () async {
          if (_stopping) return;
          final token = _cancelToken = CancelToken();
          _status.set(SyncStatus.syncing);
          final result = await _engine.pushOnce(cancelToken: token);
          if (_stopping) return;
          _status.set(result);
          if (result == SyncStatus.idle) {
            await _stampLastSyncAt();
          }
          _scheduleRetry(_runPush, only: result);
        })
        .then((_) {});
    try {
      await _activeRun;
    } finally {
      _activeRun = null;
    }
  }

  Future<void> _stampLastSyncAt() {
    return _outbox.setCursor(
      SyncCursorKey.lastSyncAt,
      DateTime.now().toIso8601String(),
    );
  }

  void _schedulePoll() {
    if (_stopping) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(_kPollInterval, () {
      if (!_stopping) unawaited(runFullSync());
    });
  }

  /// error / offline 时 30s 后重跑 [callback]。
  void _scheduleRetry(Future<void> Function() callback, {SyncStatus? only}) {
    if (_stopping) return;
    final shouldRetry =
        only == null || only == SyncStatus.error || only == SyncStatus.offline;
    if (!shouldRetry) return;
    _retryTimer = Timer(const Duration(seconds: 30), () {
      if (!_stopping) unawaited(callback());
    });
  }

  void _onOutboxChanged(int count) {
    if (_stopping || count <= 0) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!_stopping) unawaited(_runPush());
    });
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (!_stopping && _wasOffline && !isOffline) {
      // 离线 → 在线的边沿触发一次全量 sync。
      debugPrint('sync: connectivity restored, kicking full sync');
      unawaited(runFullSync());
    }
    _wasOffline = isOffline;
  }
}

@Riverpod(keepAlive: true)
SyncCoordinator syncCoordinator(Ref ref) {
  final userId = ref.watch(currentUserIdProvider);
  final coord = SyncCoordinator(
    engine: ref.watch(syncEngineProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    status: ref.watch(syncStatusControllerProvider.notifier),
    gate: ref.watch(accountOperationGateProvider),
    userId: userId,
    currentUserId: () => ref.read(currentAuthSessionProvider)?.appUserId,
  );
  ref.onDispose(coord.dispose);
  return coord;
}
