import 'package:achievements/core/recurrence/recurrence_rule_draft.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 可内嵌的重复规则编辑器(受控)。
///
/// [draft] 为 null 表示「不重复」。任何改动通过 [onChanged] 回传新草稿(或 null)。
/// 不弹任何二级 sheet——频率/间隔/周几/结束就地编辑;仅「到某天」用系统日期选择器。
class RecurrenceEditor extends StatelessWidget {
  const RecurrenceEditor({
    required this.draft,
    required this.onChanged,
    super.key,
  });

  final RecurrenceRuleDraft? draft;
  final ValueChanged<RecurrenceRuleDraft?> onChanged;

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

  String _unit(RecurrenceFreq f) => switch (f) {
    RecurrenceFreq.daily => '天',
    RecurrenceFreq.weekly => '周',
    RecurrenceFreq.monthly => '个月',
    RecurrenceFreq.yearly => '年',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 频率(含「不重复」)──
        Wrap(
          spacing: Spacing.sm,
          children: [
            ChoiceChip(
              label: const Text('不重复'),
              selected: d == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final f in RecurrenceFreq.values)
              ChoiceChip(
                label: Text(_freqLabels[f]!),
                selected: d?.freq == f,
                onSelected: (_) => onChanged(
                  (d ?? const RecurrenceRuleDraft(freq: RecurrenceFreq.daily))
                      .copyWith(freq: f),
                ),
              ),
          ],
        ),

        if (d != null) ...[
          const SizedBox(height: Spacing.base),
          // ── 间隔 ──
          Row(
            children: [
              Text('间隔', style: theme.textTheme.bodyMedium),
              const Spacer(),
              IconButton.outlined(
                visualDensity: VisualDensity.compact,
                onPressed: d.interval > 1
                    ? () => onChanged(d.copyWith(interval: d.interval - 1))
                    : null,
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Text(
                  '每 ${d.interval} ${_unit(d.freq)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton.outlined(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    onChanged(d.copyWith(interval: d.interval + 1)),
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),

          // ── 周几(仅每周) ──
          if (d.freq == RecurrenceFreq.weekly) ...[
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final entry in _weekdayLabels.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: d.byWeekdays.contains(entry.key),
                    onSelected: (sel) {
                      final next = {...d.byWeekdays};
                      if (sel) {
                        next.add(entry.key);
                      } else {
                        next.remove(entry.key);
                      }
                      onChanged(d.copyWith(byWeekdays: next));
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: Spacing.sm),
          // ── 结束条件 ──
          Wrap(
            spacing: Spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('永不'),
                selected: d.endMode == RecurrenceEndMode.never,
                onSelected: (_) =>
                    onChanged(d.copyWith(endMode: RecurrenceEndMode.never)),
              ),
              ChoiceChip(
                label: Text(
                  d.endMode == RecurrenceEndMode.count
                      ? '共 ${d.count ?? 10} 次'
                      : '指定次数',
                ),
                selected: d.endMode == RecurrenceEndMode.count,
                onSelected: (_) => onChanged(
                  d.copyWith(
                    endMode: RecurrenceEndMode.count,
                    count: d.count ?? 10,
                  ),
                ),
              ),
              if (d.endMode == RecurrenceEndMode.count) ...[
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  onPressed: (d.count ?? 10) > 1
                      ? () => onChanged(d.copyWith(count: (d.count ?? 10) - 1))
                      : null,
                  icon: const Icon(Icons.remove_rounded, size: 16),
                ),
                IconButton.outlined(
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      onChanged(d.copyWith(count: (d.count ?? 10) + 1)),
                  icon: const Icon(Icons.add_rounded, size: 16),
                ),
              ],
              ActionChip(
                avatar: const Icon(Icons.event_rounded, size: 16),
                label: Text(
                  d.endMode == RecurrenceEndMode.until && d.until != null
                      ? '至 ${_fmt(d.until!)}'
                      : '到某天',
                ),
                onPressed: () => _pickUntil(context, d),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickUntil(BuildContext context, RecurrenceRuleDraft d) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: d.until ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    onChanged(d.copyWith(endMode: RecurrenceEndMode.until, until: picked));
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
