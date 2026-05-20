import 'dart:async';

import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全屏闹钟式提醒界面。
///
/// 任务提醒到期时弹出，覆盖所有内容，类似手机闹钟的效果。
/// 提供三个操作：完成任务 / 稍后提醒 / 关闭。
/// 60 秒无操作自动关闭。
class ReminderAlarmScreen extends ConsumerStatefulWidget {
  const ReminderAlarmScreen({
    required this.task,
    required this.onDismiss,
    super.key,
  });

  final Task task;
  final VoidCallback onDismiss;

  @override
  ConsumerState<ReminderAlarmScreen> createState() =>
      _ReminderAlarmScreenState();
}

class _ReminderAlarmScreenState extends ConsumerState<ReminderAlarmScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _bgFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _contentFade;

  Timer? _autoCloseTimer;

  static const _autoCloseDuration = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();

    // ── Pulse animation for bell icon ──
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // ── Entrance animation ──
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: MotionDurations.bouncy,
    );
    _bgFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0, 0.4, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));
    _contentFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    );

    _entranceCtrl.forward();

    // ── Auto-close timer ──
    _autoCloseTimer = Timer(_autoCloseDuration, _dismiss);
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _pulseCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    widget.onDismiss();
  }

  Future<void> _completeTask() async {
    await ref.read(taskRepositoryProvider).setCompleted(
      widget.task.id,
      completed: true,
    );
    _dismiss();
  }

  Future<void> _snooze(Duration delay) async {
    await ref.read(taskRepositoryProvider).update(
      widget.task.id,
      knownVersion: widget.task.version,
      remindAt: Value(DateTime.now().add(delay)),
    );
    _dismiss();
  }

  void _showSnoozeOptions() {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.base),
              child: Text(
                '稍后提醒',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: AppIcons.svgIcon(AppIcons.focusTimer),
              title: const Text('10 分钟后'),
              onTap: () {
                Navigator.pop(ctx);
                _snooze(const Duration(minutes: 10));
              },
            ),
            ListTile(
              leading: AppIcons.svgIcon(AppIcons.focusTimer),
              title: const Text('30 分钟后'),
              onTap: () {
                Navigator.pop(ctx);
                _snooze(const Duration(minutes: 30));
              },
            ),
            ListTile(
              leading: AppIcons.svgIcon(AppIcons.focusTimer),
              title: const Text('1 小时后'),
              onTap: () {
                Navigator.pop(ctx);
                _snooze(const Duration(hours: 1));
              },
            ),
            ListTile(
              leading: AppIcons.svgIcon(AppIcons.focusTimer),
              title: const Text('明天'),
              onTap: () {
                Navigator.pop(ctx);
                _snooze(const Duration(days: 1));
              },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    final task = widget.task;

    return FadeTransition(
      opacity: _bgFade,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.2,
              colors: isLight
                  ? [
                      scheme.primaryContainer.withValues(alpha: 0.95),
                      scheme.surface.withValues(alpha: 0.98),
                    ]
                  : [
                      scheme.surface.withValues(alpha: 0.98),
                      const Color(0xFF0A0A0A).withValues(alpha: 0.98),
                    ],
            ),
          ),
          child: SlideTransition(
            position: _contentSlide,
            child: FadeTransition(
              opacity: _contentFade,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xl,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2),

                          // ── Pulsing bell icon ──
                          ScaleTransition(
                            scale: _pulseAnim,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    scheme.primary,
                                    scheme.tertiary,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withValues(
                                      alpha: isLight ? 0.3 : 0.5,
                                    ),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: AppIcons.svgIcon(AppIcons.reminder, size: 48),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── "任务提醒" label ──
                          Text(
                            '── 任务提醒 ──',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Task title ──
                          Text(
                            task.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 16),

                          // ── Time ──
                          if (task.remindAt != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcons.svgIcon(AppIcons.planned, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDateTime(task.remindAt!),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: scheme.outline,
                                  ),
                                ),
                              ],
                            ),

                          // ── Notes preview ──
                          if (task.notes != null &&
                              task.notes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(Spacing.base),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh
                                    .withValues(alpha: 0.5),
                                borderRadius:
                                    BorderRadius.circular(Radii.input),
                              ),
                              child: Text(
                                task.notes!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          const Spacer(flex: 1),

                          // ── Action buttons ──
                          Row(
                            children: [
                              // Complete button
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _completeTask,
                                  icon: AppIcons.svgIcon(AppIcons.check),
                                  label: const Text('完成'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: Spacing.base,
                                    ),
                                    backgroundColor: scheme.primary,
                                    foregroundColor: scheme.onPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.md),
                              // Snooze button
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: _showSnoozeOptions,
                                  icon: AppIcons.svgIcon(AppIcons.snooze),
                                  label: const Text('稍后'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: Spacing.base,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: Spacing.md),

                          // Dismiss button
                          TextButton(
                            onPressed: _dismiss,
                            child: Text(
                              '关闭提醒',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.outline,
                              ),
                            ),
                          ),

                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (isToday) return '今天 $h:$m';
    return '${dt.month}月${dt.day}日 $h:$m';
  }
}
