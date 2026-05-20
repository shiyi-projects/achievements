import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/features/focus/widgets/ambient_particles.dart';
import 'package:achievements/features/focus/widgets/focus_background.dart';
import 'package:achievements/features/focus/widgets/focus_task_panel.dart';
import 'package:achievements/features/focus/widgets/mode_selector.dart';
import 'package:achievements/features/focus/widgets/task_picker.dart';
import 'package:achievements/features/focus/widgets/timer_controls.dart';
import 'package:achievements/features/focus/widgets/timer_display.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 专注模式主页面。
///
/// 桌面端 (≥840dp)：
///   - 空闲时: 左右分栏（左侧任务面板 + 右侧计时器）
///   - 专注中: 全屏计时器（任务面板隐藏）
///
/// 移动端 (<840dp)：
///   - 空闲时: 折叠式任务面板 + 计时器
///   - 专注中: 仅计时器
///
/// 底层: 渐变背景 + 浮游粒子
class FocusPage extends ConsumerWidget {
  const FocusPage({super.key});

  static const _desktopBreakpoint = 840.0;
  static const _panelWidth = 360.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(focusTimerProvider.select((s) => s.phase));
    final isActive = phase == FocusPhase.working ||
        phase == FocusPhase.shortBreak;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        return Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 0: 渐变背景 ──
            const FocusBackground(),

            // ── Layer 1: 浮游粒子 ──
            const AmbientParticles(),

            // ── Layer 2: 内容 ──
            SafeArea(
              child: isDesktop
                  ? _DesktopLayout(
                      panelWidth: _panelWidth,
                      isActive: isActive,
                    )
                  : _MobileLayout(isActive: isActive),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop: left-right split (隐藏面板 when active)
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.panelWidth,
    required this.isActive,
  });

  final double panelWidth;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: MotionDurations.normal,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      child: isActive
          // ── 专注中：全屏计时器 ──
          ? const _TimerSection(key: ValueKey('timer-only'))
          // ── 空闲：左右分栏 ──
          : Row(
              key: const ValueKey('split'),
              children: [
                // 左侧: 任务面板
                SizedBox(
                  width: panelWidth,
                  child: Container(
                    margin: const EdgeInsets.all(Spacing.base),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(Radii.card),
                      border: Border.all(
                        color: scheme.onSurface.withValues(alpha: 0.06),
                      ),
                    ),
                    child: const FocusTaskPanel(),
                  ),
                ),
                // 分隔线
                Container(
                  width: 1,
                  color: scheme.onSurface.withValues(alpha: 0.04),
                ),
                // 右侧: 计时器
                const Expanded(child: _TimerSection()),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile: vertical stack
// ─────────────────────────────────────────────────────────────────────────────

class _MobileLayout extends StatefulWidget {
  const _MobileLayout({required this.isActive});
  final bool isActive;

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  bool _panelExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.lg,
      ),
      child: Column(
        children: [
          // ── 任务面板（专注中隐藏） ──
          if (!widget.isActive) ...[
            GestureDetector(
              onTap: () => setState(() => _panelExpanded = !_panelExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 16,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '选择专注任务',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _panelExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: Spacing.sm),
                child: SizedBox(
                  height: 300,
                  child: const FocusTaskPanel(),
                ),
              ),
              crossFadeState: _panelExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
            const SizedBox(height: Spacing.xl),
          ],

          // ── 计时器区域 ──
          const _TimerSection(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer section (shared between desktop and mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _TimerSection extends StatelessWidget {
  const _TimerSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.base,
          vertical: Spacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModeSelector(),
              SizedBox(height: Spacing.xl),
              TimerDisplay(),
              SizedBox(height: Spacing.lg),
              TaskPicker(),
              SizedBox(height: Spacing.xl),
              TimerControls(),
            ],
          ),
        ),
      ),
    );
  }
}
