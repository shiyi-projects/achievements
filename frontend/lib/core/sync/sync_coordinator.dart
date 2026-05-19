import 'dart:async';

import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_coordinator.g.dart';

/// 同步触发协调器。
///
/// 负责把 [SyncEngine] 的 pull / push 接到三个触发源:
///   1. **启动**:bootstrap 调用 [runFullSync] 跑 pull → push。
///   2. **本地写入**:监听 outbox.watchPendingCount,500ms debounce 后跑 push。
///   3. **网络恢复**:connectivity_plus 监听到 offline → online 后跑 pull + push。
///
/// 全部触发都会把 [SyncStatusController] 写入 syncing → idle / error / offline。
/// 同一时间只允许一次 sync 在跑(_inFlight 闸门),并发触发被合并。
class SyncCoordinator {
  SyncCoordinator({
    required SyncEngine engine,
    required OutboxRepository outbox,
    required SyncStatusController status,
    Connectivity? connectivity,
  }) : _engine = engine,
       _outbox = outbox,
       _status = status,
       _connectivity = connectivity ?? Connectivity();

  final SyncEngine _engine;
  final OutboxRepository _outbox;
  final SyncStatusController _status;
  final Connectivity _connectivity;

  StreamSubscription<int>? _outboxSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _debounce;
  Timer? _retryTimer;
  Timer? _pollTimer;
  bool _inFlight = false;
  bool _wasOffline = false;

  static const Duration _kPollInterval = Duration(seconds: 30);

  /// 启动触发监听。bootstrap 阶段调用一次。
  void start() {
    _outboxSub ??= _outbox.watchPendingCount().listen(_onOutboxChanged);
    _connectivitySub ??= _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  /// 释放资源(目前没人调,挂在 keepAlive provider 上随 app 生命周期)。
  void dispose() {
    _outboxSub?.cancel();
    _connectivitySub?.cancel();
    _debounce?.cancel();
    _retryTimer?.cancel();
    _pollTimer?.cancel();
  }

  /// 完整同步:pull 增量,再把 outbox 推完。bootstrap / 网络恢复时用。
  Future<void> runFullSync() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_inFlight) return;
    _inFlight = true;
    try {
      _status.set(SyncStatus.syncing);
      final pullResult = await _engine.pullOnce();
      if (pullResult != SyncStatus.idle) {
        _status.set(pullResult);
        _scheduleRetry(runFullSync);
        return;
      }
      final pushResult = await _engine.pushOnce();
      _status.set(pushResult);
      if (pushResult == SyncStatus.error || pushResult == SyncStatus.offline) {
        _scheduleRetry(runFullSync);
      }
    } finally {
      _inFlight = false;
      // 无论成功还是失败(错误路径已有 retry),都在 30s 后再轮询
      if (_retryTimer == null) _schedulePoll();
    }
  }

  /// 单独跑一次 push(本地写入 debounce 后调用)。
  Future<void> _runPush() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_inFlight) return;
    _inFlight = true;
    try {
      _status.set(SyncStatus.syncing);
      final result = await _engine.pushOnce();
      _status.set(result);
      _scheduleRetry(_runPush, only: result);
    } finally {
      _inFlight = false;
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(_kPollInterval, () => unawaited(runFullSync()));
  }

  /// error / offline 时 30s 后重跑 [callback]。
  void _scheduleRetry(Future<void> Function() callback, {SyncStatus? only}) {
    final shouldRetry =
        only == null ||
        only == SyncStatus.error ||
        only == SyncStatus.offline;
    if (!shouldRetry) return;
    _retryTimer = Timer(
      const Duration(seconds: 30),
      () => unawaited(callback()),
    );
  }

  void _onOutboxChanged(int count) {
    if (count <= 0) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _runPush);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (_wasOffline && !isOffline) {
      // 离线 → 在线的边沿触发一次全量 sync。
      debugPrint('sync: connectivity restored, kicking full sync');
      unawaited(runFullSync());
    }
    _wasOffline = isOffline;
  }
}

@Riverpod(keepAlive: true)
SyncCoordinator syncCoordinator(Ref ref) {
  return SyncCoordinator(
    engine: ref.watch(syncEngineProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    status: ref.watch(syncStatusControllerProvider.notifier),
  );
}
