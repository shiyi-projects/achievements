import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/data/repositories/focus_plan_repository.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 添加计划任务的底部弹窗。
///
/// 从未完成任务列表中选取一个任务，指定今日计划时长。
class AddPlanSheet extends StatefulWidget {
  const AddPlanSheet({super.key});

  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const AddPlanSheet(),
      ),
    );
  }

  @override
  State<AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<AddPlanSheet> {
  String? _selectedTaskId;
  int _plannedMinutes = 30;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
          // ── 标题 ──
          Padding(
            padding: const EdgeInsets.all(Spacing.base),
            child: Row(
              children: [
                Text('添加专注计划', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          // ── 搜索框 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
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
          // ── 任务列表 ──
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final db = ref.watch(appDatabaseProvider);
                return StreamBuilder<List<Task>>(
                  stream:
                      (db.select(db.tasks)
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
                      if (_searchQuery.isEmpty) return true;
                      return t.title.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
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
                        final isSelected = task.id == _selectedTaskId;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedTaskId = task.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.sm + 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(Radii.chip),
                              border: isSelected
                                  ? Border.all(
                                      color: scheme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: isSelected
                                      ? scheme.primary
                                      : scheme.outline,
                                ),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: scheme.onSurface.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ),
                                if (task.estimatedMinutes != null)
                                  Text(
                                    '${task.estimatedMinutes}m',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // ── 时长选择 + 确认 ──
          Container(
            padding: const EdgeInsets.all(Spacing.base),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '计划时长',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    ...[15, 30, 45, 60].map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(right: Spacing.xs),
                        child: ChoiceChip(
                          label: Text('${m}m'),
                          selected: _plannedMinutes == m,
                          onSelected: (_) =>
                              setState(() => _plannedMinutes = m),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: _plannedMinutes == m
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                          selectedColor: scheme.primary.withValues(alpha: 0.3),
                          backgroundColor: scheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.chip),
                          ),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                SizedBox(
                  width: double.infinity,
                  child: Consumer(
                    builder: (context, ref, _) {
                      return FilledButton(
                        onPressed: _selectedTaskId == null
                            ? null
                            : () async {
                                await ref
                                    .read(focusPlanRepositoryProvider)
                                    .upsertPlan(
                                      taskId: _selectedTaskId!,
                                      date: DateTime.now(),
                                      plannedMinutes: _plannedMinutes,
                                    );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        child: const Text('添加到今日计划'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
