import 'dart:async';

import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/focus_plan_repository.dart';
import 'package:achievements/data/repositories/focus_session_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/focus/providers/focus_plan_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'focus_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain enums
// ─────────────────────────────────────────────────────────────────────────────

/// 专注计时模式。
enum FocusMode {
  /// 番茄钟模式：固定工作 + 休息时长。
  pomodoro,

  /// 自由模式：只计时不倒计时。
  free,
}

/// 专注阶段。
enum FocusPhase {
  /// 空闲，尚未开始。
  idle,

  /// 专注工作中（番茄 or 自由）。
  working,

  /// 休息倒计时中（番茄专属）。
  shortBreak,

  /// 当前阶段已结束，等待用户下一步操作。
  done,
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

/// 专注计时器的完整状态快照（普通 Dart 类，无 Freezed）。
class FocusTimerState {
  const FocusTimerState({
    required this.mode,
    required this.phase,
    required this.remaining,
    required this.elapsed,
    required this.isRunning,
    required this.workDuration,
    required this.breakDuration,
    required this.completedPomodoros,
    this.taskId,
  });

  /// 默认初始状态：番茄钟，空闲，25 分钟。
  factory FocusTimerState.initial() => const FocusTimerState(
        mode: FocusMode.pomodoro,
        phase: FocusPhase.idle,
        remaining: Duration(minutes: 25),
        elapsed: Duration.zero,
        isRunning: false,
        workDuration: Duration(minutes: 25),
        breakDuration: Duration(minutes: 5),
        completedPomodoros: 0,
      );

  final FocusMode mode;
  final FocusPhase phase;

  /// 番茄钟剩余时长（倒计时）；空闲时等于 [workDuration]。
  final Duration remaining;

  /// 自由模式已过时长（正计时）。
  final Duration elapsed;

  final bool isRunning;

  /// 关联的任务 UUID（可选）。
  final String? taskId;

  final Duration workDuration;
  final Duration breakDuration;

  /// 本次 session 内已完整完成的番茄轮数。
  final int completedPomodoros;

  FocusTimerState copyWith({
    FocusMode? mode,
    FocusPhase? phase,
    Duration? remaining,
    Duration? elapsed,
    bool? isRunning,
    String? taskId,
    bool clearTaskId = false,
    Duration? workDuration,
    Duration? breakDuration,
    int? completedPomodoros,
  }) {
    return FocusTimerState(
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      remaining: remaining ?? this.remaining,
      elapsed: elapsed ?? this.elapsed,
      isRunning: isRunning ?? this.isRunning,
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      workDuration: workDuration ?? this.workDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class FocusTimer extends _$FocusTimer {
  Timer? _ticker;
  DateTime? _sessionStartedAt;

  @override
  FocusTimerState build() {
    // 销毁时清理定时器
    ref.onDispose(_cancelTicker);
    return FocusTimerState.initial();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// 切换专注模式（仅在 idle 阶段有效）。
  void setMode(FocusMode mode) {
    if (state.phase != FocusPhase.idle) return;
    state = state.copyWith(
      mode: mode,
      remaining: state.workDuration,
      elapsed: Duration.zero,
    );
  }

  /// 设置工作时长（仅在 idle 阶段有效）。
  void setWorkDuration(Duration duration) {
    if (state.phase != FocusPhase.idle) return;
    state = state.copyWith(
      workDuration: duration,
      remaining: duration,
    );
  }

  /// 设置休息时长（仅在 idle 阶段有效）。
  void setBreakDuration(Duration duration) {
    if (state.phase != FocusPhase.idle) return;
    state = state.copyWith(breakDuration: duration);
  }

  /// 设置关联任务 ID（null 表示解除关联）。
  ///
  /// 专注中（working / shortBreak）不允许切换任务。
  /// 若当前为番茄钟模式 + idle 阶段，尝试根据任务的
  /// [estimatedMinutes] 和 [dueAt] 智能计算每日专注时长。
  void setTask(String? taskId) {
    // 专注中锁定，不允许切换
    if (state.phase == FocusPhase.working ||
        state.phase == FocusPhase.shortBreak) {
      return;
    }

    if (taskId == null) {
      state = state.copyWith(clearTaskId: true);
    } else {
      state = state.copyWith(taskId: taskId);
      // 智能调整番茄钟时长
      if (state.mode == FocusMode.pomodoro && state.phase == FocusPhase.idle) {
        _autoAdjustDuration(taskId);
      }
    }
  }

  /// 根据任务的预估时长、已专注时长、截止日自动设置 workDuration。
  Future<void> _autoAdjustDuration(String taskId) async {
    final task = await ref.read(taskRepositoryProvider).getById(taskId);
    if (task == null) return;

    final estimated = task.estimatedMinutes;
    if (estimated == null || estimated <= 0) return;

    // 剩余工作量（分钟）
    final focusedMinutes = (task.focusedSeconds / 60).floor();
    final remainingMinutes = (estimated - focusedMinutes).clamp(1, estimated);

    int dailyMinutes;
    final dueAt = task.dueAt;
    if (dueAt != null) {
      // 有截止日：剩余量 ÷ 剩余天数
      final remainingDays = dueAt.difference(DateTime.now()).inDays.clamp(1, 365);
      dailyMinutes = (remainingMinutes / remainingDays).ceil().clamp(5, 90);
    } else {
      // 无截止日：取剩余量和 45 分钟的较小值
      dailyMinutes = remainingMinutes.clamp(5, 45);
    }

    setWorkDuration(Duration(minutes: dailyMinutes));
  }

  /// 开始 / 继续计时。
  void start() {
    if (state.isRunning) return;
    if (state.phase == FocusPhase.done) return;

    // 第一次开始时记录会话起始时间
    if (state.phase == FocusPhase.idle) {
      _sessionStartedAt = DateTime.now();
      state = state.copyWith(
        phase: FocusPhase.working,
        isRunning: true,
        elapsed: Duration.zero,
        remaining: state.workDuration,
      );
    } else {
      // 从 pause 恢复
      state = state.copyWith(isRunning: true);
    }

    _startTicker();
  }

  /// 暂停计时。
  void pause() {
    if (!state.isRunning) return;
    _cancelTicker();
    state = state.copyWith(isRunning: false);
  }

  /// 停止并保存会话记录。
  Future<void> stop() async {
    _cancelTicker();
    final endedAt = DateTime.now();
    final startedAt = _sessionStartedAt ?? endedAt;

    final durationSeconds = state.mode == FocusMode.free
        ? state.elapsed.inSeconds
        : state.workDuration.inSeconds - state.remaining.inSeconds;

    if (durationSeconds > 0) {
      await _saveSession(
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
        completed: false,
      );
    }

    _sessionStartedAt = null;
    state = FocusTimerState.initial().copyWith(
      taskId: state.taskId,
      mode: state.mode,
    );
  }

  /// 工作阶段结束后开始休息倒计时（番茄钟专用）。
  void startBreak() {
    if (state.mode != FocusMode.pomodoro) return;
    if (state.phase != FocusPhase.done) return;

    _sessionStartedAt = DateTime.now();
    state = state.copyWith(
      phase: FocusPhase.shortBreak,
      remaining: state.breakDuration,
      isRunning: true,
    );
    _startTicker();
  }

  /// 重置到 idle 初始状态（保留模式和任务关联）。
  void reset() {
    _cancelTicker();
    _sessionStartedAt = null;
    state = FocusTimerState.initial().copyWith(
      mode: state.mode,
      taskId: state.taskId,
    );
  }

  // ── Timer internals ────────────────────────────────────────────────────────

  void _startTicker() {
    _cancelTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick() {
    if (!state.isRunning) return;

    switch (state.mode) {
      case FocusMode.pomodoro:
        _tickPomodoro();
      case FocusMode.free:
        _tickFree();
    }
  }

  void _tickPomodoro() {
    final newRemaining = state.remaining - const Duration(seconds: 1);

    if (newRemaining <= Duration.zero) {
      _cancelTicker();

      if (state.phase == FocusPhase.working) {
        // 工作阶段完成 → 保存会话，进入 done 等待用户选择
        final endedAt = DateTime.now();
        final startedAt = _sessionStartedAt ?? endedAt;
        // fire-and-forget: timer tick 不能 await，忽略 future
        unawaited(
          _saveSession(
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: state.workDuration.inSeconds,
            completed: true,
          ),
        );
        _sessionStartedAt = null;

        state = state.copyWith(
          remaining: Duration.zero,
          isRunning: false,
          phase: FocusPhase.done,
        );
      } else if (state.phase == FocusPhase.shortBreak) {
        // 休息结束 → 回到 idle，累加完成次数
        state = state.copyWith(
          remaining: state.workDuration,
          isRunning: false,
          phase: FocusPhase.idle,
          completedPomodoros: state.completedPomodoros + 1,
        );
        _sessionStartedAt = null;
      }
    } else {
      state = state.copyWith(remaining: newRemaining);
    }
  }

  void _tickFree() {
    state = state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1));
  }

  Future<void> _saveSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required bool completed,
  }) async {
    final repo = ref.read(focusSessionRepositoryProvider);
    await repo.save(
      taskId: state.taskId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      mode: state.mode == FocusMode.pomodoro ? 'pomodoro' : 'free',
      completed: completed,
    );

    // 联动专注计划：累加实际时长
    final planService = ref.read(focusPlanServiceProvider);
    await planService.onSessionComplete(
      taskId: state.taskId,
      durationSeconds: durationSeconds,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan-related providers
// ─────────────────────────────────────────────────────────────────────────────

/// 今日专注计划列表。
@riverpod
Stream<List<FocusPlan>> todayFocusPlans(Ref ref) {
  return ref.watch(focusPlanRepositoryProvider).watchTodayPlans();
}

/// 过期未完成计划（近 7 天）。
@riverpod
Stream<List<FocusPlan>> overdueFocusPlans(Ref ref) {
  return ref.watch(focusPlanRepositoryProvider).watchOverduePlans();
}
