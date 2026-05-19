import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/widgets/mode_selector.dart';
import 'package:achievements/features/focus/widgets/task_picker.dart';
import 'package:achievements/features/focus/widgets/timer_controls.dart';
import 'package:achievements/features/focus/widgets/timer_display.dart';
import 'package:flutter/material.dart';

/// 专注模式主页面（组装层）。
///
/// 从上到下：
/// 1. [ModeSelector] — 番茄钟 / 自由模式切换
/// 2. [TimerDisplay] — 圆环进度 + 大字计时
/// 3. [TaskPicker] — 关联任务（可选）
/// 4. [TimerControls] — 操作按钮组
class FocusPage extends StatelessWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const ModeSelector(),
          const SizedBox(height: Spacing.xl),
          const TimerDisplay(),
          const SizedBox(height: Spacing.lg),
          const TaskPicker(),
          const SizedBox(height: Spacing.xl),
          const TimerControls(),
        ],
      ),
    );
  }
}
