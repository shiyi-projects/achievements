import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// 列表项入场动画包装器。
///
/// 提供交错延迟的淡入 + 微上移效果，让列表加载时有「逐一浮现」的灵动感。
///
/// ```dart
/// SliverList.builder(
///   itemBuilder: (_, i) => AnimatedListItem(
///     index: i,
///     child: TaskTile(task: tasks[i]),
///   ),
/// )
/// ```
class AnimatedListItem extends StatefulWidget {
  const AnimatedListItem({
    required this.index,
    required this.child,
    this.duration = MotionDurations.normal,
    super.key,
  });

  final int index;
  final Widget child;
  final Duration duration;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: MotionCurves.emphasizedDecelerate,
    );
    final offset = StaggerHelper.slideOffset(widget.index);
    _slide = Tween<Offset>(begin: Offset(0, offset), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: MotionCurves.emphasizedDecelerate),
    );

    Future.delayed(StaggerHelper.delay(widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// 带数字滚动动画的计数器组件。
///
/// 数值变化时从旧值平滑滚动到新值，活泼生动。
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    required this.value,
    this.style,
    this.duration = MotionDurations.bouncy,
    this.prefix = '',
    this.suffix = '',
    super.key,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: MotionCurves.emphasizedDecelerate,
      builder: (context, val, _) {
        return Text('$prefix$val$suffix', style: style);
      },
    );
  }
}
