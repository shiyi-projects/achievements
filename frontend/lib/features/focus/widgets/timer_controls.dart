import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 专注计时器操作按钮组。
///
/// 根据当前 [FocusPhase] 和 [FocusMode] 动态渲染不同按钮组合：
///
/// - **idle**：「开始专注」大按钮 + 脉冲发光
/// - **working / shortBreak（运行中）**：大圆暂停 + 两侧小圆放弃/跳过
/// - **working / shortBreak（已暂停）**：大圆继续 + 两侧小圆放弃/跳过
/// - **done（番茄）**：「开始休息」+「跳过」
/// - **done（自由）**：「再来一轮」
class TimerControls extends ConsumerWidget {
  const TimerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusTimerProvider);
    final notifier = ref.read(focusTimerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
      child: AnimatedSwitcher(
        duration: MotionDurations.normal,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: _buildButtons(context, state, notifier),
      ),
    );
  }

  Widget _buildButtons(
    BuildContext context,
    FocusTimerState state,
    FocusTimer notifier,
  ) {
    return switch (state.phase) {
      FocusPhase.idle => _StartButton(
          key: const ValueKey('idle'),
          notifier: notifier,
        ),
      FocusPhase.working => _CircularControls(
          key: const ValueKey('working'),
          isRunning: state.isRunning,
          onMainTap: state.isRunning ? notifier.pause : notifier.start,
          mainIcon: state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          mainLabel: state.isRunning ? '暂停' : '继续',
          onSecondary: notifier.stop,
          secondaryIcon: Icons.stop_rounded,
          secondaryLabel: '放弃',
        ),
      FocusPhase.shortBreak => _CircularControls(
          key: const ValueKey('break'),
          isRunning: state.isRunning,
          onMainTap: state.isRunning ? notifier.pause : notifier.start,
          mainIcon: state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          mainLabel: state.isRunning ? '暂停' : '继续',
          onSecondary: notifier.reset,
          secondaryIcon: Icons.skip_next_rounded,
          secondaryLabel: '跳过',
        ),
      FocusPhase.done => state.mode == FocusMode.pomodoro
          ? _DoneButtons(
              key: const ValueKey('done-pomo'),
              onBreak: notifier.startBreak,
              onSkip: notifier.reset,
            )
          : _StartButton(
              key: const ValueKey('done-free'),
              notifier: notifier,
              label: '再来一轮',
              onTap: notifier.reset,
            ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start button with pulsing glow
// ─────────────────────────────────────────────────────────────────────────────

class _StartButton extends StatefulWidget {
  const _StartButton({
    super.key,
    required this.notifier,
    this.label = '开始专注',
    this.onTap,
  });

  final FocusTimer notifier;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, child) {
        final glowOpacity = 0.15 + _glowCtrl.value * 0.2;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.button),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: glowOpacity),
                blurRadius: 20 + _glowCtrl.value * 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: FilledButton(
        onPressed: widget.onTap ?? widget.notifier.start,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: Spacing.md + 2),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(widget.label),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circular controls: big center + small sides
// ─────────────────────────────────────────────────────────────────────────────

class _CircularControls extends StatelessWidget {
  const _CircularControls({
    super.key,
    required this.isRunning,
    required this.onMainTap,
    required this.mainIcon,
    required this.mainLabel,
    required this.onSecondary,
    required this.secondaryIcon,
    required this.secondaryLabel,
  });

  final bool isRunning;
  final VoidCallback onMainTap;
  final IconData mainIcon;
  final String mainLabel;
  final VoidCallback onSecondary;
  final IconData secondaryIcon;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── 次要按钮 ──
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CircleButton(
              size: 48,
              icon: secondaryIcon,
              color: scheme.onSurface.withValues(alpha: 0.1),
              iconColor: scheme.onSurface.withValues(alpha: 0.6),
              onTap: onSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              secondaryLabel,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(width: Spacing.xxl),
        // ── 主按钮 ──
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CircleButton(
              size: 72,
              icon: mainIcon,
              color: scheme.primary.withValues(alpha: 0.2),
              iconColor: scheme.onSurface,
              borderColor: scheme.primary.withValues(alpha: 0.5),
              iconSize: 36,
              onTap: onMainTap,
            ),
            const SizedBox(height: 6),
            Text(
              mainLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(width: Spacing.xxl),
        // ── 占位（保持对称） ──
        const SizedBox(width: 48, height: 48),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.size,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    this.borderColor,
    this.iconSize = 24,
  });

  final double size;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final Color? borderColor;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Done buttons (pomodoro complete)
// ─────────────────────────────────────────────────────────────────────────────

class _DoneButtons extends StatelessWidget {
  const _DoneButtons({
    super.key,
    required this.onBreak,
    required this.onSkip,
  });

  final VoidCallback onBreak;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: onBreak,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
            ),
            child: const Text('开始休息'),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: OutlinedButton(
            onPressed: onSkip,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              side: BorderSide(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
              foregroundColor: scheme.onSurface.withValues(alpha: 0.7),
            ),
            child: const Text('跳过'),
          ),
        ),
      ],
    );
  }
}
