import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 专注计时器操作按钮组。
///
/// 根据当前 [FocusPhase] 和 [FocusMode] 动态渲染不同按钮组合：
///
/// - **idle**：「开始专注」大按钮
/// - **working（运行中）**：「暂停」+ 「放弃」
/// - **working（已暂停）**：「继续」+ 「放弃」
/// - **done（番茄工作完成）**：「开始休息」+ 「跳过」
/// - **done（自由模式结束）**：「再来一轮」
/// - **shortBreak（运行中）**：「暂停休息」+ 「跳过休息」
/// - **shortBreak（已暂停）**：「继续」+ 「跳过休息」
class TimerControls extends ConsumerWidget {
  const TimerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusTimerProvider);
    final notifier = ref.read(focusTimerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
      child: _buildButtons(context, state, notifier),
    );
  }

  Widget _buildButtons(
    BuildContext context,
    FocusTimerState state,
    FocusTimer notifier,
  ) {
    return switch (state.phase) {
      FocusPhase.idle => _IdleButtons(notifier: notifier),
      FocusPhase.working => state.isRunning
          ? _RunningButtons(notifier: notifier)
          : _PausedButtons(notifier: notifier),
      FocusPhase.shortBreak => state.isRunning
          ? _BreakRunningButtons(notifier: notifier)
          : _BreakPausedButtons(notifier: notifier),
      FocusPhase.done => state.mode == FocusMode.pomodoro
          ? _PomodoroWorkDoneButtons(notifier: notifier)
          : _FreeDoneButtons(notifier: notifier),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Button group variants
// ─────────────────────────────────────────────────────────────────────────────

class _IdleButtons extends StatelessWidget {
  const _IdleButtons({required this.notifier});
  final FocusTimer notifier;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: notifier.start,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Text('开始专注', style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}

class _RunningButtons extends StatelessWidget {
  const _RunningButtons({required this.notifier});
  final FocusTimer notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: notifier.pause,
            child: const Text('暂停'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: FilledButton.tonal(
            onPressed: notifier.stop,
            child: const Text('放弃'),
          ),
        ),
      ],
    );
  }
}

class _PausedButtons extends StatelessWidget {
  const _PausedButtons({required this.notifier});
  final FocusTimer notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: notifier.start,
            child: const Text('继续'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: OutlinedButton(
            onPressed: notifier.stop,
            child: const Text('放弃'),
          ),
        ),
      ],
    );
  }
}

class _BreakRunningButtons extends StatelessWidget {
  const _BreakRunningButtons({required this.notifier});
  final FocusTimer notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: notifier.pause,
            child: const Text('暂停休息'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: FilledButton.tonal(
            onPressed: notifier.reset,
            child: const Text('跳过休息'),
          ),
        ),
      ],
    );
  }
}

class _BreakPausedButtons extends StatelessWidget {
  const _BreakPausedButtons({required this.notifier});
  final FocusTimer notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: notifier.start,
            child: const Text('继续'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: OutlinedButton(
            onPressed: notifier.reset,
            child: const Text('跳过休息'),
          ),
        ),
      ],
    );
  }
}

class _PomodoroWorkDoneButtons extends StatelessWidget {
  const _PomodoroWorkDoneButtons({required this.notifier});
  final FocusTimer notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: notifier.startBreak,
            child: const Text('开始休息'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: OutlinedButton(
            onPressed: notifier.reset,
            child: const Text('跳过'),
          ),
        ),
      ],
    );
  }
}

class _FreeDoneButtons extends StatelessWidget {
  const _FreeDoneButtons({required this.notifier});
  final FocusTimer notifier;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: notifier.reset,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Text('再来一轮', style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}
