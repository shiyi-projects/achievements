import 'dart:async';

import 'package:achievements/core/notifications/notification_service.dart';
import 'package:achievements/core/notifications/reminder_scheduler.dart';
import 'package:achievements/core/sync/sync_coordinator.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/outbox_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap_provider.g.dart';

/// 首次同步门未通过时,bootstrap 抛此异常。
///
/// 触发条件:本设备上 [SyncCursorKey.firstSyncDone] 还没被置位,且这次启动
/// 的 `pullOnce()` 没有成功(网络断 / 服务端 5xx / 任何非 idle 结果)。
///
/// 用户在错误屏上有两个出口:
///   - 重试:`ref.invalidate(appBootstrapProvider)` 再走一次门;
///   - 离线使用:把游标手动置 `'true'`,接受"本设备先于云端落数据"的风险,
///     之后正常流程接管,outbox 会在网络恢复后 push。
class FirstSyncFailedException implements Exception {
  const FirstSyncFailedException(this.status);
  final SyncStatus status;

  @override
  String toString() =>
      'FirstSyncFailedException(status: ${status.name})';
}

/// 应用启动期一次性初始化:
///   1. 种入系统清单(幂等)
///   2. 初始化 NotificationService(时区 + Android 通道)并尝试申请权限
///   3. 启动 ReminderScheduler:watch 待提醒任务流并 reconcile 本地排程
///   4. **首次同步门**:本设备没标记 firstSyncDone 时,强制 pull 成功才放行;
///      失败抛 [FirstSyncFailedException] 让 UI 显示错误屏(重试/离线)
///   5. 启动 SyncCoordinator 触发监听(outbox debounce + connectivity 边沿)
///   6. 异步 kick 一次 full sync(pull → push),失败不阻塞,SyncStatus 上报
///
/// AchievementsApp 在渲染前 watch 此 Future,完成后再放行 router。
@Riverpod(keepAlive: true)
Future<void> appBootstrap(Ref ref) async {
  await ref.read(listRepositoryProvider).ensureSystemLists();

  final notifications = ref.read(notificationServiceProvider);
  await notifications.initialize();
  // 权限申请失败不阻塞启动,只是后续 schedule 会静默无效
  await notifications.requestPermissions();

  ref.read(reminderSchedulerProvider).start();

  // ── 首次同步门 ──────────────────────────────────────────────────
  // 新设备本地只种了系统清单,outbox 是空的;但用户能在 splash 关掉后立刻
  // 写本地。如果首次 pull 还没成功就放行 UI,云端旧数据会在稍后 pull 时
  // insertOnConflictUpdate 进来,跟用户刚写的混在一起,LWW 可能让用户白写。
  // 这里直接 await pullOnce(),失败就抛错让 UI 拦住,不进入正常自动同步循环。
  final outbox = ref.read(outboxRepositoryProvider);
  final statusController = ref.read(syncStatusControllerProvider.notifier);
  final firstSyncDone =
      (await outbox.getCursor(SyncCursorKey.firstSyncDone)) == 'true';

  if (!firstSyncDone) {
    statusController.set(SyncStatus.syncing);
    final result = await ref.read(syncEngineProvider).pullOnce();
    statusController.set(result);
    if (result != SyncStatus.idle) {
      throw FirstSyncFailedException(result);
    }
    await outbox.setCursor(SyncCursorKey.firstSyncDone, 'true');
  }

  // 门通过后才接管自动同步;此时再 runFullSync 一次会拉到几乎为空的 delta
  // (cursor 已被首次 pull 推到最新),开销可忽略。
  final coord = ref.read(syncCoordinatorProvider)..start();
  unawaited(coord.runFullSync());
}
