import 'dart:math' as math;

import 'package:achievements/features/task_detail/widgets/date_helpers.dart';

import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/step_repository.dart';
import 'package:achievements/data/repositories/tag_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/platform/android/haptic.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/shared/widgets/priority_chip.dart';
import 'package:achievements/shared/widgets/tags_row.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 任务行,Today / ListPage 共用。
///
/// 卡片式布局:
/// - 左侧 4dp 优先级色条(高优先级有发光效果)
/// - 圆形 Checkbox(完成时粒子爆散)
/// - 标题 + 标签行
/// - trailing: 优先级 Chip / 提醒图标 / 星标
/// - 按压时缩小回弹的物理感
class TaskTile extends ConsumerStatefulWidget {
  const TaskTile({required this.task, super.key});

  final Task task;

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: MotionDurations.instant,
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: MotionCurves.gentleSpring),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final done = task.completedAt != null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    final selectedId = ref.watch(selectedTaskIdProvider);
    final selected = selectedId == task.id;
    final priority = TaskPriority.fromValue(task.priority);
    final tagsAsync = ref.watch(tagsForTaskProvider(task.id));
    final tags = tagsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <Tag>[],
    );
    final hasFutureReminder =
        task.remindAt != null && task.remindAt!.isAfter(DateTime.now());
    final stepProgress = ref.watch(stepCountProvider(task.id));

    final priorityColor = _priorityColor(priority);
    final isHighPriority = priority == TaskPriority.high;

    return ScaleTransition(
          scale: _pressScale,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.base,
              vertical: Spacing.xs,
            ),
            child: GestureDetector(
              onTapDown: (_) => _pressCtrl.forward(),
              onTapUp: (_) => _pressCtrl.reverse(),
              onTapCancel: () => _pressCtrl.reverse(),
              child: Material(
                color: selected
                    ? scheme.secondaryContainer.withValues(alpha: 0.5)
                    : scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(Radii.card),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.card),
                  onTap: () =>
                      ref.read(selectedTaskIdProvider.notifier).select(task.id),
                  onLongPress: () {
                    Haptic.medium();
                    _showContextMenu(context, ref);
                  },
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Priority Color Strip (高优先级发光) ──
                        if (priority != TaskPriority.none)
                          AnimatedContainer(
                            duration: MotionDurations.fast,
                            width: 4,
                            decoration: BoxDecoration(
                              color: priorityColor,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(Radii.card),
                              ),
                              boxShadow: isHighPriority
                                  ? [
                                      BoxShadow(
                                        color: priorityColor.withValues(
                                          alpha: isLight ? 0.4 : 0.6,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(2, 0),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),

                        // ── Main Content ──
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              priority != TaskPriority.none
                                  ? Spacing.sm
                                  : Spacing.md,
                              Spacing.sm,
                              Spacing.md,
                              Spacing.sm,
                            ),
                            child: Row(
                              children: [
                                // ── Checkbox with particles ──
                                _ParticleCheckbox(
                                  checked: done,
                                  color: done ? scheme.primary : scheme.outline,
                                  onTap: () => ref
                                      .read(taskRepositoryProvider)
                                      .setCompleted(task.id, completed: !done),
                                ),
                                const SizedBox(width: Spacing.md),

                                // ── Title + Meta + Tags ──
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedDefaultTextStyle(
                                        duration: MotionDurations.fast,
                                        style:
                                            (theme.textTheme.bodyLarge ??
                                                    const TextStyle())
                                                .copyWith(
                                                  decoration: done
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : null,
                                                  color: done
                                                      ? scheme.outline
                                                      : scheme.onSurface,
                                                  decorationColor:
                                                      scheme.outline,
                                                ),
                                        child: Text(
                                          task.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // ── Metadata row: due date / repeat / focus ──
                                      if (_hasMetadata(task))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: Spacing.xs,
                                          ),
                                          child: _MetadataRow(task: task),
                                        ),
                                      if (tags.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: Spacing.xs,
                                          ),
                                          child: TagsRow(tags: tags),
                                        ),
                                      if (stepProgress.total > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: Spacing.xs,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        Radii.circle,
                                                      ),
                                                  child: LinearProgressIndicator(
                                                    value:
                                                        stepProgress.total == 0
                                                        ? 0
                                                        : stepProgress.done /
                                                              stepProgress
                                                                  .total,
                                                    minHeight: 3,
                                                    backgroundColor: scheme
                                                        .surfaceContainerHighest
                                                        .withValues(alpha: 0.6),
                                                    valueColor:
                                                        AlwaysStoppedAnimation(
                                                          scheme.primary,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: Spacing.xs),
                                              Text(
                                                '${stepProgress.done}/${stepProgress.total}',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: scheme.outline,
                                                      fontSize: 10,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // ── Trailing ──
                                ..._buildTrailing(
                                  theme,
                                  scheme,
                                  priority,
                                  hasFutureReminder,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: MotionDurations.fast)
        .slideX(
          begin: 0.03,
          duration: MotionDurations.normal,
          curve: MotionCurves.emphasizedDecelerate,
        );
  }

  List<Widget> _buildTrailing(
    ThemeData theme,
    ColorScheme scheme,
    TaskPriority priority,
    bool hasFutureReminder,
  ) {
    final items = <Widget>[];
    if (priority != TaskPriority.none) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: Spacing.sm),
          child: PriorityChip(priority: priority),
        ),
      );
    }
    if (hasFutureReminder) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: Spacing.sm),
          child: AppIcons.svgIcon(AppIcons.reminder, size: 18),
        ),
      );
    }
    if (widget.task.starred) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(left: Spacing.sm),
          child: AppIcons.svgIcon(AppIcons.important, size: 18)
              .animate(onPlay: (c) => c.stop())
              .scale(
                begin: const Offset(0.0, 0.0),
                end: const Offset(1.0, 1.0),
                duration: MotionDurations.normal,
                curve: MotionCurves.bouncySpring,
              ),
        ),
      );
    }
    return items;
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:
        return AppColors.urgent;
      case TaskPriority.medium:
        return AppColors.medium;
      case TaskPriority.low:
        return AppColors.low;
      case TaskPriority.none:
        return Colors.transparent;
    }
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final done = widget.task.completedAt != null;
    final repo = ref.read(taskRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Center(
                    child: AppIcons.svgIcon(
                      done ? AppIcons.undo : AppIcons.incomplete,
                      size: 18,
                    ),
                  ),
                ),
                title: Text(done ? '标记为未完成' : '标记为完成'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Haptic.light();
                  repo.setCompleted(widget.task.id, completed: !done);
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Center(
                    child: AppIcons.svgIcon(AppIcons.important, size: 18),
                  ),
                ),
                title: Text(widget.task.starred ? '取消星标' : '加星标'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Haptic.light();
                  repo.update(
                    widget.task.id,
                    starred: Value(!widget.task.starred),
                  );
                },
              ),
              const Divider(height: Spacing.sm),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Center(
                    child: AppIcons.svgIcon(AppIcons.delete, size: 18),
                  ),
                ),
                title: Text('移到回收站', style: TextStyle(color: scheme.error)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Haptic.medium();
                  repo.softDelete(widget.task.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 判断任务是否有可显示的元数据信息。
bool _hasMetadata(Task task) {
  return task.dueAt != null ||
      (task.repeatRule != null && task.repeatRule!.isNotEmpty) ||
      (task.estimatedMinutes != null && task.estimatedMinutes! > 0);
}

/// 元数据信息行：截止日期 / 重复标识 / 专注进度。
///
/// 紧凑单行布局，用小图标 + 文字，不额外占用卡片高度。
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = <Widget>[];

    // ── 1. 截止日期 ──
    if (task.dueAt != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDate = DateTime(
        task.dueAt!.year,
        task.dueAt!.month,
        task.dueAt!.day,
      );
      final isOverdue = dueDate.isBefore(today) && task.completedAt == null;
      final isToday = dueDate == today;

      Color dateColor;
      if (isOverdue) {
        dateColor = scheme.error;
      } else if (isToday) {
        dateColor = AppColors.high;
      } else {
        dateColor = scheme.outline;
      }

      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOverdue ? Icons.event_busy_rounded : Icons.event_rounded,
              size: 13,
              color: dateColor,
            ),
            const SizedBox(width: 3),
            Text(
              formatDateCn(task.dueAt!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: dateColor,
                fontSize: 11,
                fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // ── 2. 重复标识 ──
    if (task.repeatRule != null && task.repeatRule!.isNotEmpty) {
      items.add(Icon(Icons.repeat_rounded, size: 13, color: scheme.outline));
    }

    // ── 3. 专注进度 ──
    if (task.estimatedMinutes != null && task.estimatedMinutes! > 0) {
      final focusedMin = task.focusedSeconds ~/ 60;
      final estMin = task.estimatedMinutes!;
      final isComplete = focusedMin >= estMin;

      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isComplete
                  ? Icons.check_circle_outline_rounded
                  : Icons.timer_outlined,
              size: 13,
              color: isComplete ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 3),
            Text(
              '${_fmtMin(focusedMin)}/${_fmtMin(estMin)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isComplete ? scheme.primary : scheme.outline,
                fontSize: 11,
                fontWeight: isComplete ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          items[i],
          if (i < items.length - 1)
            Text(
              '·',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outlineVariant,
                fontSize: 10,
              ),
            ),
        ],
      ],
    );
  }

  static String _fmtMin(int v) {
    if (v >= 60) {
      final h = v ~/ 60;
      final m = v % 60;
      return m == 0 ? '${h}h' : '${h}h${m}m';
    }
    return '${v}m';
  }
}

// ─────────────────────────────────────────────────────────────────────
// Particle Checkbox (animated with burst effect)
// ─────────────────────────────────────────────────────────────────────

class _ParticleCheckbox extends StatefulWidget {
  const _ParticleCheckbox({
    required this.checked,
    required this.color,
    required this.onTap,
  });

  final bool checked;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ParticleCheckbox> createState() => _ParticleCheckboxState();
}

class _ParticleCheckboxState extends State<_ParticleCheckbox>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;
  late final AnimationController _particleCtrl;

  // 粒子数据
  static final _random = math.Random();
  List<_ParticleData> _particles = [];

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: MotionDurations.fast,
    );
    _scale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1, end: 1.4), weight: 35),
          TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 35),
        ]).animate(
          CurvedAnimation(parent: _scaleCtrl, curve: MotionCurves.bouncySpring),
        );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: MotionDurations.celebration,
    );
  }

  @override
  void didUpdateWidget(_ParticleCheckbox old) {
    super.didUpdateWidget(old);
    if (!old.checked && widget.checked) {
      // 触发完成动画 + 粒子爆散
      _scaleCtrl.forward(from: 0);
      _spawnParticles();
    }
  }

  void _spawnParticles() {
    _particles = List.generate(8, (i) {
      final angle = (i / 8) * 2 * math.pi + _random.nextDouble() * 0.5;
      return _ParticleData(
        angle: angle,
        speed: 40 + _random.nextDouble() * 30,
        size: 2.5 + _random.nextDouble() * 2,
      );
    });
    _particleCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // ── Particles ──
            if (_particles.isNotEmpty)
              AnimatedBuilder(
                animation: _particleCtrl,
                builder: (context, _) {
                  if (!_particleCtrl.isAnimating && _particleCtrl.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    size: const Size(32, 32),
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _particleCtrl.value,
                      color: widget.color,
                    ),
                  );
                },
              ),
            // ── Checkbox ──
            ScaleTransition(
              scale: _scale,
              child: AnimatedContainer(
                duration: MotionDurations.fast,
                curve: MotionCurves.bouncySpring,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.checked ? widget.color : Colors.transparent,
                  border: Border.all(color: widget.color, width: 2),
                ),
                child: AnimatedSwitcher(
                  duration: MotionDurations.fast,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: widget.checked
                      ? SizedBox(
                          key: const ValueKey('check'),
                          width: 16,
                          height: 16,
                          child: AppIcons.svgIcon(AppIcons.check, size: 16),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticleData {
  const _ParticleData({
    required this.angle,
    required this.speed,
    required this.size,
  });
  final double angle;
  final double speed;
  final double size;
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  final List<_ParticleData> particles;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final t = progress;
      final dist = p.speed * t;
      final dx = math.cos(p.angle) * dist;
      final dy = math.sin(p.angle) * dist;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      final radius = p.size * (1.0 - t * 0.5);

      canvas.drawCircle(
        center + Offset(dx, dy),
        radius,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
