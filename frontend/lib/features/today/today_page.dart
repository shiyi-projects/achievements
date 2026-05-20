import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:achievements/shared/widgets/quick_create_input.dart';
import 'package:achievements/shared/widgets/task_tile.dart';
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
                child: Text('加载失败: $e'),
              ),
            ),
            data: (tasks) => _TodayBody(tasks: tasks, now: DateTime.now()),
          ),
        ),
        QuickCreateInput(
          hint: '添加今日任务…',
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
    final completedCount = tasks.where((t) => t.completedAt != null).length;
    final pending = tasks.where((t) => t.completedAt == null).toList();
    final completed = tasks.where((t) => t.completedAt != null).toList();

    return CustomScrollView(
      slivers: [
        // ── Welcome Card ──
        SliverToBoxAdapter(
          child: _WelcomeCard(
            hour: now.hour,
            date: now,
            total: tasks.length,
            completed: completedCount,
          ),
        ),

        // ── Task List (as native slivers — no nested scrollable) ──
        if (tasks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: AppIcons.svgIcon(AppIcons.completed, size: 36),
              title: '今天还没有任务',
              subtitle: '从下方输入框创建你的第一个任务吧。',
            ),
          )
        else ...[
          if (pending.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader('待完成 (${pending.length})'),
            ),
            SliverList.builder(
              itemCount: pending.length,
              itemBuilder: (_, i) => TaskTile(task: pending[i]),
            ),
          ],
          if (completed.isNotEmpty)
            SliverToBoxAdapter(
              child: _CompletedSection(
                tasks: completed,
                initiallyExpanded: pending.isEmpty,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: Spacing.sm)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.sm,
        Spacing.base,
        Spacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.outline,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Completed 折叠区。children 是普通 TaskTile(非 ListView),
/// 可安全放在 SliverToBoxAdapter 里。
class _CompletedSection extends StatelessWidget {
  const _CompletedSection({
    required this.tasks,
    required this.initiallyExpanded,
  });

  final List<Task> tasks;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        child: ExpansionTile(
          key: const PageStorageKey<String>('today-completed-fold'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.input),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.input),
          ),
          title: Text(
            '已完成 (${tasks.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
              letterSpacing: 0.5,
            ),
          ),
          childrenPadding: EdgeInsets.zero,
          children: [for (final t in tasks) TaskTile(task: t)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Welcome Card — 带动画进度条和动态 Emoji
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
    final isLight = scheme.brightness == Brightness.light;
    final dateLabel = DateFormat.yMMMMEEEEd('zh_CN').format(date);
    final pending = total - completed;
    final progress = total > 0 ? completed / total : 0.0;
    final emoji = _greetingEmoji(hour);

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
            colors: isLight
                ? [
                    scheme.primaryContainer,
                    scheme.primaryContainer.withValues(alpha: 0.6),
                  ]
                : [
                    scheme.primaryContainer.withValues(alpha: 0.4),
                    scheme.primaryContainer.withValues(alpha: 0.15),
                  ],
          ),
          borderRadius: BorderRadius.circular(Radii.card),
          border: isLight
              ? null
              : Border.all(
                  color: scheme.primaryContainer.withValues(alpha: 0.3),
                ),
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting ──
            Row(
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    _greeting(hour),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              dateLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: Spacing.base),

            // ── Animated Progress ──
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.circle),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: MotionDurations.celebration,
                      curve: MotionCurves.emphasizedDecelerate,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: scheme.onPrimaryContainer.withValues(
                            alpha: 0.12,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: completed),
                  duration: MotionDurations.bouncy,
                  curve: MotionCurves.emphasizedDecelerate,
                  builder: (context, val, _) {
                    return Text(
                      '$val / $total',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: Spacing.sm),

            // ── Summary ──
            Text(
              total == 0
                  ? '今天没有待办任务'
                  : '$pending 个待完成 · $completed 个已完成',
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
    if (hour < 5) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String _greetingEmoji(int hour) {
    if (hour < 5) return '🦉';
    if (hour < 12) return '🌅';
    if (hour < 18) return '☀️';
    return '🌙';
  }
}
