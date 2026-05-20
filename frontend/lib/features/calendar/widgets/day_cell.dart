import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// 日历网格中的单日格子。
///
/// 视觉特性:
/// - 选中态: 主色实心圆 + bouncySpring 缩放弹入 + 底部阴影
/// - 今日态: primaryContainer 填充 + 粗体 + 底部小圆点标记
/// - 任务指示器: 1-3 小圆点,按最高优先级取色
/// - 悬停态(桌面): 淡色背景
/// - InkWell 水波纹触摸反馈
class DayCell extends StatefulWidget {
  const DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.tasks,
    required this.onTap,
    super.key,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final List<Task> tasks;
  final VoidCallback onTap;

  @override
  State<DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<DayCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    final hasTasks = widget.tasks.isNotEmpty;
    final taskCount = widget.tasks.length;

    // ── Colors ──
    Color bgColor;
    Color fgColor;

    if (widget.isSelected) {
      bgColor = scheme.primary;
      fgColor = scheme.onPrimary;
    } else if (widget.isToday) {
      bgColor = scheme.primaryContainer.withValues(alpha: isLight ? 0.45 : 0.3);
      fgColor = scheme.onPrimaryContainer;
    } else if (_hovering) {
      bgColor = scheme.surfaceContainerHigh.withValues(alpha: isLight ? 0.6 : 0.3);
      fgColor = scheme.onSurface;
    } else {
      bgColor = Colors.transparent;
      fgColor = scheme.onSurface;
    }

    // ── Task indicator dots ──
    final highestPriority = _highestPriority(widget.tasks);
    final dotColor = widget.isSelected
        ? scheme.onPrimary.withValues(alpha: 0.7)
        : _priorityDotColor(highestPriority, scheme);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: widget.isSelected ? 1.08 : 1.0,
          duration: MotionDurations.fast,
          curve: MotionCurves.bouncySpring,
          child: AnimatedContainer(
            duration: MotionDurations.fast,
            curve: MotionCurves.emphasizedDecelerate,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(Radii.chip),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.chip),
                onTap: widget.onTap,
                splashColor: scheme.primary.withValues(alpha: 0.12),
                highlightColor: scheme.primary.withValues(alpha: 0.06),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Day number ──
                      Text(
                        '${widget.day}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: widget.isToday || widget.isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: fgColor,
                          height: 1.2,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // ── Task dots or today marker ──
                      if (hasTasks)
                        _TaskDots(
                          count: taskCount,
                          color: dotColor,
                        )
                      else if (widget.isToday && !widget.isSelected)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _highestPriority(List<Task> tasks) {
    if (tasks.isEmpty) return 0;
    return tasks.fold<int>(0, (max, t) => t.priority > max ? t.priority : max);
  }

  Color _priorityDotColor(int priority, ColorScheme scheme) {
    switch (priority) {
      case 3:
        return AppColors.urgent;
      case 2:
        return AppColors.medium;
      case 1:
        return AppColors.low;
      default:
        return scheme.primary.withValues(alpha: 0.5);
    }
  }
}

/// 任务数量指示圆点 (1-3 dots, 4+ 显示条)。
class _TaskDots extends StatelessWidget {
  const _TaskDots({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count <= 3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count.clamp(0, 3),
          (i) => Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 16,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.circle),
      ),
    );
  }
}
