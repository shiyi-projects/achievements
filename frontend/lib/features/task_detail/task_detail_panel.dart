import 'dart:async';

import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/task_detail/widgets/collapsible_meta.dart';
import 'package:achievements/features/task_detail/widgets/date_chip.dart';
import 'package:achievements/features/task_detail/widgets/list_dropdown.dart';
import 'package:achievements/features/task_detail/widgets/priority_chips.dart';
import 'package:achievements/features/task_detail/widgets/subtasks_section.dart';
import 'package:achievements/features/task_detail/widgets/tag_editor.dart';
import 'package:achievements/features/task_detail/widgets/top_bar.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration _kDebounce = Duration(milliseconds: 400);

class TaskDetailPanel extends ConsumerWidget {
  const TaskDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(currentTaskProvider);
    return taskAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('加载失败: $e')),
      data: (task) {
        if (task == null) return const _EmptySelection();
        return _TaskDetailForm(task: task);
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
  const _TaskDetailForm({required this.task});
  final Task task;
  @override
  ConsumerState<_TaskDetailForm> createState() => _TaskDetailFormState();
}

class _TaskDetailFormState extends ConsumerState<_TaskDetailForm> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;

  // 累积文本字段变更,统一 flush 到一次事务,避免每个字段单独 SELECT+UPDATE+INSERT。
  Value<String> _dirtyTitle = const Value.absent();
  Value<String?> _dirtyNotes = const Value.absent();
  Timer? _flushTimer;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _notesCtrl = TextEditingController(text: widget.task.notes ?? '');
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

  /// 把积累的变更写入 DB(一次事务),直接用已知 [version] 跳过额外的 SELECT。
  void _flushPending({required String taskId, required int version}) {
    if (!_dirtyTitle.present && !_dirtyNotes.present) return;
    final title = _dirtyTitle;
    final notes = _dirtyNotes;
    _dirtyTitle = const Value.absent();
    _dirtyNotes = const Value.absent();
    _repo.update(
      taskId,
      knownVersion: version,
      title: title,
      notes: notes,
    );
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

  Future<void> _pickDueDate() async {
    final initial = widget.task.dueAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    await _repo.update(
      widget.task.id,
      knownVersion: widget.task.version,
      dueAt: Value(DateTime(picked.year, picked.month, picked.day, 23, 59)),
    );
  }

  Future<void> _pickRemind() async {
    final initial =
        widget.task.remindAt ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    await _repo.update(
      widget.task.id,
      knownVersion: widget.task.version,
      remindAt: Value(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      ),
    );
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
        title: const Text('永久删除?'),
        content: Text('「${widget.task.title}」将被永久删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
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

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            TaskDetailTopBar(
              starred: task.starred,
              completed: task.completedAt != null,
              isTrashed: task.deletedAt != null,
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
                padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, Spacing.base, Spacing.xl, Spacing.xl,
                ),
                children: [
                  // ── Title (改动6: 完成状态反馈) ──
                  TextField(
                    controller: _titleCtrl,
                    onChanged: _onTitleChanged,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      decoration: task.completedAt != null
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.completedAt != null ? scheme.outline : null,
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
                  const SizedBox(height: Spacing.base),
                  // ── Notes ──
                  TextField(
                    controller: _notesCtrl,
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
                  const SizedBox(height: Spacing.lg),

                  // ── 属性区 (改动4: 流式分组) ──
                  const SectionHeader(label: '属性'),
                  const SizedBox(height: Spacing.sm),
                  PriorityChips(
                    priority: TaskPriority.fromValue(task.priority),
                    onChanged: (p) => _repo.update(
                      task.id,
                      knownVersion: task.version,
                      priority: Value(p.value),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  ListDropdown(
                    currentListId: task.listId,
                    onChanged: (newId) => _repo.update(
                      task.id,
                      knownVersion: task.version,
                      listId: Value(newId),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  TagEditor(taskId: task.id),

                  const SizedBox(height: Spacing.lg),
                  const SectionHeader(label: '时间'),
                  const SizedBox(height: Spacing.sm),
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    children: [
                      DateChip(
                        date: task.dueAt,
                        icon: AppIcons.svgIcon(AppIcons.planned, size: 16),
                        emptyLabel: '截止日期',
                        onTap: _pickDueDate,
                        onClear: task.dueAt != null
                            ? () => _repo.update(
                                  task.id,
                                  knownVersion: task.version,
                                  dueAt: const Value(null),
                                )
                            : null,
                      ),
                      DateChip(
                        date: task.remindAt,
                        icon: AppIcons.svgIcon(AppIcons.reminder, size: 16),
                        emptyLabel: '提醒',
                        showTime: true,
                        onTap: _pickRemind,
                        onClear: task.remindAt != null
                            ? () => _repo.update(
                                  task.id,
                                  knownVersion: task.version,
                                  remindAt: const Value(null),
                                )
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: Spacing.lg),
                  SubtasksSection(parent: task),

                  const SizedBox(height: Spacing.lg),
                  // ── 元信息 (改动5: 折叠) ──
                  CollapsibleMeta(task: task),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
