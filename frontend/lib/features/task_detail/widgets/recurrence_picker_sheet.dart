import 'package:achievements/core/recurrence/recurrence_rule_draft.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 弹出重复规则选择器。
///
/// 返回值:新的 RRULE 主体串;空串表示「关闭重复」;null 表示取消(不改动)。
/// [initialBody] 为当前规则主体(可空)。
Future<String?> showRecurrencePicker(
  BuildContext context, {
  String? initialBody,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RecurrencePickerSheet(initialBody: initialBody),
  );
}

class _RecurrencePickerSheet extends StatefulWidget {
  const _RecurrencePickerSheet({this.initialBody});

  final String? initialBody;

  @override
  State<_RecurrencePickerSheet> createState() => _RecurrencePickerSheetState();
}

class _RecurrencePickerSheetState extends State<_RecurrencePickerSheet> {
  late RecurrenceRuleDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft =
        (widget.initialBody != null
            ? RecurrenceRuleDraft.fromRuleBody(widget.initialBody!)
            : null) ??
        const RecurrenceRuleDraft(freq: RecurrenceFreq.weekly);
  }

  static const _freqLabels = {
    RecurrenceFreq.daily: '每天',
    RecurrenceFreq.weekly: '每周',
    RecurrenceFreq.monthly: '每月',
    RecurrenceFreq.yearly: '每年',
  };

  static const _weekdayLabels = {
    DateTime.monday: '一',
    DateTime.tuesday: '二',
    DateTime.wednesday: '三',
    DateTime.thursday: '四',
    DateTime.friday: '五',
    DateTime.saturday: '六',
    DateTime.sunday: '日',
  };

  String get _unit => switch (_draft.freq) {
    RecurrenceFreq.daily => '天',
    RecurrenceFreq.weekly => '周',
    RecurrenceFreq.monthly => '个月',
    RecurrenceFreq.yearly => '年',
  };

  Future<void> _pickUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.until ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      _draft = _draft.copyWith(endMode: RecurrenceEndMode.until, until: picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          Spacing.sm,
          Spacing.xl,
          Spacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.repeat_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Text(
                  '重复',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _draft.describe(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),

            // ── 频率 ──
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final f in RecurrenceFreq.values)
                  ChoiceChip(
                    label: Text(_freqLabels[f]!),
                    selected: _draft.freq == f,
                    onSelected: (_) =>
                        setState(() => _draft = _draft.copyWith(freq: f)),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.base),

            // ── 间隔 ──
            Row(
              children: [
                Text('间隔', style: theme.textTheme.bodyLarge),
                const Spacer(),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  onPressed: _draft.interval > 1
                      ? () => setState(
                          () => _draft = _draft.copyWith(
                            interval: _draft.interval - 1,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Text(
                    '每 ${_draft.interval} $_unit',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(
                    () =>
                        _draft = _draft.copyWith(interval: _draft.interval + 1),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
              ],
            ),

            // ── 周几(仅每周) ──
            if (_draft.freq == RecurrenceFreq.weekly) ...[
              const SizedBox(height: Spacing.base),
              Wrap(
                spacing: Spacing.sm,
                children: [
                  for (final entry in _weekdayLabels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _draft.byWeekdays.contains(entry.key),
                      onSelected: (sel) {
                        final next = {..._draft.byWeekdays};
                        if (sel) {
                          next.add(entry.key);
                        } else {
                          next.remove(entry.key);
                        }
                        setState(
                          () => _draft = _draft.copyWith(byWeekdays: next),
                        );
                      },
                    ),
                ],
              ),
            ],

            Divider(
              height: Spacing.xl,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),

            // ── 结束条件 ──
            Text(
              '结束',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            RadioListTile<RecurrenceEndMode>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('永不'),
              value: RecurrenceEndMode.never,
              groupValue: _draft.endMode,
              onChanged: (_) => setState(
                () =>
                    _draft = _draft.copyWith(endMode: RecurrenceEndMode.never),
              ),
            ),
            RadioListTile<RecurrenceEndMode>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Row(
                children: [
                  const Text('指定次数后'),
                  const Spacer(),
                  if (_draft.endMode == RecurrenceEndMode.count)
                    _CountStepper(
                      count: _draft.count ?? 10,
                      onChanged: (n) =>
                          setState(() => _draft = _draft.copyWith(count: n)),
                    ),
                ],
              ),
              value: RecurrenceEndMode.count,
              groupValue: _draft.endMode,
              onChanged: (_) => setState(
                () => _draft = _draft.copyWith(
                  endMode: RecurrenceEndMode.count,
                  count: _draft.count ?? 10,
                ),
              ),
            ),
            RadioListTile<RecurrenceEndMode>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Row(
                children: [
                  const Text('到某天'),
                  const Spacer(),
                  if (_draft.endMode == RecurrenceEndMode.until)
                    TextButton(
                      onPressed: _pickUntil,
                      child: Text(
                        _draft.until != null
                            ? '${_draft.until!.year}-'
                                  '${_draft.until!.month.toString().padLeft(2, '0')}-'
                                  '${_draft.until!.day.toString().padLeft(2, '0')}'
                            : '选择日期',
                      ),
                    ),
                ],
              ),
              value: RecurrenceEndMode.until,
              groupValue: _draft.endMode,
              onChanged: (_) {
                setState(
                  () => _draft = _draft.copyWith(
                    endMode: RecurrenceEndMode.until,
                  ),
                );
                if (_draft.until == null) _pickUntil();
              },
            ),

            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    child: const Text('关闭重复'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_draft.toRuleBody()),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  const _CountStepper({required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: count > 1 ? () => onChanged(count - 1) : null,
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        Text('$count 次', style: Theme.of(context).textTheme.titleSmall),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(count + 1),
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}
