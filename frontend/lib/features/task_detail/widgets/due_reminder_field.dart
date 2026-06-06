import 'package:achievements/core/recurrence/recurrence_rule_draft.dart';
import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/task_detail/widgets/date_helpers.dart';
import 'package:achievements/features/task_detail/widgets/recurrence_editor.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 把 RRULE 主体串转成简短中文摘要;无法解析的复杂规则回退为「重复」。
String recurrenceSummary(String body) =>
    RecurrenceRuleDraft.fromRuleBody(body)?.describe() ?? '重复';

/// 「截止日期 + 提醒 + 重复」合并入口。
///
/// chip 展示摘要(📅 截止 · 🔔 提醒 · 🔁 重复),点开**单层**排期面板就地编辑三者,
/// 不再层层弹出日历对话框 / 时间选择器 / 重复子面板。
class DueReminderField extends StatelessWidget {
  const DueReminderField({
    required this.dueAt,
    required this.remindAt,
    this.repeatRule,
    super.key,
  });

  final DateTime? dueAt;
  final DateTime? remindAt;
  final String? repeatRule;

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ScheduleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // ── 未设置任何时间:淡色添加 chip ──
    if (dueAt == null && remindAt == null) {
      return ActionChip(
        avatar: Icon(Icons.schedule_rounded, size: 16, color: scheme.outline),
        label: Text(
          '+ 时间',
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        backgroundColor: Colors.transparent,
        onPressed: () => _openSheet(context),
      );
    }

    // ── 已设置:带颜色反馈的摘要 chip ──
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isOverdue =
        dueAt != null &&
        DateTime(dueAt!.year, dueAt!.month, dueAt!.day).isBefore(today);
    final isToday =
        dueAt != null &&
        DateTime(dueAt!.year, dueAt!.month, dueAt!.day) == today;

    Color bg;
    Color fg;
    if (isOverdue) {
      bg = scheme.errorContainer;
      fg = scheme.onErrorContainer;
    } else if (isToday) {
      bg = AppColors.high.withValues(alpha: 0.12);
      fg = AppColors.high;
    } else {
      bg = scheme.primaryContainer.withValues(alpha: 0.5);
      fg = scheme.onPrimaryContainer;
    }

    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: fg,
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dueAt != null) ...[
                Icon(Icons.event_rounded, size: 16, color: fg),
                const SizedBox(width: Spacing.xs),
                Text(formatDateCn(dueAt!), style: labelStyle),
              ],
              if (dueAt != null && remindAt != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  child: Text('·', style: labelStyle),
                ),
              if (remindAt != null) ...[
                Icon(Icons.notifications_rounded, size: 16, color: fg),
                const SizedBox(width: Spacing.xs),
                Text(formatDateTimeCn(remindAt!), style: labelStyle),
              ],
              if (repeatRule != null && repeatRule!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  child: Text('·', style: labelStyle),
                ),
                Icon(Icons.repeat_rounded, size: 16, color: fg),
                const SizedBox(width: Spacing.xs),
                Text(recurrenceSummary(repeatRule!), style: labelStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 排期面板 — 单层内嵌:截止日(内嵌日历) + 时间 + 提醒 + 重复
// ─────────────────────────────────────────────────────────────────────

/// 提醒提前量预设。
const _reminderOffsets = <(String, Duration)>[
  ('准时', Duration.zero),
  ('提前 10 分', Duration(minutes: 10)),
  ('提前 1 小时', Duration(hours: 1)),
  ('提前 1 天', Duration(days: 1)),
];

/// 截止时间快捷预设(小时, 分钟);(23,59) 视为「全天」。
const _timePresets = <(String, int, int)>[
  ('全天', 23, 59),
  ('09:00', 9, 0),
  ('14:00', 14, 0),
  ('20:00', 20, 0),
];

class _ScheduleSheet extends ConsumerStatefulWidget {
  const _ScheduleSheet();

  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  static DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59);
  }

  void _setDueDate(Task task, DateTime date) {
    final prev = task.dueAt;
    final h = prev?.hour ?? 23;
    final m = prev?.minute ?? 59;
    _repo.update(
      task.id,
      knownVersion: task.version,
      dueAt: Value(DateTime(date.year, date.month, date.day, h, m)),
    );
  }

  void _setDueTime(Task task, int hour, int minute) {
    final base = task.dueAt ?? DateTime.now();
    _repo.update(
      task.id,
      knownVersion: task.version,
      dueAt: Value(DateTime(base.year, base.month, base.day, hour, minute)),
    );
  }

  Future<void> _pickCustomTime(Task task) async {
    final initial = TimeOfDay.fromDateTime(task.dueAt ?? DateTime.now());
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t == null || !mounted) return;
    _setDueTime(task, t.hour, t.minute);
  }

  void _clearDue(Task task) {
    _repo.update(
      task.id,
      knownVersion: task.version,
      dueAt: const Value(null),
      remindAt: const Value(null),
    );
  }

  void _setReminderOffset(Task task, Duration off) {
    final due = task.dueAt ?? _endOfToday();
    _repo.update(
      task.id,
      knownVersion: task.version,
      dueAt: Value(due),
      remindAt: Value(due.subtract(off)),
    );
  }

  void _toggleReminder(Task task, {required bool enable}) {
    if (enable) {
      _setReminderOffset(task, Duration.zero);
    } else {
      _repo.update(
        task.id,
        knownVersion: task.version,
        remindAt: const Value(null),
      );
    }
  }

  void _setRecurrence(Task task, RecurrenceRuleDraft? draft) {
    final body = draft?.toRuleBody();
    // 重复需要 DTSTART 锚点(dueAt);若未设,落今天终点。
    final due = (body != null && task.dueAt == null)
        ? Value(_endOfToday())
        : const Value<DateTime?>.absent();
    _repo.update(
      task.id,
      knownVersion: task.version,
      repeatRule: Value(body),
      dueAt: due,
    );
  }

  CalendarDatePicker2Config _calendarConfig(ColorScheme scheme) {
    return CalendarDatePicker2Config(
      calendarType: CalendarDatePicker2Type.single,
      firstDayOfWeek: 1,
      selectedDayHighlightColor: scheme.primary,
      weekdayLabels: const ['日', '一', '二', '三', '四', '五', '六'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = ref.watch(currentTaskProvider).valueOrNull;
    if (task == null) return const SizedBox.shrink();

    final due = task.dueAt;
    final hasReminder = task.remindAt != null;
    final currentOffset = (due != null && task.remindAt != null)
        ? due.difference(task.remindAt!)
        : null;
    final draft = task.repeatRule == null
        ? null
        : RecurrenceRuleDraft.fromRuleBody(task.repeatRule!);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          Spacing.sm,
          Spacing.xl,
          Spacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '排期',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (due != null)
                  TextButton.icon(
                    onPressed: () => _clearDue(task),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('清除'),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xs),

            // ── 内嵌日历 ──
            CalendarDatePicker2(
              config: _calendarConfig(scheme),
              value: [if (due != null) due],
              onValueChanged: (dates) {
                final first = dates.isNotEmpty ? dates.first : null;
                if (first != null) _setDueDate(task, first);
              },
            ),

            const SizedBox(height: Spacing.xs),
            // ── 截止时间 ──
            _Label(text: '截止时间', scheme: scheme),
            Wrap(
              spacing: Spacing.sm,
              children: [
                for (final (label, h, m) in _timePresets)
                  ChoiceChip(
                    label: Text(label),
                    selected: due != null && due.hour == h && due.minute == m,
                    onSelected: due == null
                        ? null
                        : (_) => _setDueTime(task, h, m),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text(
                    due != null &&
                            !_timePresets.any(
                              (p) => due.hour == p.$2 && due.minute == p.$3,
                            )
                        ? '${due.hour.toString().padLeft(2, '0')}:'
                              '${due.minute.toString().padLeft(2, '0')}'
                        : '自定义',
                  ),
                  onPressed: due == null ? null : () => _pickCustomTime(task),
                ),
              ],
            ),

            Divider(
              height: Spacing.xl,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),

            // ── 提醒 ──
            Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: hasReminder ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: Spacing.md),
                Text('提醒', style: theme.textTheme.bodyLarge),
                const Spacer(),
                Switch(
                  value: hasReminder,
                  onChanged: (v) => _toggleReminder(task, enable: v),
                ),
              ],
            ),
            if (hasReminder) ...[
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.sm,
                children: [
                  for (final (label, off) in _reminderOffsets)
                    ChoiceChip(
                      label: Text(label),
                      selected: currentOffset == off,
                      onSelected: (_) => _setReminderOffset(task, off),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(
                  '提醒时间:${formatDateTimeCn(task.remindAt!)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ),
            ],

            Divider(
              height: Spacing.xl,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),

            // ── 重复(就地内嵌)──
            Row(
              children: [
                Icon(Icons.repeat_rounded, size: 20, color: scheme.outline),
                const SizedBox(width: Spacing.md),
                Text('重复', style: theme.textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            RecurrenceEditor(
              draft: draft,
              onChanged: (d) => _setRecurrence(task, d),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.scheme});
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.outline,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
