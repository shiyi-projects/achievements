import 'dart:async';

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

DateTime _endOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 23, 59);
}

Task? _currentTask(WidgetRef ref) => ref.read(currentTaskProvider).valueOrNull;

/// 排期面板。各子区块按字段**精确订阅**(Riverpod select),点提醒只重建提醒区、
/// 点日期才重建日历——避免任一编辑都重绘开销大的内嵌日历造成的卡顿。
class _ScheduleSheet extends ConsumerWidget {
  const _ScheduleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final taskId = ref.watch(
      currentTaskProvider.select((a) => a.valueOrNull?.id),
    );
    if (taskId == null) return const SizedBox.shrink();
    final initialRule = ref.read(currentTaskProvider).valueOrNull?.repeatRule;

    Divider divider() => Divider(
      height: Spacing.xl,
      color: scheme.outlineVariant.withValues(alpha: 0.4),
    );

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
            Text(
              '排期',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            _DueSection(taskId: taskId),
            divider(),
            _ReminderBlock(taskId: taskId),
            divider(),
            _RecurrenceSection(taskId: taskId, initialRule: initialRule),
          ],
        ),
      ),
    );
  }
}

/// 截止日 + 截止时间区块。
///
/// 默认紧凑:一行「今天/明天/本周末/选日期」快捷 + 截止时间 chip。大日历**默认收起**,
/// 点「选日期」才就地展开(非弹窗),避免常驻占地 + 选「每周」时被 sheet 改尺寸连带重绘。
class _DueSection extends ConsumerStatefulWidget {
  const _DueSection({required this.taskId});
  final String taskId;

  @override
  ConsumerState<_DueSection> createState() => _DueSectionState();
}

class _DueSectionState extends ConsumerState<_DueSection> {
  bool _calendarOpen = false;

  static bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  void _setDate(DateTime date) {
    final t = _currentTask(ref);
    if (t == null) return;
    final prev = t.dueAt;
    final h = prev?.hour ?? 23;
    final m = prev?.minute ?? 59;
    ref
        .read(taskRepositoryProvider)
        .update(
          t.id,
          knownVersion: t.version,
          dueAt: Value(DateTime(date.year, date.month, date.day, h, m)),
        );
  }

  void _setTime(int hour, int minute) {
    final t = _currentTask(ref);
    if (t == null) return;
    final base = t.dueAt ?? DateTime.now();
    ref
        .read(taskRepositoryProvider)
        .update(
          t.id,
          knownVersion: t.version,
          dueAt: Value(DateTime(base.year, base.month, base.day, hour, minute)),
        );
  }

  Future<void> _pickCustomTime(DateTime? due) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(due ?? DateTime.now()),
    );
    if (picked == null || !mounted) return;
    _setTime(picked.hour, picked.minute);
  }

  void _clear() {
    final t = _currentTask(ref);
    if (t == null) return;
    ref
        .read(taskRepositoryProvider)
        .update(
          t.id,
          knownVersion: t.version,
          dueAt: const Value(null),
          remindAt: const Value(null),
        );
    setState(() => _calendarOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = ref.watch(
      currentTaskProvider.select((a) => a.valueOrNull?.dueAt),
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekend = today.add(
      Duration(days: (DateTime.saturday - today.weekday) % 7),
    );
    final isCustomTime =
        due != null &&
        !_timePresets.any((p) => due.hour == p.$2 && due.minute == p.$3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Label(text: '截止日', scheme: scheme),
            const Spacer(),
            if (due != null)
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('清除'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        // ── 日期快捷 + 展开日历 ──
        Wrap(
          spacing: Spacing.sm,
          children: [
            ChoiceChip(
              label: const Text('今天'),
              selected: _sameDay(due, today),
              onSelected: (_) => _setDate(today),
            ),
            ChoiceChip(
              label: const Text('明天'),
              selected: _sameDay(due, tomorrow),
              onSelected: (_) => _setDate(tomorrow),
            ),
            ChoiceChip(
              label: const Text('本周末'),
              selected: _sameDay(due, weekend),
              onSelected: (_) => _setDate(weekend),
            ),
            ActionChip(
              avatar: Icon(
                _calendarOpen ? Icons.expand_less_rounded : Icons.event_rounded,
                size: 16,
              ),
              label: Text(
                due != null &&
                        !_sameDay(due, today) &&
                        !_sameDay(due, tomorrow) &&
                        !_sameDay(due, weekend)
                    ? formatDateCn(due)
                    : '选日期',
              ),
              onPressed: () => setState(() => _calendarOpen = !_calendarOpen),
            ),
          ],
        ),
        // ── 内嵌日历(默认收起;RepaintBoundary 隔离重绘)──
        if (_calendarOpen)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: RepaintBoundary(child: _DueCalendar(taskId: widget.taskId)),
          ),

        const SizedBox(height: Spacing.sm),
        _Label(text: '截止时间', scheme: scheme),
        Wrap(
          spacing: Spacing.sm,
          children: [
            for (final (label, h, m) in _timePresets)
              ChoiceChip(
                label: Text(label),
                selected: due != null && due.hour == h && due.minute == m,
                onSelected: due == null ? null : (_) => _setTime(h, m),
              ),
            ActionChip(
              avatar: const Icon(Icons.schedule_rounded, size: 16),
              label: Text(
                isCustomTime
                    ? '${due.hour.toString().padLeft(2, '0')}:'
                          '${due.minute.toString().padLeft(2, '0')}'
                    : '自定义',
              ),
              onPressed: due == null ? null : () => _pickCustomTime(due),
            ),
          ],
        ),
      ],
    );
  }
}

/// 内嵌日历:仅订阅截止日的「日期」部分(时分变化不重建)。
class _DueCalendar extends ConsumerWidget {
  const _DueCalendar({required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dueDay = ref.watch(
      currentTaskProvider.select((a) {
        final d = a.valueOrNull?.dueAt;
        return d == null ? null : DateTime(d.year, d.month, d.day);
      }),
    );
    return CalendarDatePicker2(
      config: CalendarDatePicker2Config(
        calendarType: CalendarDatePicker2Type.single,
        firstDayOfWeek: 1,
        selectedDayHighlightColor: scheme.primary,
        weekdayLabels: const ['日', '一', '二', '三', '四', '五', '六'],
      ),
      value: [if (dueDay != null) dueDay],
      onValueChanged: (dates) {
        final first = dates.isNotEmpty ? dates.first : null;
        if (first == null) return;
        final t = _currentTask(ref);
        if (t == null) return;
        final prev = t.dueAt;
        final h = prev?.hour ?? 23;
        final m = prev?.minute ?? 59;
        ref
            .read(taskRepositoryProvider)
            .update(
              t.id,
              knownVersion: t.version,
              dueAt: Value(DateTime(first.year, first.month, first.day, h, m)),
            );
      },
    );
  }
}

/// 提醒区块:仅订阅 (dueAt, remindAt)。点提醒 chip 只重建本区,不碰日历。
class _ReminderBlock extends ConsumerWidget {
  const _ReminderBlock({required this.taskId});
  final String taskId;

  void _setOffset(WidgetRef ref, Duration off) {
    final t = _currentTask(ref);
    if (t == null) return;
    final due = t.dueAt ?? _endOfToday();
    ref
        .read(taskRepositoryProvider)
        .update(
          t.id,
          knownVersion: t.version,
          dueAt: Value(due),
          remindAt: Value(due.subtract(off)),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rec = ref.watch(
      currentTaskProvider.select((a) {
        final t = a.valueOrNull;
        return (due: t?.dueAt, remind: t?.remindAt);
      }),
    );
    final hasReminder = rec.remind != null;
    final currentOffset = (rec.due != null && rec.remind != null)
        ? rec.due!.difference(rec.remind!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              onChanged: (v) {
                if (v) {
                  _setOffset(ref, Duration.zero);
                } else {
                  final t = _currentTask(ref);
                  if (t == null) return;
                  ref
                      .read(taskRepositoryProvider)
                      .update(
                        t.id,
                        knownVersion: t.version,
                        remindAt: const Value(null),
                      );
                }
              },
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
                  onSelected: (_) => _setOffset(ref, off),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: Text(
              '提醒时间:${formatDateTimeCn(rec.remind!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 独立的「重复」编辑区块。
///
/// 自管本地草稿 + debounce 写库:间隔/次数连点只触发**自身** setState,不会重建
/// 父面板里那个开销大的内嵌日历,从根上消除「调间隔很卡」。
class _RecurrenceSection extends ConsumerStatefulWidget {
  const _RecurrenceSection({required this.taskId, required this.initialRule});

  final String taskId;
  final String? initialRule;

  @override
  ConsumerState<_RecurrenceSection> createState() => _RecurrenceSectionState();
}

class _RecurrenceSectionState extends ConsumerState<_RecurrenceSection> {
  late RecurrenceRuleDraft? _draft = widget.initialRule == null
      ? null
      : RecurrenceRuleDraft.fromRuleBody(widget.initialRule!);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _flush();
    super.dispose();
  }

  void _onChanged(RecurrenceRuleDraft? d) {
    setState(() => _draft = d);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 450), _flush);
  }

  void _flush() {
    _timer?.cancel();
    final task = ref.read(currentTaskProvider).valueOrNull;
    if (task == null || task.id != widget.taskId) return;
    final body = _draft?.toRuleBody();
    if (body == task.repeatRule) return; // 无变化
    // 重复需要 DTSTART 锚点(dueAt);若未设,落今天终点。
    final now = DateTime.now();
    final due = (body != null && task.dueAt == null)
        ? Value(DateTime(now.year, now.month, now.day, 23, 59))
        : const Value<DateTime?>.absent();
    ref
        .read(taskRepositoryProvider)
        .update(
          task.id,
          knownVersion: task.version,
          repeatRule: Value(body),
          dueAt: due,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.repeat_rounded, size: 20, color: scheme.outline),
            const SizedBox(width: Spacing.md),
            Text('重复', style: theme.textTheme.bodyLarge),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        RecurrenceEditor(draft: _draft, onChanged: _onChanged),
      ],
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
