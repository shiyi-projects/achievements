import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/step_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StepsSection extends ConsumerStatefulWidget {
  const StepsSection({required this.taskId, super.key});

  final String taskId;

  @override
  ConsumerState<StepsSection> createState() => _StepsSectionState();
}

class _StepsSectionState extends ConsumerState<StepsSection> {
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _addCtrl.text.trim();
    if (raw.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(stepRepositoryProvider).createStep(widget.taskId, raw);
      _addCtrl.clear();
      _addFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reorder(
    List<TaskStep> steps,
    int oldIndex,
    int rawNewIndex,
  ) async {
    final newIndex = rawNewIndex > oldIndex ? rawNewIndex - 1 : rawNewIndex;
    final reordered = List<TaskStep>.from(steps);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    await ref.read(stepRepositoryProvider).reorderSteps([
      for (var i = 0; i < reordered.length; i++)
        (id: reordered[i].id, sortOrder: i),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stepsAsync = ref.watch(stepsForTaskProvider(widget.taskId));

    final steps = stepsAsync.maybeWhen(
      data: (s) => s,
      orElse: () => const <TaskStep>[],
    );
    final total = steps.length;
    final done = steps.where((s) => s.completedAt != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        Row(
          children: [
            Icon(Icons.checklist_rounded, size: 18, color: scheme.outline),
            const SizedBox(width: Spacing.sm),
            Text('步骤', style: theme.textTheme.labelLarge),
            if (total > 0) ...[
              const SizedBox(width: Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: done == total
                      ? scheme.primary.withValues(alpha: 0.15)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(Radii.circle),
                ),
                child: Text(
                  '$done/$total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: done == total ? scheme.primary : scheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),

        // ── Progress bar ──
        if (total > 0)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.circle),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 4,
                      backgroundColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  '$done/$total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: Spacing.sm),

        // ── Step list ──
        stepsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: Spacing.xs),
            child: LinearProgressIndicator(minHeight: 2),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (stepList) {
            if (stepList.isEmpty) {
              return const SizedBox.shrink();
            }
            return ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (o, n) => _reorder(stepList, o, n),
              itemCount: stepList.length,
              itemBuilder: (context, index) {
                final step = stepList[index];
                return _StepRow(
                  key: ValueKey(step.id),
                  step: step,
                  index: index,
                  repo: ref.read(stepRepositoryProvider),
                );
              },
            );
          },
        ),

        // ── Add step input ──
        Padding(
          padding: const EdgeInsets.only(top: Spacing.xs),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: TextField(
                  controller: _addCtrl,
                  focusNode: _addFocus,
                  enabled: !_submitting,
                  onSubmitted: (_) => _submit(),
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: '添加步骤',
                    hintStyle: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.outline),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: Spacing.sm,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Step Row
// ─────────────────────────────────────────────────────────────────────

class _StepRow extends StatefulWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.repo,
    this.onDelete,
    super.key,
  });

  final TaskStep step;
  final int index;
  final StepRepository repo;
  final VoidCallback? onDelete;

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.step.title);
    _focus = FocusNode()
      ..addListener(() {
        if (!_focus.hasFocus && _editing) {
          _commitRename();
        }
      });
  }

  @override
  void didUpdateWidget(_StepRow old) {
    super.didUpdateWidget(old);
    // 外部数据更新时,若当前不在编辑状态则同步文本
    if (old.step.title != widget.step.title && !_editing) {
      _ctrl.text = widget.step.title;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _editing = true);
    _focus.requestFocus();
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
  }

  void _commitRename() {
    setState(() => _editing = false);
    final text = _ctrl.text.trim();
    if (text.isNotEmpty && text != widget.step.title) {
      widget.repo.renameStep(widget.step.id, text);
    } else {
      _ctrl.text = widget.step.title;
    }
  }

  void _showDeleteMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('删除步骤'),
              onTap: () {
                Navigator.pop(context);
                widget.repo.deleteStep(widget.step.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = widget.step.completedAt != null;

    return GestureDetector(
      onLongPress: () => _showDeleteMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            // ── Checkbox ──
            GestureDetector(
              onTap: () => widget.repo.toggleStep(
                widget.step.id,
                completed: !done,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? scheme.primary : Colors.transparent,
                  border: Border.all(
                    color: done ? scheme.primary : scheme.outline,
                    width: 1.5,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: Spacing.md),

            // ── Title (inline editable) ──
            Expanded(
              child: GestureDetector(
                onTap: _editing ? null : _startEditing,
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  readOnly: !_editing,
                  onSubmitted: (_) => _commitRename(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? scheme.outline : null,
                    decorationColor: scheme.outline,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ),

            // ── Drag handle ──
            ReorderableDragStartListener(
              index: widget.index,
              child: Padding(
                padding: const EdgeInsets.only(left: Spacing.xs),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: scheme.outlineVariant,
                ),
              ),
            ),

            // ── Delete button (显式，提高可发现性) ──
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: scheme.outline,
                ),
                tooltip: '删除步骤',
                onPressed: widget.onDelete ??
                    () => widget.repo.deleteStep(widget.step.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
