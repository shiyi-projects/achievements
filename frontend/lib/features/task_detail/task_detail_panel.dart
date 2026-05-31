import 'dart:async';

import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/focus/providers/focus_plan_service.dart';
import 'package:achievements/features/task_detail/widgets/collapsible_meta.dart';
import 'package:achievements/features/task_detail/widgets/date_chip.dart';
import 'package:achievements/features/task_detail/widgets/detail_card.dart';
import 'package:achievements/features/task_detail/widgets/focus_progress_row.dart';
import 'package:achievements/features/task_detail/widgets/list_dropdown.dart';
import 'package:achievements/features/task_detail/widgets/priority_chips.dart';
import 'package:achievements/features/task_detail/widgets/steps_section.dart';
import 'package:achievements/features/task_detail/widgets/subtasks_section.dart';
import 'package:achievements/features/task_detail/widgets/tag_editor.dart';
import 'package:achievements/features/task_detail/widgets/top_bar.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Duration _kDebounce = Duration(milliseconds: 600);

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

  CalendarDatePicker2WithActionButtonsConfig _calendarConfig() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return CalendarDatePicker2WithActionButtonsConfig(
      calendarType: CalendarDatePicker2Type.single,
      firstDayOfWeek: 1,
      centerAlignModePicker: true,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      selectedDayHighlightColor: scheme.primary,
      weekdayLabels: const ['日', '一', '二', '三', '四', '五', '六'],
      weekdayLabelTextStyle: textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      controlsTextStyle: textTheme.titleSmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      dayTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      selectedDayTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onPrimary,
        fontWeight: FontWeight.w600,
      ),
      todayTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w600,
      ),
      disabledDayTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.38),
      ),
      dayBorderRadius: BorderRadius.circular(Radii.chip),
      // 只传 Text，不能传带 onPressed 的 Button：
      // 包的 InkWell 负责处理 tap(→ Navigator.pop)，若 child 也有 GestureDetector
      // 则内层优先消耗 tap，外层 Navigator.pop 永远不触发。
      okButton: Text(
        '确定',
        style: textTheme.labelLarge?.copyWith(color: scheme.primary),
      ),
      cancelButton: Text(
        '取消',
        style: textTheme.labelLarge?.copyWith(color: scheme.outline),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    FocusScope.of(context).unfocus();
    final initial = widget.task.dueAt ?? DateTime.now();
    final results = await showCalendarDatePicker2Dialog(
      context: context,
      config: _calendarConfig(),
      dialogSize: const Size(340, 400),
      borderRadius: BorderRadius.circular(Radii.sheet),
      value: [initial],
    );
    if (results == null ||
        results.isEmpty ||
        results.first == null ||
        !mounted) {
      return;
    }
    final picked = results.first!;
    await _repo.update(
      widget.task.id,
      knownVersion: widget.task.version,
      dueAt: Value(DateTime(picked.year, picked.month, picked.day, 23, 59)),
    );
  }

  Future<void> _pickRemind() async {
    FocusScope.of(context).unfocus();
    final initial =
        widget.task.remindAt ?? DateTime.now().add(const Duration(hours: 1));
    final results = await showCalendarDatePicker2Dialog(
      context: context,
      config: _calendarConfig(),
      dialogSize: const Size(340, 400),
      borderRadius: BorderRadius.circular(Radii.sheet),
      value: [initial],
    );
    if (results == null ||
        results.isEmpty ||
        results.first == null ||
        !mounted) {
      return;
    }
    final date = results.first!;
    // 等待日历退场动画结束后再显示时间选择器，避免两个 dialog 动画同时播放
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
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
                      DetailCard(
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
                      const SizedBox(height: Spacing.sm),

                      // ═════════════════════════════════════════
                      // 时间 & 专注卡片
                      // ═════════════════════════════════════════
                      DetailCard(
                        icon: Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: scheme.outline,
                        ),
                        title: '时间 & 专注',
                        children: [
                          // ── 截止日期 / 提醒 / 预估时长 — 同一 Wrap 行 ──
                          Wrap(
                            spacing: Spacing.sm,
                            runSpacing: Spacing.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DateChip(
                                date: task.dueAt,
                                icon: AppIcons.svgIcon(
                                  AppIcons.planned,
                                  size: 16,
                                ),
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
                                icon: AppIcons.svgIcon(
                                  AppIcons.reminder,
                                  size: 16,
                                ),
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
                      const SizedBox(height: Spacing.sm),

                      // ═════════════════════════════════════════
                      // 步骤卡片
                      // ═════════════════════════════════════════
                      DetailCard(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.base,
                          Spacing.base,
                          Spacing.base,
                          Spacing.sm,
                        ),
                        children: [StepsSection(taskId: task.id)],
                      ),
                      const SizedBox(height: Spacing.sm),

                      // ═════════════════════════════════════════
                      // 子任务卡片
                      // ═════════════════════════════════════════
                      DetailCard(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.base,
                          Spacing.base,
                          Spacing.base,
                          Spacing.sm,
                        ),
                        children: [SubtasksSection(parent: task)],
                      ),
                      const SizedBox(height: Spacing.sm),

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
