import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/data/repositories/focus_plan_repository.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/features/focus/widgets/add_plan_sheet.dart';
import 'package:achievements/features/focus/widgets/plan_task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 今日专注计划面板。
///
/// 展示:
/// - 总进度条
/// - 计划任务列表（可拖拽排序）
/// - 过期未完成折叠区域
/// - 添加计划入口
class TodayPlanPanel extends ConsumerWidget {
  const TodayPlanPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayFocusPlansProvider);
    final overdueAsync = ref.watch(overdueFocusPlansProvider);
    final timerState = ref.watch(focusTimerProvider);

    return todayAsync.when(
      loading: () => const _PanelShell(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => _PanelShell(
        child: Center(
          child: Text(
            '加载失败',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      data: (plans) {
        final overduePlans = overdueAsync.valueOrNull ?? [];
        return _PanelContent(
          plans: plans,
          overduePlans: overduePlans,
          activeTaskId: timerState.taskId,
          ref: ref,
        );
      },
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.base),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({
    required this.plans,
    required this.overduePlans,
    required this.activeTaskId,
    required this.ref,
  });

  final List<FocusPlan> plans;
  final List<FocusPlan> overduePlans;
  final String? activeTaskId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 计算总进度
    final totalPlanned = plans.fold<int>(0, (s, p) => s + p.plannedMinutes);
    final totalActual = plans.fold<int>(0, (s, p) => s + p.actualSeconds);
    final totalPlannedSecs = totalPlanned * 60;
    final progress =
        totalPlannedSecs > 0 ? (totalActual / totalPlannedSecs).clamp(0.0, 1.0) : 0.0;
    final allDone = plans.isNotEmpty &&
        plans.every((p) => p.actualSeconds >= p.plannedMinutes * 60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 标题行 ──
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.base,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '今日专注计划',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              if (totalPlanned > 0)
                Text(
                  '${_formatMinutes(totalActual)} / ${_formatMinutes(totalPlanned)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),

        // ── 总进度条 ──
        if (totalPlanned > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor:
                          scheme.onSurface.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(
                        allDone
                            ? const Color(0xFF4CAF50)
                            : scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  allDone ? '已完成 🎉' : '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: allDone
                        ? const Color(0xFF4CAF50)
                        : scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],

        // ── 计划列表 ──
        if (plans.isEmpty)
          _EmptyState(ref: ref)
        else ...[
          ...plans.map((plan) {
            final taskTitle = ref
                    .watch(_taskTitleProvider(plan.taskId))
                    .valueOrNull ??
                '加载中...';
            return Padding(
              padding: const EdgeInsets.only(
                left: Spacing.sm,
                right: Spacing.sm,
                bottom: Spacing.sm,
              ),
              child: PlanTaskCard(
                plan: plan,
                taskTitle: taskTitle,
                isActive: plan.taskId == activeTaskId,
                onStart: () => _startFocusForPlan(plan),
                onDelete: () => _deletePlan(plan.id),
                onEditDuration: () =>
                    _showEditDuration(context, plan),
              ),
            );
          }),
          // ── 添加按钮 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: TextButton.icon(
              onPressed: () => AddPlanSheet.show(context, ref),
              icon: Icon(
                Icons.add_rounded,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
              label: Text(
                '添加计划任务',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xs,
                ),
              ),
            ),
          ),
        ],

        // ── 过期未完成 ──
        if (overduePlans.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          _OverdueSection(
            plans: overduePlans,
            ref: ref,
          ),
        ],
      ],
    );
  }

  void _startFocusForPlan(FocusPlan plan) {
    final notifier = ref.read(focusTimerProvider.notifier);
    notifier.setTask(plan.taskId);
    final state = ref.read(focusTimerProvider);
    if (state.phase == FocusPhase.idle) {
      notifier.start();
    }
  }

  void _deletePlan(String planId) {
    ref.read(focusPlanRepositoryProvider).deletePlan(planId);
  }

  void _showEditDuration(BuildContext context, FocusPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    final controller = TextEditingController(
      text: plan.plannedMinutes.toString(),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改计划时长'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: '分钟',
            suffixStyle: TextStyle(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0) {
                ref.read(focusPlanRepositoryProvider).upsertPlan(
                      taskId: plan.taskId,
                      date: plan.date,
                      plannedMinutes: minutes,
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  static String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.xxl,
        horizontal: Spacing.base,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 40,
            color: scheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            '还没有今日计划',
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            '添加任务计划，或直接开始自由专注',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          OutlinedButton.icon(
            onPressed: () => AddPlanSheet.show(context, ref),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加计划'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.base,
                vertical: Spacing.sm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueSection extends StatefulWidget {
  const _OverdueSection({required this.plans, required this.ref});
  final List<FocusPlan> plans;
  final WidgetRef ref;

  @override
  State<_OverdueSection> createState() => _OverdueSectionState();
}

class _OverdueSectionState extends State<_OverdueSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: const Color(0xFFFF9800).withValues(alpha: 0.6),
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  '未完成 (${widget.plans.length})',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFFFF9800).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Icon(
                  _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 16,
                  color: scheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.plans.map((plan) {
            final taskTitle = widget.ref
                    .watch(_taskTitleProvider(plan.taskId))
                    .valueOrNull ??
                '...';
            return Padding(
              padding: const EdgeInsets.only(
                left: Spacing.sm,
                right: Spacing.sm,
                top: Spacing.sm,
              ),
              child: PlanTaskCard(
                plan: plan,
                taskTitle: taskTitle,
                isOverdue: true,
                onStart: () {},
                onDelete: () => widget.ref
                    .read(focusPlanRepositoryProvider)
                    .deletePlan(plan.id),
                onEditDuration: () {},
              ),
            );
          }),
      ],
    );
  }
}

/// 根据 taskId 获取任务标题的 provider。
final _taskTitleProvider =
    StreamProvider.family.autoDispose<String?, String>((ref, taskId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.tasks)..where((t) => t.id.equals(taskId)))
      .watchSingleOrNull()
      .map((task) => task?.title);
});
