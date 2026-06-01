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
/// 触发策略(类 git 的「有改动才推、不每次打开都同」):
///   1. **启动**:bootstrap 调用 [runFullSync] 跑 pull → push,**拉取仅此一次**。
///   2. **本地写入**:监听 outbox.watchPendingCount,500ms debounce 后跑 push;
///      没有改动(outbox 空)就什么都不发。
///   3. **网络恢复**:offline → online 边沿 **只 flush 未推送的本地改动(push)**,
///      不自动 pull。
///   4. **手动**:下拉刷新 / 设置页「立即同步」直接调 [runFullSync](pull + push)。
///   5. **失败重试**:pull/push 报 error/offline 时延时重试,直到成功。
///
/// 不再有 resume / 窗口聚焦 / 周期轮询触发的自动 pull —— 远端变更靠启动拉取或
/// 用户手动刷新获取。全部触发都会把 [SyncStatusController] 写入
/// syncing → idle / error / offline。同一时间只允许一次 sync 在跑,并发触发被合并。
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
  Future<void>? _activeRun;
  CancelToken? _cancelToken;
  bool _stopping = false;
  bool _wasOffline = false;
  bool _lifecycleObserverRegistered = false;

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
    if (_lifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverRegistered = false;
    }
    await outboxSub?.cancel();
    await connectivitySub?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切回前台不再自动 pull(按「不每次打开都同」的策略)。本地改动仍由
    // outbox 监听驱动 push,远端变更靠启动拉取或手动刷新获取。
  }

  /// 完整同步:pull 增量,再把 outbox 推完。启动 / 手动刷新 / 设置页「立即同步」用。
  Future<void> runFullSync() async {
    if (_stopping || _activeRun != null) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _activeRun = _gate
        .runForAccount(_userId, _currentUserId, () async {
          if (_stopping) return;
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
      // 离线 → 在线的边沿:只 flush 未推送的本地改动,不自动 pull。
      debugPrint('sync: connectivity restored, flushing pending push');
      unawaited(_runPush());
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
