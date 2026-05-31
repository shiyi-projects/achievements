import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/features/focus/utils/duration_format.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 筛选范围。
enum _FilterRange { today, week, month, all }

/// 专注任务选择面板。
///
/// 展示未完成任务列表，支持筛选（今日/本周/本月/全部）。
/// 点击任务后调用 [FocusTimerNotifier.setTask]，自动调整番茄钟时长。
class FocusTaskPanel extends ConsumerStatefulWidget {
  const FocusTaskPanel({super.key});

  @override
  ConsumerState<FocusTaskPanel> createState() => _FocusTaskPanelState();
}

class _FocusTaskPanelState extends ConsumerState<FocusTaskPanel> {
  _FilterRange _range = _FilterRange.today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timerState = ref.watch(focusTimerProvider);
    final activeTaskId = timerState.taskId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 标题 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.base,
            Spacing.md,
            Spacing.base,
            Spacing.sm,
          ),
          child: Text(
            '选择专注任务',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),

        // ── 筛选条 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: SegmentedButton<_FilterRange>(
            segments: const [
              ButtonSegment(value: _FilterRange.today, label: Text('今日')),
              ButtonSegment(value: _FilterRange.week, label: Text('本周')),
              ButtonSegment(value: _FilterRange.month, label: Text('本月')),
              ButtonSegment(value: _FilterRange.all, label: Text('全部')),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.labelSmall,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),

        // ── 任务列表 ──
        Expanded(
          child: _TaskList(range: _range, activeTaskId: activeTaskId),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task list
// ─────────────────────────────────────────────────────────────────────────────

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.range, required this.activeTaskId});

  final _FilterRange range;
  final String? activeTaskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return StreamBuilder<List<Task>>(
      stream: _buildQuery(db).watch(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final tasks = snap.data ?? [];
        if (tasks.isEmpty) {
          return _EmptyHint(range: range);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          itemCount: tasks.length,
          itemBuilder: (context, i) {
            final task = tasks[i];
            final isActive = task.id == activeTaskId;
            return _TaskRow(
              task: task,
              isActive: isActive,
              onTap: () {
                final notifier = ref.read(focusTimerProvider.notifier);
                notifier.setTask(task.id);
              },
            );
          },
        );
      },
    );
  }

  SimpleSelectStatement<$TasksTable, Task> _buildQuery(AppDatabase db) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final q = db.select(db.tasks)
      ..where(
        (t) =>
            t.deletedAt.isNull() & t.completedAt.isNull() & t.parentId.isNull(),
      );

    // 按筛选范围过滤
    switch (range) {
      case _FilterRange.today:
        final tomorrow = today.add(const Duration(days: 1));
        q.where(
          (t) => t.dueAt.isBetweenValues(today, tomorrow) | t.dueAt.isNull(),
        ); // 今日到期 + 无截止日
      case _FilterRange.week:
        final weekEnd = today.add(const Duration(days: 7));
        q.where(
          (t) => t.dueAt.isSmallerOrEqualValue(weekEnd) | t.dueAt.isNull(),
        );
      case _FilterRange.month:
        final monthEnd = today.add(const Duration(days: 30));
        q.where(
          (t) => t.dueAt.isSmallerOrEqualValue(monthEnd) | t.dueAt.isNull(),
        );
      case _FilterRange.all:
        break; // 不加额外过滤
    }

    q.orderBy([
      // 有截止日的排前面，按截止日升序
      (t) => OrderingTerm(expression: t.dueAt.isNull(), mode: OrderingMode.asc),
      (t) => OrderingTerm(expression: t.dueAt, mode: OrderingMode.asc),
      (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
    ]);

    q.limit(50);
    return q;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task row
// ─────────────────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.isActive,
    required this.onTap,
  });

  final Task task;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasEstimate =
        task.estimatedMinutes != null && task.estimatedMinutes! > 0;

    // 进度
    final progress = hasEstimate
        ? (task.focusedSeconds / (task.estimatedMinutes! * 60)).clamp(0.0, 1.0)
        : 0.0;

    // 今日建议时长
    final suggestion = _dailySuggestion(task);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: Spacing.xs),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.1)
              : scheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: isActive
                ? scheme.primary.withValues(alpha: 0.3)
                : scheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 标题行 ──
            Row(
              children: [
                Icon(
                  isActive ? Icons.radio_button_checked : Icons.circle_outlined,
                  size: 16,
                  color: isActive
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),

            // ── 进度条（有预估时显示） ──
            if (hasEstimate) ...[
              const SizedBox(height: Spacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1.0 ? const Color(0xFF4CAF50) : scheme.primary,
                  ),
                ),
              ),
            ],

            // ── 标签行 ──
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              children: [
                // 已专注
                if (task.focusedSeconds > 0)
                  _Label(
                    icon: Icons.timer_outlined,
                    text: '已专注 ${formatFocusDuration(task.focusedSeconds)}',
                    color: scheme.primary,
                  ),
                // 预估
                if (hasEstimate)
                  _Label(
                    icon: Icons.schedule,
                    text:
                        '预估 ${formatFocusDuration(task.estimatedMinutes! * 60)}',
                    color: scheme.onSurfaceVariant,
                  ),
                // 截止日
                if (task.dueAt != null)
                  _Label(
                    icon: Icons.event,
                    text: _formatDueDate(task.dueAt!),
                    color: _isDueUrgent(task.dueAt!)
                        ? const Color(0xFFFF9800)
                        : scheme.onSurfaceVariant,
                  ),
                // 今日建议
                if (suggestion != null)
                  _Label(
                    icon: Icons.lightbulb_outline,
                    text: '建议 ${suggestion}m',
                    color: scheme.tertiary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 计算今日建议专注时长（分钟），无法计算返回 null。
  int? _dailySuggestion(Task task) {
    final estimated = task.estimatedMinutes;
    if (estimated == null || estimated <= 0) return null;

    final focusedMinutes = (task.focusedSeconds / 60).floor();
    final remaining = estimated - focusedMinutes;
    if (remaining <= 0) return null;

    final dueAt = task.dueAt;
    if (dueAt == null) return remaining.clamp(5, 45);

    final days = dueAt.difference(DateTime.now()).inDays.clamp(1, 365);
    return (remaining / days).ceil().clamp(5, 90);
  }

  String _formatDueDate(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff < 0) return '已过期';
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff < 7) return '${diff}天后';
    return '${d.month}/${d.day}';
  }

  bool _isDueUrgent(DateTime d) {
    return d.difference(DateTime.now()).inDays <= 1;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 2),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.range});
  final _FilterRange range;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rangeText = switch (range) {
      _FilterRange.today => '今日',
      _FilterRange.week => '本周',
      _FilterRange.month => '本月',
      _FilterRange.all => '',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 40,
            color: scheme.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            rangeText.isEmpty ? '没有待办任务' : '$rangeText没有待办任务',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
