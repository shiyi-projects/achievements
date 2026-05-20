import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/calendar/providers/calendar_providers.dart';
import 'package:achievements/features/calendar/widgets/calendar_task_tile.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 选中日期的任务列表面板。
///
/// 日期切换时用 AnimatedSwitcher + SharedAxis 竖轴过渡。
/// 日期标签包含星期几显示。
/// 任务卡片带交错入场动画。
class DayTaskList extends ConsumerWidget {
  const DayTaskList({super.key});

  static const _weekDayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final tasks = ref.watch(selectedDayTasksProvider);

    if (selected == null) {
      return const EmptyState(
        icon: Icons.calendar_today_rounded,
        title: '点击日期查看任务',
        subtitle: '选择一个日期以查看当天的待办事项',
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weekDay = _weekDayNames[selected.weekday];
    final label = '${selected.month} 月 ${selected.day} 日  $weekDay';

    final pending = tasks.where((t) => t.completedAt == null).toList();
    final completed = tasks.where((t) => t.completedAt != null).toList();

    return AnimatedSwitcher(
      duration: MotionDurations.normal,
      switchInCurve: MotionCurves.emphasizedDecelerate,
      switchOutCurve: MotionCurves.emphasizedAccelerate,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey('${selected.year}-${selected.month}-${selected.day}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date label + badge ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.base, Spacing.sm, Spacing.base, Spacing.xs,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.xs),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Icon(
                    Icons.event_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tasks.isNotEmpty
                        ? scheme.primary.withValues(alpha: 0.1)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Radii.circle),
                  ),
                  child: Text(
                    '${tasks.length} 项任务',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tasks.isNotEmpty ? scheme.primary : scheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // ── Task list or empty ──
          if (tasks.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.event_available_rounded,
                title: '这一天没有任务',
                subtitle: '选定日期无待办事项',
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.base,
                  vertical: Spacing.xs,
                ),
                itemCount: pending.length +
                    (completed.isNotEmpty ? 1 + completed.length : 0),
                itemBuilder: (context, index) {
                  // Pending tasks
                  if (index < pending.length) {
                    return _AnimatedTaskEntry(
                      index: index,
                      child: CalendarTaskTile(task: pending[index]),
                    );
                  }
                  // Completed header
                  final cIndex = index - pending.length;
                  if (cIndex == 0) {
                    return _CompletedHeader(count: completed.length);
                  }
                  // Completed tasks
                  final cTaskIndex = cIndex - 1;
                  return _AnimatedTaskEntry(
                    index: pending.length + cTaskIndex,
                    child: CalendarTaskTile(task: completed[cTaskIndex]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 交错入场动画包装。
class _AnimatedTaskEntry extends StatefulWidget {
  const _AnimatedTaskEntry({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_AnimatedTaskEntry> createState() => _AnimatedTaskEntryState();
}

class _AnimatedTaskEntryState extends State<_AnimatedTaskEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: MotionDurations.normal,
    );
    final curve = CurvedAnimation(
      parent: _ctrl,
      curve: MotionCurves.emphasizedDecelerate,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(curve);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(curve);

    // Stagger: delay based on index
    final delay = Duration(milliseconds: widget.index.clamp(0, 8) * 40);
    Future.delayed(delay, () {
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
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

/// 「已完成」分隔标题。
class _CompletedHeader extends StatelessWidget {
  const _CompletedHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        top: Spacing.sm,
        bottom: Spacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            '已完成',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
