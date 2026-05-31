import 'dart:async';
import 'dart:io';

import 'package:achievements/core/notifications/reminder_alarm_screen.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// 前台提醒检测器。
///
/// 监听数据库中所有「remindAt 非空、未完成、未删除」的任务流，
/// 对每个任务精确安排 [Timer]，到点弹出全屏闹钟界面。
///
/// 流程：
///   1. watch 任务流 → 收到变更时 reconcile
///   2. 未来提醒 → 安排 Timer（精确到毫秒）
///   3. 已过期提醒 → 立即加入弹出队列
///   4. 依次弹出队列中的闹钟（一次一个）
///
/// - Windows：通过 `window_manager` 将窗口置顶并激活。
/// - 已弹过的任务 ID 记录在 `_shownIds` 中，避免重复弹出。
class ReminderChecker extends ConsumerStatefulWidget {
  const ReminderChecker({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderChecker> createState() => _ReminderCheckerState();
}

class _ReminderCheckerState extends ConsumerState<ReminderChecker>
    with WidgetsBindingObserver {
  StreamSubscription<List<Task>>? _subscription;

  /// taskId → 定时器
  final _timers = <String, Timer>{};

  /// 待弹出的提醒队列
  final _pendingQueue = <Task>[];

  /// 已弹过的任务 ID（生命周期内不重复弹）
  final _shownIds = <String>{};

  bool _isShowingAlarm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 延迟订阅，确保 bootstrap 已完成
    Future<void>.delayed(const Duration(seconds: 2), _startWatching);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('[ReminderChecker] ❌ dispose — 已取消所有定时器');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[ReminderChecker] 📱 App resumed — 重新 reconcile');
      // App 回到前台时重新检查（Timer 在后台可能不精确）
      _startWatching();
    }
  }

  void _startWatching() {
    _subscription?.cancel();
    final repo = ref.read(taskRepositoryProvider);
    _subscription = repo.watchTasksWithActiveReminders().listen(
      _reconcile,
      onError: (Object e) {
        debugPrint('[ReminderChecker] ❗ Stream error: $e');
      },
    );
    debugPrint('[ReminderChecker] ✅ 开始监听提醒任务流');
  }

  /// 核心 reconcile：对比当前任务列表与已安排的定时器。
  void _reconcile(List<Task> tasks) {
    final now = DateTime.now();
    final activeIds = <String>{};

    debugPrint(
      '[ReminderChecker] 🔄 reconcile: ${tasks.length} 条活跃提醒, '
      '${_timers.length} 个定时器, ${_shownIds.length} 个已弹',
    );

    for (final task in tasks) {
      final remindAt = task.remindAt;
      if (remindAt == null) continue;
      activeIds.add(task.id);

      // 已弹过 → 跳过
      if (_shownIds.contains(task.id)) continue;

      final delay = remindAt.difference(now);

      if (delay.isNegative || delay == Duration.zero) {
        // 已过期 → 立即加入弹出队列
        debugPrint(
          '[ReminderChecker] ⏰ 已过期: "${task.title}" '
          '(remindAt=$remindAt, 过期${delay.inSeconds.abs()}秒)',
        );
        _enqueue(task);
      } else {
        // 未来 → 安排精确定时器
        if (!_timers.containsKey(task.id)) {
          debugPrint(
            '[ReminderChecker] ⏳ 安排定时器: "${task.title}" '
            '(${delay.inMinutes}分${delay.inSeconds % 60}秒后)',
          );
          final taskId = task.id;
          _timers[taskId] = Timer(delay, () async {
            debugPrint('[ReminderChecker] 🔔 定时器触发: taskId=$taskId');
            _timers.remove(taskId);
            // 重查 DB:Timer 触发瞬间任务可能刚被完成,stream emit 还在路上,
            // 不能直接用闭包里的旧 task 去 enqueue。
            if (!mounted) return;
            final fresh = await ref
                .read(taskRepositoryProvider)
                .getById(taskId);
            if (fresh == null ||
                fresh.completedAt != null ||
                fresh.deletedAt != null ||
                fresh.remindAt == null) {
              debugPrint('[ReminderChecker] ⏭ 定时器触发但任务已失效,跳过: taskId=$taskId');
              return;
            }
            _enqueue(fresh);
          });
        }
      }
    }

    // 取消不再活跃的定时器（任务被完成/删除/清空提醒）
    final staleIds = _timers.keys.toSet().difference(activeIds);
    for (final id in staleIds) {
      debugPrint('[ReminderChecker] 🗑 取消定时器: taskId=$id');
      _timers.remove(id)?.cancel();
    }

    // 同时把 pendingQueue 里已经不活跃的任务剔除掉。否则前面 alarm 还在显示
    // 的窗口期里,用户(或其他设备同步过来)把任务完成了,轮到它出队仍会弹。
    final beforeQueue = _pendingQueue.length;
    _pendingQueue.removeWhere((t) => !activeIds.contains(t.id));
    if (_pendingQueue.length != beforeQueue) {
      debugPrint(
        '[ReminderChecker] 🧹 清理 pendingQueue: '
        '${beforeQueue - _pendingQueue.length} 条已完成/删除',
      );
    }
  }

  /// 将任务加入弹出队列，并尝试处理队列。
  void _enqueue(Task task) {
    if (_shownIds.contains(task.id)) return;
    if (_pendingQueue.any((t) => t.id == task.id)) return;
    _pendingQueue.add(task);
    _processQueue();
  }

  /// 依次弹出队列中的闹钟（一次只显示一个）。
  Future<void> _processQueue() async {
    if (_isShowingAlarm || _pendingQueue.isEmpty || !mounted) return;

    final task = _pendingQueue.removeAt(0);
    if (_shownIds.contains(task.id)) {
      // 可能在排队期间已弹过
      unawaited(Future<void>.microtask(_processQueue));
      return;
    }

    // 弹窗前最后一次复核:从 DB 重新拉,任务可能已被完成/删除/清掉提醒。
    // _reconcile 已尽量清理 pendingQueue,但 stream emit 和 _processQueue 调度
    // 之间仍有可能错过一拍,这里兜底。
    final fresh = await ref.read(taskRepositoryProvider).getById(task.id);
    if (!mounted) return;
    if (fresh == null ||
        fresh.completedAt != null ||
        fresh.deletedAt != null ||
        fresh.remindAt == null) {
      debugPrint('[ReminderChecker] ⏭ 出队时已失效,跳过: "${task.title}"');
      _shownIds.add(task.id); // 防止再次入队
      unawaited(Future<void>.microtask(_processQueue));
      return;
    }

    _shownIds.add(task.id);
    await _showAlarm(fresh);

    // 闹钟关闭后处理下一个
    if (mounted && _pendingQueue.isNotEmpty) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 500), _processQueue),
      );
    }
  }

  Future<void> _showAlarm(Task task) async {
    if (!mounted) return;
    _isShowingAlarm = true;

    // Windows：置顶 + 激活窗口
    if (!kIsWeb && Platform.isWindows) {
      try {
        await windowManager.setAlwaysOnTop(true);
        await windowManager.show();
        await windowManager.focus();
        debugPrint('[ReminderChecker] 🪟 Windows 窗口已置顶');
      } catch (e) {
        debugPrint('[ReminderChecker] Window activation error: $e');
      }
    }

    if (!mounted) return;

    debugPrint('[ReminderChecker] 🔔 弹出闹钟: "${task.title}"');

    // 使用 rootNavigator 确保全屏覆盖在 GoRouter 之上
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, anim, secondAnim) => ReminderAlarmScreen(
          task: task,
          onDismiss: () {
            Navigator.of(ctx, rootNavigator: true).pop();
          },
        ),
        transitionsBuilder: (ctx, anim, secondAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );

    debugPrint('[ReminderChecker] 🔕 闹钟已关闭: "${task.title}"');
    _isShowingAlarm = false;

    // Windows：取消置顶
    if (!kIsWeb && Platform.isWindows) {
      try {
        await windowManager.setAlwaysOnTop(false);
      } catch (e) {
        debugPrint('[ReminderChecker] Window un-pin error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
