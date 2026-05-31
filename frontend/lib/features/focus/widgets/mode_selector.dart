import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 番茄钟 / 自由模式切换选择器。
///
/// M3 Segmented 风格：滑动指示条动画 + 半透明玻璃容器。
/// 仅在 [FocusPhase.idle] 时可交互。
class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  static const _modes = [
    (FocusMode.pomodoro, '番茄钟', Icons.timer_outlined),
    (FocusMode.free, '自由模式', Icons.all_inclusive_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusTimerProvider);
    final notifier = ref.read(focusTimerProvider.notifier);
    final isEnabled = state.phase == FocusPhase.idle;
    final selectedIndex = _modes.indexWhere((m) => m.$1 == state.mode);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      opacity: isEnabled ? 1.0 : 0.4,
      duration: MotionDurations.fast,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.button),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _modes.length;
              return Stack(
                children: [
                  // ── 滑动指示条 ──
                  AnimatedPositioned(
                    duration: MotionDurations.normal,
                    curve: MotionCurves.gentleSpring,
                    left: selectedIndex * itemWidth,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(Radii.button - 3),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  // ── 标签按钮 ──
                  Row(
                    children: [
                      for (var i = 0; i < _modes.length; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => notifier.setMode(_modes[i].$1),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Spacing.sm + 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _modes[i].$3,
                                    size: 16,
                                    color: selectedIndex == i
                                        ? scheme.onSurface
                                        : scheme.onSurface.withValues(
                                            alpha: 0.5,
                                          ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _modes[i].$2,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selectedIndex == i
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: selectedIndex == i
                                          ? scheme.onSurface
                                          : scheme.onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
