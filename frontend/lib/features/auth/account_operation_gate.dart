import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 账号边界操作闸门。
///
/// 同步 / bootstrap 等账号作用域操作通过 [runForAccount] 注册；登录切换或
/// 登出通过 [runAccountSwitch] 进入临界区，先阻止新操作，再等待已开始的操作
/// 自然结束，避免旧账号后台任务和新账号数据库初始化交错。
class AccountOperationGate {
  bool _switching = false;
  int _activeOperations = 0;
  Completer<void>? _drainCompleter;

  bool get isSwitching => _switching;

  Future<T?> runForAccount<T>(
    String userId,
    String? Function() currentUserId,
    Future<T> Function() body,
  ) async {
    if (_switching || currentUserId() != userId) return null;
    _activeOperations++;
    try {
      if (_switching || currentUserId() != userId) return null;
      final result = await body();
      if (_switching || currentUserId() != userId) return null;
      return result;
    } finally {
      _activeOperations--;
      if (_activeOperations == 0) {
        _drainCompleter?.complete();
        _drainCompleter = null;
      }
    }
  }

  Future<T> runAccountSwitch<T>(Future<T> Function() body) async {
    _switching = true;
    try {
      await _waitForDrain();
      return await body();
    } finally {
      _switching = false;
    }
  }

  Future<void> _waitForDrain({Duration timeout = const Duration(seconds: 5)}) {
    if (_activeOperations == 0) return Future<void>.value();
    final future = (_drainCompleter ??= Completer<void>()).future;
    return future.timeout(timeout, onTimeout: () {
      _drainCompleter?.complete();
      _drainCompleter = null;
    });
  }
}

final accountOperationGateProvider = Provider<AccountOperationGate>((ref) {
  return AccountOperationGate();
});
