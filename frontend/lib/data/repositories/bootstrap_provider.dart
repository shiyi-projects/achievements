import 'package:achievements/core/notifications/notification_service.dart';
import 'package:achievements/core/notifications/reminder_scheduler.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap_provider.g.dart';

/// 应用启动期一次性初始化:
///   1. 种入系统清单(幂等)
///   2. 初始化 NotificationService(时区 + Android 通道)并尝试申请权限
///   3. 启动 ReminderScheduler:watch 待提醒任务流并 reconcile 本地排程
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
}
