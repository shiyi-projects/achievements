import 'dart:async';

import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/task_detail/widgets/subtasks_section.dart';
import 'package:achievements/features/task_detail/widgets/tag_editor.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const Duration _kTextDebounce = Duration(milliseconds: 400);

class TaskDetailPanel extends ConsumerWidget {
  const TaskDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(currentTaskProvider);
    return taskAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Failed to load: $e')),
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
            'Select a task to view details',
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
  Timer? _titleDebounce;
  Timer? _notesDebounce;

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
      _titleCtrl.text = widget.task.title;
      _notesCtrl.text = widget.task.notes ?? '';
    }
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _notesDebounce?.cancel();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  void _onTitleChanged(String v) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(_kTextDebounce, () async {
      final t = v.trim();
      if (t.isEmpty) return;
      await _repo.update(widget.task.id, title: Value(t));
    });
  }

  void _onNotesChanged(String v) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(_kTextDebounce, () async {
      await _repo.update(
        widget.task.id,
        notes: Value(v.trim().isEmpty ? null : v),
      );
    });
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
        title: const Text('Delete forever?'),
        content: Text('"${widget.task.title}" will be permanently deleted.'),
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
    if (ok != true) return;
    await _repo.hardDelete(widget.task.id);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = widget.task;
    final df = DateFormat.yMMMd();
    final dtf = DateFormat.yMd().add_jm();

    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            _TopBar(
              starred: task.starred,
              isTrashed: task.deletedAt != null,
              onClose: _close,
              onToggleStar: () =>
                  _repo.update(task.id, starred: Value(!task.starred)),
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
                  // Title
                  TextField(
                    controller: _titleCtrl,
                    onChanged: _onTitleChanged,
                    style: theme.textTheme.headlineSmall,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Task title',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: Spacing.base),
                  // Notes
                  TextField(
                    controller: _notesCtrl,
                    onChanged: _onNotesChanged,
                    minLines: 2,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Add description...',
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
                  // Properties card
                  _PropsCard(
                    children: [
                      _PrioritySel(
                        priority: TaskPriority.fromValue(task.priority),
                        onChanged: (p) =>
                            _repo.update(task.id, priority: Value(p.value)),
                      ),
                      _ListDropdown(
                        currentListId: task.listId,
                        onChanged: (newId) =>
                            _repo.update(task.id, listId: Value(newId)),
                      ),
                      TagEditor(taskId: task.id),
                    ],
                  ),
                  const SizedBox(height: Spacing.base),
                  SubtasksSection(parent: task),
                  Divider(
                    height: Spacing.xxl,
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  // Due date
                  _PropRow(
                    icon: Icons.event_rounded,
                    onTap: _pickDueDate,
                    trailing: task.dueAt != null
                        ? _ClearBtn(
                            onTap: () =>
                                _repo.update(task.id, dueAt: const Value(null)),
                          )
                        : null,
                    child: Text(
                      task.dueAt == null
                          ? 'No due date'
                          : 'Due ${df.format(task.dueAt!)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _PropRow(
                    icon: Icons.notifications_rounded,
                    onTap: _pickRemind,
                    trailing: task.remindAt != null
                        ? _ClearBtn(
                            onTap: () => _repo.update(
                              task.id,
                              remindAt: const Value(null),
                            ),
                          )
                        : null,
                    child: Text(
                      task.remindAt == null
                          ? 'No reminder'
                          : 'Remind ${dtf.format(task.remindAt!)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Divider(
                    height: Spacing.xxl,
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  _Meta(label: 'Created', value: dtf.format(task.createdAt)),
                  _Meta(label: 'Updated', value: dtf.format(task.updatedAt)),
                  if (task.completedAt != null)
                    _Meta(
                      label: 'Completed',
                      value: dtf.format(task.completedAt!),
                    ),
                  if (task.deletedAt != null)
                    _Meta(label: 'Trashed', value: dtf.format(task.deletedAt!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.starred,
    required this.isTrashed,
    required this.onClose,
    required this.onToggleStar,
    required this.onSoftDelete,
    required this.onRestore,
    required this.onHardDelete,
  });
  final bool starred, isTrashed;
  final VoidCallback onClose,
      onToggleStar,
      onSoftDelete,
      onRestore,
      onHardDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: onClose,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              starred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: starred ? scheme.tertiary : null,
            ),
            tooltip: starred ? 'Unstar' : 'Star',
            onPressed: onToggleStar,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onSelected: (v) {
              switch (v) {
                case 'del':
                  onSoftDelete();
                case 'res':
                  onRestore();
                case 'hdel':
                  onHardDelete();
              }
            },
            itemBuilder: (_) => [
              if (!isTrashed)
                const PopupMenuItem(value: 'del', child: Text('Move to Trash'))
              else ...[
                const PopupMenuItem(value: 'res', child: Text('Restore')),
                const PopupMenuItem(
                  value: 'hdel',
                  child: Text('Delete forever'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PropsCard extends StatelessWidget {
  const _PropsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.sm,
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
          ],
        ],
      ),
    );
  }
}

class _PropRow extends StatelessWidget {
  const _PropRow({
    required this.icon,
    required this.child,
    this.onTap,
    this.trailing,
  });
  final IconData icon;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.base),
            Expanded(child: child),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ListDropdown extends ConsumerWidget {
  const _ListDropdown({required this.currentListId, required this.onChanged});
  final String currentListId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lists = ref.watch(movableListsProvider);
    final folders = ref
        .watch(allFoldersProvider)
        .maybeWhen(data: (d) => d, orElse: () => const <Folder>[]);
    final currentName =
        lists
            .where((l) => l.id == currentListId)
            .map((l) => l.name)
            .firstOrNull ??
        '—';

    // Group: inbox first, then root lists, then folder lists
    final inbox = lists.where((l) => l.isSystem).toList();
    final rootLists = lists
        .where((l) => !l.isSystem && l.folderId == null)
        .toList();
    final folderIds = folders.map((f) => f.id).toSet();
    final byFolder = <String, List<TaskList>>{};
    for (final l in lists.where((l) => !l.isSystem && l.folderId != null)) {
      if (folderIds.contains(l.folderId)) {
        byFolder.putIfAbsent(l.folderId!, () => []).add(l);
      } else {
        rootLists.add(l);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.base),
          Expanded(
            child: PopupMenuButton<String>(
              initialValue: currentListId,
              onSelected: (id) {
                if (id != currentListId) onChanged(id);
              },
              offset: const Offset(0, 36),
              constraints: const BoxConstraints(maxHeight: 400, minWidth: 200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.input),
              ),
              itemBuilder: (_) => [
                // System lists (Inbox)
                for (final l in inbox) _buildItem(l, scheme),
                // Root custom lists
                for (final l in rootLists) _buildItem(l, scheme),
                // Folder groups
                for (final folder in folders) ...[
                  if (byFolder.containsKey(folder.id)) ...[
                    PopupMenuItem<String>(
                      enabled: false,
                      height: 32,
                      child: Text(
                        folder.name,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    for (final l in byFolder[folder.id]!)
                      _buildItem(l, scheme, indent: true),
                  ],
                ],
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        currentName,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 16,
                      color: scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildItem(
    TaskList l,
    ColorScheme scheme, {
    bool indent = false,
  }) {
    return PopupMenuItem<String>(
      value: l.id,
      child: Padding(
        padding: EdgeInsets.only(left: indent ? Spacing.base : 0),
        child: Row(
          children: [
            Icon(
              l.isSystem
                  ? Icons.inbox_rounded
                  : Icons.format_list_bulleted_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(child: Text(l.name)),
            if (l.id == currentListId)
              Icon(Icons.check_rounded, size: 18, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _PrioritySel extends StatelessWidget {
  const _PrioritySel({required this.priority, required this.onChanged});
  final TaskPriority priority;
  final ValueChanged<TaskPriority> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.flag_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.base),
          Expanded(
            child: SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(value: TaskPriority.none, label: Text('None')),
                ButtonSegment(value: TaskPriority.low, label: Text('Low')),
                ButtonSegment(value: TaskPriority.medium, label: Text('Med')),
                ButtonSegment(value: TaskPriority.high, label: Text('High')),
              ],
              selected: {priority},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearBtn extends StatelessWidget {
  const _ClearBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.close_rounded, size: 16),
    tooltip: 'Clear',
    onPressed: onTap,
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    padding: EdgeInsets.zero,
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
