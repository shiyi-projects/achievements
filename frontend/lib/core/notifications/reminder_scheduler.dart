import 'dart:async';

import 'package:achievements/core/id.dart';
import 'package:achievements/core/notifications/notification_service.dart';
import 'package:achievements/core/recurrence/recurrence_service.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reminder_scheduler.g.dart';

/// 一条期望排程的提醒(纯数据,供 reconcile 计算与单测)。
@immutable
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.payload,
    this.body,
  });

  final int id;
  final DateTime when;
  final String title;
  final String? body;
  final String payload;

  @override
  bool operator ==(Object other) =>
      other is ScheduledReminder &&
      other.id == id &&
      other.when == when &&
      other.title == title &&
      other.body == body &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, when, title, body, payload);
}

/// 监听任务流,reconcile 本地通知排程。两条数据源:
///
/// 1. **普通提醒**:`remind_at` 非空且活跃的真实任务(一次性任务 + 已实体化 override)。
///    重复模板(repeat_rule 非空)从此路径**排除**,由路径 2 统一展开,避免锚点被重复排程。
/// 2. **重复提醒**:对每个有提醒的模板,在未来窗口([_windowDays] 天)内虚拟展开发生点,
///    逐个排程;已实体化 / 已删除的发生点跳过(前者由路径 1 覆盖,后者是 EXDATE)。
///
/// Notification id 由 UUID 字符串的稳定 32-bit 散列得到:普通任务用 task.id,重复发生点
/// 用确定性 [occurrenceId](模板 id + 发生点)。窗口随 app 启动 / 数据变更滚动前移。
class ReminderScheduler {
  ReminderScheduler({
    required NotificationService notifications,
    required TaskRepository tasks,
    required RecurrenceService recurrence,
  }) : _notifications = notifications,
       _tasks = tasks,
       _recurrence = recurrence;

  final NotificationService _notifications;
  final TaskRepository _tasks;
  final RecurrenceService _recurrence;

  /// 重复提醒展开窗口(天)。
  static const int _windowDays = 60;

  /// 每个模板最多排程的发生点数(防御 Android pending 通知上限)。
  static const int _maxPerTemplate = 40;

  /// 流连续触发(增删改一次任务常同时触动两条流)时合并 reconcile 的去抖时长。
  static const Duration _debounceDelay = Duration(milliseconds: 250);

  StreamSubscription<List<Task>>? _reminderSub;
  StreamSubscription<List<Task>>? _recurringSub;
  Timer? _debounce;

  List<Task> _activeReminders = const [];
  List<Task> _recurringRows = const [];

  /// 当前已排程的通知:id → 内容。用于增量 reconcile(只动新增/变化/消失的)。
  Map<int, ScheduledReminder> _scheduled = const {};

  void start() {
    _reminderSub?.cancel();
    _recurringSub?.cancel();
    _reminderSub = _tasks.watchTasksWithActiveReminders().listen((rows) {
      _activeReminders = rows;
      _scheduleReconcile();
    });
    _recurringSub = _tasks.watchRecurring().listen((rows) {
      _recurringRows = rows;
      _scheduleReconcile();
    });
  }

  Future<void> stop() async {
    _debounce?.cancel();
    _debounce = null;
    await _reminderSub?.cancel();
    await _recurringSub?.cancel();
    _reminderSub = null;
    _recurringSub = null;
    await _notifications.cancelAll();
    _activeReminders = const [];
    _recurringRows = const [];
    _scheduled = const {};
  }

  void _scheduleReconcile() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => unawaited(_reconcile()));
  }

  /// 增量 reconcile:只对**新增 / 内容变化**的发生点重排,对**消失**的取消,其余跳过。
  /// 避免任一任务增删改时全量重排(几十~上百次跨 channel 调用)造成卡顿。
  Future<void> _reconcile() async {
    final desired = computeSchedule(
      activeReminders: _activeReminders,
      recurringRows: _recurringRows,
      now: DateTime.now(),
      recurrence: _recurrence,
    );
    final next = {for (final r in desired) r.id: r};

    // 新增或内容变化 → schedule(覆盖)
    for (final r in desired) {
      if (_scheduled[r.id] != r) {
        await _notifications.schedule(
          id: r.id,
          when: r.when,
          title: r.title,
          body: r.body,
          payload: r.payload,
        );
      }
    }
    // 本轮不再需要的 → cancel
    for (final id in _scheduled.keys) {
      if (!next.containsKey(id)) await _notifications.cancel(id);
    }
    _scheduled = next;
  }

  /// 纯计算:根据普通提醒任务与重复行,算出期望排程的提醒列表。无副作用,可单测。
  static List<ScheduledReminder> computeSchedule({
    required List<Task> activeReminders,
    required List<Task> recurringRows,
    required DateTime now,
    required RecurrenceService recurrence,
    int windowDays = _windowDays,
    int maxPerTemplate = _maxPerTemplate,
  }) {
    final out = <ScheduledReminder>[];
    final seen = <int>{};

    void put(ScheduledReminder r) {
      if (seen.add(r.id)) out.add(r);
    }

    // ── 路径 1:普通提醒(排除重复模板,其由路径 2 展开)──
    for (final task in activeReminders) {
      final at = task.remindAt;
      if (at == null) continue;
      if (task.repeatRule != null) continue;
      if (at.isBefore(now)) continue; // 过期提醒不再排程
      put(
        ScheduledReminder(
          id: _idFor(task.id),
          when: at,
          title: task.title,
          body: task.notes,
          payload: task.id,
        ),
      );
    }

    // ── 路径 2:重复提醒(虚拟展开未来窗口)──
    final overrideIdsByParent = <String, Set<String>>{};
    for (final row in recurringRows) {
      final pid = row.recurrenceParentId;
      if (pid != null) {
        overrideIdsByParent.putIfAbsent(pid, () => {}).add(row.id);
      }
    }

    final windowEnd = now.add(Duration(days: windowDays));
    for (final tpl in recurringRows) {
      if (tpl.repeatRule == null ||
          tpl.recurrenceParentId != null ||
          tpl.deletedAt != null ||
          tpl.remindAt == null ||
          tpl.dueAt == null) {
        continue;
      }
      final offset = tpl.remindAt!.difference(tpl.dueAt!);
      final dates = recurrence.expand(
        rule: tpl.repeatRule!,
        dtStart: tpl.dueAt!,
        from: now,
        to: windowEnd,
        max: maxPerTemplate,
      );
      final overrideIds = overrideIdsByParent[tpl.id] ?? const <String>{};
      for (final d in dates) {
        // 已实体化(路径 1 覆盖)或已删除(EXDATE)的发生点跳过。
        if (overrideIds.contains(occurrenceId(tpl.id, d))) continue;
        final remindAt = d.add(offset);
        if (remindAt.isBefore(now)) continue;
        put(
          ScheduledReminder(
            id: _idFor(occurrenceId(tpl.id, d)),
            when: remindAt,
            title: tpl.title,
            body: tpl.notes,
            payload: tpl.id,
          ),
        );
      }
    }
    return out;
  }

  static int _idFor(String key) => key.hashCode & 0x7fffffff;
}

@Riverpod(keepAlive: true)
ReminderScheduler reminderScheduler(Ref ref) {
  final scheduler = ReminderScheduler(
    notifications: ref.read(notificationServiceProvider),
    tasks: ref.read(taskRepositoryProvider),
    recurrence: ref.read(recurrenceServiceProvider),
  );
  ref.onDispose(scheduler.stop);
  return scheduler;
}
