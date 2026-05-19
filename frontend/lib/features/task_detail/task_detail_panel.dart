import 'dart:async';

import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const Duration _kTextDebounce = Duration(milliseconds: 400);

/// 任务详情面板。
///
/// 桌面模式作为第三列内嵌,移动模式作为 modal bottom sheet 内容。
/// 字段:title / notes / dueAt / starred + 元数据(created / updated)。
class TaskDetailPanel extends ConsumerWidget {
  const TaskDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(currentTaskProvider);
    return taskAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('加载失败:$e'),
        ),
      ),
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '从左侧选择一个任务以查看详情',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
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
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  Timer? _titleDebounce;
  Timer? _notesDebounce;
  String _lastSeenId = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _syncControllers(widget.task);
  }

  @override
  void didUpdateWidget(_TaskDetailForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换到不同任务时重置控制器,但不要在每次同一任务的字段变化里覆盖输入
    if (oldWidget.task.id != widget.task.id) {
      _syncControllers(widget.task);
    } else if (_lastSeenId == widget.task.id) {
      // 远端数据有更新且非用户在编辑(简单策略:仅当控制器值与新值不一致且
      // 当前未聚焦时同步,Phase 1 先保守起见不抢用户输入)
    }
  }

  void _syncControllers(Task task) {
    _titleController.text = task.title;
    _notesController.text = task.notes ?? '';
    _lastSeenId = task.id;
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _notesDebounce?.cancel();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  void _scheduleTitle(String value) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(_kTextDebounce, () async {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      await _repo.update(widget.task.id, title: Value(trimmed));
    });
  }

  void _scheduleNotes(String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(_kTextDebounce, () async {
      await _repo.update(
        widget.task.id,
        notes: Value(value.trim().isEmpty ? null : value),
      );
    });
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
    // 保持时间为当天 23:59,与 QuickCreate 一致
    final due = DateTime(picked.year, picked.month, picked.day, 23, 59);
    await _repo.update(widget.task.id, dueAt: Value(due));
  }

  Future<void> _clearDueDate() async {
    await _repo.update(widget.task.id, dueAt: const Value(null));
  }

  Future<void> _toggleStarred() async {
    await _repo.update(widget.task.id, starred: Value(!widget.task.starred));
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete forever?'),
        content: Text('"${widget.task.title}" 将被彻底删除,无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.hardDelete(widget.task.id);
    _close();
  }

  void _close() {
    ref.read(selectedTaskIdProvider.notifier).clear();
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final df = DateFormat.yMMMd();
    final dtf = DateFormat.yMd().add_jm();

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: _close,
                ),
                IconButton(
                  icon: Icon(
                    task.starred ? Icons.star : Icons.star_outline,
                    color: task.starred ? theme.colorScheme.tertiary : null,
                  ),
                  tooltip: task.starred ? 'Unstar' : 'Star',
                  onPressed: _toggleStarred,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Task title',
                border: InputBorder.none,
              ),
              style: theme.textTheme.headlineSmall,
              onChanged: _scheduleTitle,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Notes',
                border: OutlineInputBorder(),
              ),
              onChanged: _scheduleNotes,
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                task.dueAt == null
                    ? 'No due date'
                    : 'Due ${df.format(task.dueAt!)}',
              ),
              trailing: task.dueAt == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear',
                      onPressed: _clearDueDate,
                    ),
              onTap: _pickDueDate,
            ),
            const Divider(height: 32),
            _MetadataRow(label: 'Created', value: dtf.format(task.createdAt)),
            _MetadataRow(label: 'Updated', value: dtf.format(task.updatedAt)),
            if (task.completedAt != null)
              _MetadataRow(
                label: 'Completed',
                value: dtf.format(task.completedAt!),
              ),
            if (task.deletedAt != null)
              _MetadataRow(
                label: 'Trashed',
                value: dtf.format(task.deletedAt!),
              ),
            const SizedBox(height: 24),
            _DangerActions(
              isTrashed: task.deletedAt != null,
              onSoftDelete: _softDelete,
              onRestore: _restore,
              onHardDelete: _hardDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerActions extends StatelessWidget {
  const _DangerActions({
    required this.isTrashed,
    required this.onSoftDelete,
    required this.onRestore,
    required this.onHardDelete,
  });

  final bool isTrashed;
  final VoidCallback onSoftDelete;
  final VoidCallback onRestore;
  final VoidCallback onHardDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isTrashed) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Restore'),
              onPressed: onRestore,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                foregroundColor: theme.colorScheme.onErrorContainer,
                backgroundColor: theme.colorScheme.errorContainer,
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete forever'),
              onPressed: onHardDelete,
            ),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        label: Text(
          'Move to Trash',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        onPressed: onSoftDelete,
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
