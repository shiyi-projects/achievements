import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:achievements/features/focus/utils/duration_format.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 根据任务 ID 查询任务的 provider。
final _taskByIdProvider =
    StreamProvider.family.autoDispose<Task?, String>((ref, taskId) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.tasks)..where((t) => t.id.equals(taskId)))
      .watchSingleOrNull();
});

/// 专注会话关联任务区域。
///
/// 三种状态：
/// - 已关联：情感化卡片展示（专注中不可切换）
/// - 未关联 + 列表选中：快速关联建议
/// - 空：选择任务入口
class TaskPicker extends ConsumerWidget {
  const TaskPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(focusTimerProvider);
    final notifier = ref.read(focusTimerProvider.notifier);
    final currentTaskAsync = ref.watch(currentTaskProvider);

    final associatedId = timerState.taskId;
    final isActive = timerState.phase == FocusPhase.working ||
        timerState.phase == FocusPhase.shortBreak;

    // ── 已关联任务 ──
    if (associatedId != null) {
      final taskAsync = ref.watch(_taskByIdProvider(associatedId));
      final task = taskAsync.valueOrNull;
      return _AssociatedCard(
        task: task,
        isActive: isActive,
        onClear: isActive ? null : () => notifier.setTask(null),
      );
    }

    // 专注中不允许关联新任务
    if (isActive) return const SizedBox.shrink();

    // ── 未关联，但列表有选中任务 ──
    final currentTask = currentTaskAsync.maybeWhen(
      data: (t) => t,
      orElse: () => null,
    );
    if (currentTask != null) {
      return _SuggestCard(
        taskTitle: currentTask.title,
        onAssociate: () => notifier.setTask(currentTask.id),
      );
    }

    // ── 无任何关联 ──
    return _EmptyCard(
      onTap: () => _showTaskSelector(context, ref),
    );
  }

  void _showTaskSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TaskSelectorSheet(),
    ).then((taskId) {
      if (taskId != null) {
        ref.read(focusTimerProvider.notifier).setTask(taskId);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Associated — 情感化卡片
// ─────────────────────────────────────────────────────────────────────────────

class _AssociatedCard extends StatelessWidget {
  const _AssociatedCard({
    required this.task,
    required this.isActive,
    required this.onClear,
  });

  final Task? task;
  final bool isActive;
  final VoidCallback? onClear; // null = 锁定（专注中不可切换）

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = task?.title ?? '加载中...';
    final focusedSecs = task?.focusedSeconds ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.md,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive
                ? [
                    scheme.primary.withValues(alpha: 0.10),
                    scheme.primary.withValues(alpha: 0.04),
                  ]
                : [
                    scheme.onSurface.withValues(alpha: 0.04),
                    scheme.onSurface.withValues(alpha: 0.02),
                  ],
          ),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: isActive
                ? scheme.primary.withValues(alpha: 0.2)
                : scheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // ── 状态图标 ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isActive ? Icons.local_fire_department_rounded : Icons.task_alt_rounded,
                key: ValueKey(isActive),
                size: 22,
                color: isActive
                    ? const Color(0xFFFF6D00)
                    : scheme.primary,
              ),
            ),
            const SizedBox(width: Spacing.md),

            // ── 标题 + 标签 ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? '正在专注' : '当前任务',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: isActive
                          ? const Color(0xFFFF6D00).withValues(alpha: 0.7)
                          : scheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  if (focusedSecs > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '累计专注 ${formatFocusDuration(focusedSecs)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── 操作区 ──
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: onClear,
                visualDensity: VisualDensity.compact,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                tooltip: '取消关联',
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(28, 28),
                ),
              )
            else
              // 专注中：锁定图标
              Tooltip(
                message: '专注中无法切换任务',
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.25),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggest — 快速关联建议
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestCard extends StatelessWidget {
  const _SuggestCard({required this.taskTitle, required this.onAssociate});
  final String taskTitle;
  final VoidCallback onAssociate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAssociate,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.md,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.15),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: scheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '快速关联',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: scheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        taskTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: scheme.primary.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty — 选择任务入口
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.md,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
              borderRadius: BorderRadius.circular(Radii.card),
              color: scheme.onSurface.withValues(alpha: 0.02),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_task_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  '选择关联任务',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 任务选择弹窗
// ─────────────────────────────────────────────────────────────────────────────

class _TaskSelectorSheet extends ConsumerStatefulWidget {
  const _TaskSelectorSheet();

  @override
  ConsumerState<_TaskSelectorSheet> createState() =>
      _TaskSelectorSheetState();
}

class _TaskSelectorSheetState extends ConsumerState<_TaskSelectorSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = ref.watch(appDatabaseProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
      child: Column(
        children: [
          // ── 拖拽手柄 ──
          Padding(
            padding: const EdgeInsets.only(top: Spacing.md),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Spacing.base),
            child: Text(
              '选择关联任务',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          // ── 搜索框 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: '搜索任务...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          // ── 列表 ──
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: (db.select(db.tasks)
                    ..where(
                      (t) =>
                          t.deletedAt.isNull() &
                          t.completedAt.isNull() &
                          t.parentId.isNull(),
                    )
                    ..orderBy([
                      (t) => OrderingTerm(
                            expression: t.updatedAt,
                            mode: OrderingMode.desc,
                          ),
                    ])
                    ..limit(50))
                  .watch(),
              builder: (context, snap) {
                final tasks = (snap.data ?? []).where((t) {
                  if (_search.isEmpty) return true;
                  return t.title
                      .toLowerCase()
                      .contains(_search.toLowerCase());
                }).toList();

                if (tasks.isEmpty) {
                  return Center(
                    child: Text(
                      '没有可用任务',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return ListTile(
                      leading: Icon(
                        Icons.circle_outlined,
                        size: 18,
                        color: scheme.outline,
                      ),
                      title: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                      onTap: () => Navigator.pop(context, task.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
