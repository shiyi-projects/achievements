import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:achievements/shared/widgets/pending_completed_list.dart';
import 'package:achievements/shared/widgets/quick_create_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Today 页面主体(不含 Scaffold / AppBar,由外层 AppShell 提供)。
///
/// 包含欢迎卡片(含日期、进度、统计)、快速创建、任务列表。
/// 任务创建落 Inbox 清单,dueAt = 今天 23:59。
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksForCurrentListProvider);
    return Column(
      children: [
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Text('Failed to load: $e'),
              ),
            ),
            data: (tasks) => _TodayBody(tasks: tasks, now: DateTime.now()),
          ),
        ),
        QuickCreateInput(
          hint: 'Add a task for today',
          onSubmit: (title) => _createForToday(ref, title),
        ),
      ],
    );
  }

  Future<void> _createForToday(WidgetRef ref, String title) async {
    final inbox = await ref.read(inboxListProvider.future);
    if (inbox == null) return;
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day, 23, 59);
    await ref
        .read(taskRepositoryProvider)
        .createTask(listId: inbox.id, title: title, dueAt: due);
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.tasks, required this.now});

  final List<Task> tasks;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((t) => t.completedAt != null).length;

    return CustomScrollView(
      slivers: [
        // ── Welcome Card ──
        SliverToBoxAdapter(
          child: _WelcomeCard(
            hour: now.hour,
            date: now,
            total: tasks.length,
            completed: completed,
          ),
        ),

        // ── Task List ──
        if (tasks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Nothing on today',
              subtitle: 'Create your first task from the input below.',
            ),
          )
        else
          SliverToBoxAdapter(
            child: PendingCompletedList(
              tasks: tasks,
              emptyState: const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Welcome Card
// ─────────────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.hour,
    required this.date,
    required this.total,
    required this.completed,
  });

  final int hour;
  final DateTime date;
  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateLabel = DateFormat.yMMMMEEEEd().format(date);
    final pending = total - completed;
    final progress = total > 0 ? completed / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.base,
        Spacing.md,
        Spacing.base,
        Spacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer,
              scheme.primaryContainer.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ──
            Text(
              _greeting(hour),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              dateLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: Spacing.base),

            // ── Progress ──
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.circle),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: scheme.onPrimaryContainer.withValues(
                        alpha: 0.12,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Text(
                  '$completed / $total',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Spacing.sm),

            // ── Summary ──
            Text(
              total == 0
                  ? 'No tasks due today'
                  : '$pending pending · $completed completed',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 5) return 'Still up?';
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}
