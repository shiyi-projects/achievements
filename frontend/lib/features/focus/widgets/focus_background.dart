import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 专注页渐变背景。
///
/// 使用当前主题的 [ColorScheme] 生成柔和渐变。
/// 根据 [FocusPhase] 动态调整色调:
/// - 空闲: surface 基底，微弱 primary 点缀
/// - 工作中: primary 色调渲染加深
/// - 休息: tertiary 色调
/// - 完成: 暖金点缀
class FocusBackground extends ConsumerWidget {
  const FocusBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      focusTimerProvider.select((s) => s.phase),
    );
    final isRunning = ref.watch(
      focusTimerProvider.select((s) => s.isRunning),
    );
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final colors = _colorsForPhase(phase, isRunning, scheme, isLight);

    return AnimatedContainer(
      duration: MotionDurations.xSlow,
      curve: MotionCurves.standard,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: colors,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  List<Color> _colorsForPhase(
    FocusPhase phase,
    bool isRunning,
    ColorScheme scheme,
    bool isLight,
  ) {
    if (isLight) {
      // 亮色模式: 柔和浅渐变
      final base = scheme.surfaceContainerLowest;
      final edge = scheme.surfaceContainerLow;

      return switch (phase) {
        FocusPhase.idle => [
            base,
            Color.lerp(base, scheme.primaryContainer, 0.05)!,
            edge,
          ],
        FocusPhase.working when isRunning => [
            Color.lerp(base, scheme.primaryContainer, 0.12)!,
            Color.lerp(base, scheme.primaryContainer, 0.06)!,
            edge,
          ],
        FocusPhase.working => [
            Color.lerp(base, scheme.surfaceContainerHigh, 0.08)!,
            base,
            edge,
          ],
        FocusPhase.shortBreak => [
            Color.lerp(base, scheme.tertiaryContainer, 0.1)!,
            Color.lerp(base, scheme.tertiaryContainer, 0.04)!,
            edge,
          ],
        FocusPhase.done => [
            Color.lerp(base, const Color(0xFFFFF8E1), 0.15)!,
            Color.lerp(base, const Color(0xFFFFF8E1), 0.06)!,
            edge,
          ],
      };
    } else {
      // 暗色模式: 深色渐变
      final base = scheme.surface;
      final darkEdge = Color.lerp(base, Colors.black, 0.6)!;

      return switch (phase) {
        FocusPhase.idle => [
            Color.lerp(base, Colors.black, 0.3)!,
            Color.lerp(base, Colors.black, 0.4)!,
            darkEdge,
          ],
        FocusPhase.working when isRunning => [
            Color.lerp(base, scheme.primary, 0.08)!,
            Color.lerp(base, Colors.black, 0.35)!,
            darkEdge,
          ],
        FocusPhase.working => [
            Color.lerp(base, scheme.outline, 0.05)!,
            Color.lerp(base, Colors.black, 0.4)!,
            darkEdge,
          ],
        FocusPhase.shortBreak => [
            Color.lerp(base, scheme.tertiary, 0.06)!,
            Color.lerp(base, Colors.black, 0.35)!,
            darkEdge,
          ],
        FocusPhase.done => [
            Color.lerp(base, const Color(0xFFFFD700), 0.06)!,
            Color.lerp(base, Colors.black, 0.35)!,
            darkEdge,
          ],
      };
    }
  }
}
