import 'dart:async';

import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/focus/providers/focus_plan_service.dart';
import 'package:achievements/features/task_detail/widgets/collapsible_meta.dart';
import 'package:achievements/features/task_detail/widgets/due_reminder_field.dart';
import 'package:achievements/features/task_detail/widgets/focus_progress_row.dart';
import 'package:achievements/features/task_detail/widgets/list_dropdown.dart';
import 'package:achievements/features/task_detail/widgets/priority_chips.dart';
import 'package:achievements/features/task_detail/widgets/steps_subtasks_tabs.dart';
import 'package:achievements/features/task_detail/widgets/tag_editor.dart';
import 'package:achievements/features/task_detail/widgets/top_bar.dart';
import 'package:achievements/shared/widgets/surface_card.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration _kDebounce = Duration(milliseconds: 600);

class TaskDetailPanel extends ConsumerWidget {
  const TaskDetailPanel({this.scrollController, super.key});

  /// 窄屏 bottom sheet 传入 DraggableScrollableSheet 的控制器,使拖拽与内容滚动
  /// 统一;桌面停靠时为 null,列表用自身控制器。
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(currentTaskProvider);
    return taskAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('加载失败: $e')),
      data: (task) {
        if (task == null) return const _EmptySelection();
        return _TaskDetailForm(task: task, scrollController: scrollController);
      },
    );
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.touch_app_rounded,
              size: 28,
              color: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: Spacing.base),
          Text(
            '选择一个任务查看详情',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

class _TaskDetailForm extends ConsumerStatefulWidget {
  const _TaskDetailForm({required this.task, this.scrollController});
  final Task task;
  final ScrollController? scrollController;
  @override
  ConsumerState<_TaskDetailForm> createState() => _TaskDetailFormState();
}

class _TaskDetailFormState extends ConsumerState<_TaskDetailForm> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final FocusNode _titleFocus;
  late final FocusNode _notesFocus;

  // 累积文本字段变更,统一 flush 到一次事务,避免每个字段单独 SELECT+UPDATE+INSERT。
  Value<String> _dirtyTitle = const Value.absent();
  Value<String?> _dirtyNotes = const Value.absent();
  Timer? _flushTimer;

  // 描述区焦点状态，用于视觉反馈
  bool _notesHasFocus = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _notesCtrl = TextEditingController(text: widget.task.notes ?? '');
    _titleFocus = FocusNode();
    _notesFocus = FocusNode()
      ..addListener(() {
        final hasFocus = _notesFocus.hasFocus;
        if (hasFocus != _notesHasFocus) {
          setState(() => _notesHasFocus = hasFocus);
        }
      });
  }

  @override
  void didUpdateWidget(_TaskDetailForm old) {
    super.didUpdateWidget(old);
    if (old.task.id != widget.task.id) {
      // 切换任务:先 flush 旧任务的未提交变更,再重置控制器
      _flushPending(taskId: old.task.id, version: old.task.version);
      _titleCtrl.text = widget.task.title;
      _notesCtrl.text = widget.task.notes ?? '';
    }
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _flushPending(taskId: widget.task.id, version: widget.task.version);
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  /// 标记字段脏,重置 debounce 计时器。
  void _markDirty({Value<String>? title, Value<String?>? notes}) {
    if (title != null) _dirtyTitle = title;
    if (notes != null) _dirtyNotes = notes;
    _flushTimer?.cancel();
    _flushTimer = Timer(_kDebounce, () {
      _flushPending(taskId: widget.task.id, version: widget.task.version);
    });
  }

  /// 把积累的变更写入 DB（一次事务),直接用已知 [version] 跳过额外的 SELECT。
  void _flushPending({required String taskId, required int version}) {
    if (!_dirtyTitle.present && !_dirtyNotes.present) return;
    final title = _dirtyTitle;
    final notes = _dirtyNotes;
    _dirtyTitle = const Value.absent();
    _dirtyNotes = const Value.absent();
    _repo.update(taskId, knownVersion: version, title: title, notes: notes);
  }

  /// 立即保存（Ctrl+S 触发），跳过 debounce。
  void _flushNow() {
    _flushTimer?.cancel();
    _flushPending(taskId: widget.task.id, version: widget.task.version);
  }

  void _onTitleChanged(String v) {
    final t = v.trim();
    if (t.isEmpty) return;
    _markDirty(title: Value(t));
  }

  void _onNotesChanged(String v) {
    _markDirty(notes: Value(v.trim().isEmpty ? null : v));
  }

  void _close() {
    ref.read(selectedTaskIdProvider.notifier).clear();
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) nav.pop();
  }

  void _backToParent() {
    final parentId = widget.task.parentId;
    if (parentId != null) {
      ref.read(selectedTaskIdProvider.notifier).select(parentId);
    }
  }

  Future<void> _softDelete() async {
    await _repo.softDelete(widget.task.id);
    _close();
  }

  Future<void> _restore() async {
    await _repo.restore(widget.task.id);
    _close();
  }

  Future<void> _hardDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 32,
        ),
        title: const Text('永久删除?'),
        content: Text('「${widget.task.title}」将被永久删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.hardDelete(widget.task.id);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;

    // 面包屑：父任务信息
    final parentAsync = ref.watch(parentTaskProvider);
    final parentTask = parentAsync.valueOrNull;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            _repo.setCompleted(task.id, completed: task.completedAt == null),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _flushNow,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: scheme.surface,
          child: SafeArea(
            child: Column(
              children: [
                // ── Top Bar ──
                TaskDetailTopBar(
                  starred: task.starred,
                  completed: task.completedAt != null,
                  isTrashed: task.deletedAt != null,
                  parentTaskTitle: parentTask?.title,
                  onBackToParent: _backToParent,
                  onClose: _close,
                  onToggleComplete: () => _repo.setCompleted(
                    task.id,
                    completed: task.completedAt == null,
                  ),
                  onToggleStar: () => _repo.update(
                    task.id,
                    knownVersion: task.version,
                    starred: Value(!task.starred),
                  ),
                  onSoftDelete: _softDelete,
                  onRestore: _restore,
                  onHardDelete: _hardDelete,
                ),
                // ── Content ──
                Expanded(
                  child: ListView(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.xl,
                      Spacing.base,
                      Spacing.xl,
                      Spacing.xl,
                    ),
                    children: [
                      // ── Title (完成状态反馈) ──
                      TextField(
                        controller: _titleCtrl,
                        focusNode: _titleFocus,
                        onChanged: _onTitleChanged,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          decoration: task.completedAt != null
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.completedAt != null
                              ? scheme.outline
                              : null,
                          decorationColor: scheme.outline,
                        ),
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: '任务标题',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),

                      // ── Notes (增强：最小高度 + 聚焦视觉反馈) ──
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(Spacing.sm),
                        decoration: BoxDecoration(
                          color: _notesHasFocus
                              ? scheme.primaryContainer.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(Radii.input),
                          border: Border.all(
                            color: _notesHasFocus
                                ? scheme.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: TextField(
                            controller: _notesCtrl,
                            focusNode: _notesFocus,
                            onChanged: _onNotesChanged,
                            minLines: 2,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: '添加描述...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.md),

                      // ═════════════════════════════════════════
                      // 属性卡片
                      // ═════════════════════════════════════════
                      SurfaceCard(
                        key: const PageStorageKey('detail-card-attrs'),
                        collapsible: true,
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: scheme.outline,
                        ),
                        title: '属性',
                        children: [
                          PriorityChips(
                            priority: TaskPriority.fromValue(task.priority),
                            onChanged: (p) => _repo.update(
                              task.id,
                              knownVersion: task.version,
                              priority: Value(p.value),
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          ListDropdown(
                            currentListId: task.listId,
                            onChanged: (newId) => _repo.update(
                              task.id,
                              knownVersion: task.version,
                              listId: Value(newId),
                            ),
                          ),
                          TagEditor(taskId: task.id),
                        ],
                      ),
                      const SizedBox(height: Spacing.md),

                      // ═════════════════════════════════════════
                      // 时间 & 专注卡片
                      // ═════════════════════════════════════════
                      SurfaceCard(
                        key: const PageStorageKey('detail-card-time'),
                        collapsible: true,
                        icon: Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: scheme.outline,
                        ),
                        title: '时间 & 专注',
                        children: [
                          // ── 时间(截止+提醒合并) / 预估时长 — 同一 Wrap 行 ──
                          Wrap(
                            spacing: Spacing.sm,
                            runSpacing: Spacing.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DueReminderField(
                                dueAt: task.dueAt,
                                remindAt: task.remindAt,
                                repeatRule: task.repeatRule,
                              ),
                              _EstimatedDurationRow(
                                estimatedMinutes: task.estimatedMinutes,
                                onChanged: (minutes) async {
                                  await _repo.update(
                                    task.id,
                                    knownVersion: task.version,
                                    estimatedMinutes: Value(minutes),
                                  );
                                  // 触发自动规划
                                  if (minutes != null) {
                                    final updatedTask = task;
                                    ref
                                        .read(focusPlanServiceProvider)
                                        .generatePlans(updatedTask);
                                  }
                                },
                              ),
                            ],
                          ),
                          // ── 专注进度（仅在有预估时长时显示） ──
                          if (task.estimatedMinutes != null &&
                              task.estimatedMinutes! > 0)
                            FocusProgressRow(
                              focusedSeconds: task.focusedSeconds,
                              estimatedMinutes: task.estimatedMinutes!,
                            ),
                        ],
                      ),
                      const SizedBox(height: Spacing.md),

                      // ═════════════════════════════════════════
                      // 步骤 / 子任务（Tab 切换）
                      // ═════════════════════════════════════════
                      SurfaceCard(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.base,
                          Spacing.sm,
                          Spacing.base,
                          Spacing.sm,
                        ),
                        children: [StepsSubtasksTabs(task: task)],
                      ),
                      const SizedBox(height: Spacing.md),

                      // ── 元信息 (折叠) ──
                      CollapsibleMeta(task: task),
                    ],
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

/// 预估时长属性行。
class _EstimatedDurationRow extends StatelessWidget {
  const _EstimatedDurationRow({
    required this.estimatedMinutes,
    required this.onChanged,
  });

  final int? estimatedMinutes;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = estimatedMinutes != null;
    final label = hasValue ? _formatMinutes(estimatedMinutes!) : '预估时长';

    return ActionChip(
      avatar: Icon(
        Icons.timer_outlined,
        size: 16,
        color: hasValue ? scheme.primary : scheme.outline,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: hasValue ? scheme.primary : scheme.outline,
        ),
      ),
      onPressed: () => _showPicker(context),
      side: BorderSide(
        color: hasValue
            ? scheme.primary.withValues(alpha: 0.3)
            : scheme.outlineVariant,
      ),
      backgroundColor: hasValue
          ? scheme.primary.withValues(alpha: 0.06)
          : Colors.transparent,
    );
  }

  void _showPicker(BuildContext context) {
    final presets = [15, 30, 60, 120, 180, 240, 360, 480];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: Row(
                  children: [
                    const Text(
                      '预估专注时长',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (estimatedMinutes != null)
                      TextButton(
                        onPressed: () {
                          onChanged(null);
                          Navigator.pop(ctx);
                        },
                        child: const Text('清除'),
                      ),
                  ],
                ),
              ),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: presets.map((m) {
                  return ChoiceChip(
                    label: Text(_formatMinutes(m)),
                    selected: estimatedMinutes == m,
                    onSelected: (_) {
                      onChanged(m);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.md),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}小时${m}分钟' : '$h小时';
    }
    return '$minutes分钟';
  }
}
