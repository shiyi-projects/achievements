import 'dart:async';

import 'package:achievements/core/notifications/notification_service.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reminder_scheduler.g.dart';

/// 监听 "remind_at 非空且仍活跃" 的任务流,reconcile 本地通知排程。
///
/// - 新增 / 改时间 / 改标题:重新 schedule(notify plugin 用 id 覆盖)
/// - 完成 / 软删 / 清空 remind_at:从下次流中消失 → cancel
///
/// Notification id 由 task.id (UUIDv7) 的稳定 32-bit 散列得到;UUID 全局
/// 唯一,碰撞概率忽略。后续若需要绝对避碰,可在 Drift 加一个
/// `task_id ↔ int_id` 映射表。
class ReminderScheduler {
  ReminderScheduler({
    required NotificationService notifications,
    required TaskRepository tasks,
  }) : _notifications = notifications,
       _tasks = tasks;

  final NotificationService _notifications;
  final TaskRepository _tasks;

  StreamSubscription<List<Task>>? _sub;
  Set<int> _scheduledIds = const <int>{};

  void start() {
    _sub?.cancel();
    _sub = _tasks.watchTasksWithActiveReminders().listen(_reconcile);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _notifications.cancelAll();
    _scheduledIds = const <int>{};
  }

  Future<void> _reconcile(List<Task> tasks) async {
    final next = <int>{};
    for (final task in tasks) {
      final at = task.remindAt;
      if (at == null) continue;
      final id = _idFor(task.id);
      next.add(id);
      await _notifications.schedule(
        id: id,
        when: at,
        title: task.title,
        body: task.notes,
        payload: task.id,
      );
    }
    // 上轮排过但本轮不再需要的(完成 / 软删 / 清空 remind_at)→ cancel
    for (final stale in _scheduledIds.difference(next)) {
      await _notifications.cancel(stale);
    }
    _scheduledIds = next;
  }

  static int _idFor(String taskId) => taskId.hashCode & 0x7fffffff;
}

@Riverpod(keepAlive: true)
ReminderScheduler reminderScheduler(Ref ref) {
  final scheduler = ReminderScheduler(
    notifications: ref.read(notificationServiceProvider),
    tasks: ref.read(taskRepositoryProvider),
  );
  ref.onDispose(scheduler.stop);
  return scheduler;
}
