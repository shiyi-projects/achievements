import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:flutter/material.dart';

/// 日历网格中的单日格子。
///
/// 视觉特性:
/// - 选中态: 主色填充 + 阴影 + 微缩放
/// - 今日: primaryContainer 描边 + 脉冲动画
/// - 底部热力条: 任务密度色阶 (0=无, 1-2=浅, 3-4=中, 5+=深)
/// - 优先级最高任务颜色作为热力条色相
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

class _DayCellState extends State<DayCell> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnim = Tween<double>(begin: 0.35, end: 0.7).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.isToday && !widget.isSelected) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant DayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isToday && !widget.isSelected) {
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl
        ..stop()
        ..value = 0.35;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasTasks = widget.tasks.isNotEmpty;
    final taskCount = widget.tasks.length;

    // — Colors —
    Color bgColor;
    Color fgColor;

    if (widget.isSelected) {
      bgColor = scheme.primary;
      fgColor = scheme.onPrimary;
    } else if (widget.isToday) {
      bgColor = scheme.primaryContainer.withValues(alpha: 0.3);
      fgColor = scheme.onPrimaryContainer;
    } else {
      bgColor = Colors.transparent;
      fgColor = scheme.onSurface;
    }

    // — Heat strip color —
    final heatColor = _heatColor(scheme, taskCount);
    final highestPriority = _highestPriority(widget.tasks);
    final priorityAccent = _priorityAccent(highestPriority);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: widget.isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(Radii.chip),
            border: priorityAccent != null && !widget.isSelected
                ? Border.all(
                    color: priorityAccent.withValues(alpha: 0.3),
                  )
                : null,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Day number
                  Text(
                    '${widget.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.isToday || widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: fgColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Heat strip
                  if (hasTasks)
                    _HeatStrip(
                      color: heatColor,
                      isSelected: widget.isSelected,
                      count: taskCount,
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
              if (widget.isToday && !widget.isSelected)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, _) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Radii.chip),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: _pulseAnim.value),
                              width: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 任务密度 → 热力条颜色。
  Color _heatColor(ColorScheme scheme, int count) {
    if (count == 0) return Colors.transparent;
    final baseColor = scheme.primary;
    if (count <= 2) return baseColor.withValues(alpha: 0.3);
    if (count <= 4) return baseColor.withValues(alpha: 0.55);
    return baseColor.withValues(alpha: 0.85);
  }

  /// 取任务列表中最高优先级。
  int _highestPriority(List<Task> tasks) {
    if (tasks.isEmpty) return 0;
    return tasks.fold<int>(0, (max, t) => t.priority > max ? t.priority : max);
  }

  /// 优先级 → 强调色。
  Color? _priorityAccent(int priority) {
    switch (priority) {
      case 3:
        return AppColors.urgent;
      case 2:
        return AppColors.medium;
      case 1:
        return AppColors.low;
      default:
        return null;
    }
  }
}


/// 热力条组件。
class _HeatStrip extends StatelessWidget {
  const _HeatStrip({
    required this.color,
    required this.isSelected,
    required this.count,
  });

  final Color color;
  final bool isSelected;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayColor = isSelected
        ? scheme.onPrimary.withValues(alpha: 0.6)
        : color;

    if (count <= 3) {
      // Dots for low count
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count.clamp(0, 3),
          (i) => Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: displayColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    // Strip for higher counts
    return Container(
      width: 18,
      height: 4,
      decoration: BoxDecoration(
        color: displayColor,
        borderRadius: BorderRadius.circular(Radii.circle),
      ),
    );
  }
}
