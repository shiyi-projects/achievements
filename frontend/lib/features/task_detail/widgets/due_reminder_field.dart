import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/task_detail/widgets/date_helpers.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 「截止日期 + 提醒」合并入口。
///
/// chip 展示两者摘要(📅 截止 · 🔔 提醒),点开统一底部面板同时编辑两者,
/// 取代原先两个各自弹日历的独立 chip。
class DueReminderField extends StatelessWidget {
  const DueReminderField({
    required this.dueAt,
    required this.remindAt,
    super.key,
  });

  final DateTime? dueAt;
  final DateTime? remindAt;

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DueReminderSheet(),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 统一编辑面板 — 截止日期 + 提醒
// ─────────────────────────────────────────────────────────────────────

/// 监听 [currentTaskProvider] 以保证选完日期后面板内的值实时刷新。
class _DueReminderSheet extends ConsumerStatefulWidget {
  const _DueReminderSheet();

  @override
  ConsumerState<_DueReminderSheet> createState() => _DueReminderSheetState();
}

class _DueReminderSheetState extends ConsumerState<_DueReminderSheet> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);

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

  Future<DateTime?> _pickDate(DateTime initial) async {
    final results = await showCalendarDatePicker2Dialog(
      context: context,
      config: _calendarConfig(),
      dialogSize: const Size(340, 400),
      borderRadius: BorderRadius.circular(Radii.sheet),
      value: [initial],
    );
    if (results == null || results.isEmpty) return null;
    return results.first;
  }

  Future<void> _pickDueDate(Task task) async {
    final picked = await _pickDate(task.dueAt ?? DateTime.now());
    if (picked == null || !mounted) return;
    await _repo.update(
      task.id,
      knownVersion: task.version,
      dueAt: Value(DateTime(picked.year, picked.month, picked.day, 23, 59)),
    );
  }

  Future<void> _pickReminder(Task task) async {
    final initial =
        task.remindAt ?? DateTime.now().add(const Duration(hours: 1));
    final date = await _pickDate(initial);
    if (date == null || !mounted) return;
    // 等日历退场动画结束再弹时间选择器,避免两个 dialog 动画同时播放
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    await _repo.update(
      task.id,
      knownVersion: task.version,
      remindAt: Value(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      ),
    );
  }

  Future<void> _toggleReminder(Task task, {required bool enable}) async {
    if (enable) {
      await _pickReminder(task);
    } else {
      await _repo.update(
        task.id,
        knownVersion: task.version,
        remindAt: const Value(null),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final task = ref.watch(currentTaskProvider).valueOrNull;
    if (task == null) return const SizedBox.shrink();

    final hasReminder = task.remindAt != null;

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
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.base),
              child: Text(
                '时间',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // ── 截止日期 ──
            _SettingRow(
              icon: Icons.event_rounded,
              label: '截止日期',
              valueLabel: task.dueAt != null ? formatDateCn(task.dueAt!) : null,
              onTap: () => _pickDueDate(task),
              onClear: task.dueAt != null
                  ? () => _repo.update(
                      task.id,
                      knownVersion: task.version,
                      dueAt: const Value(null),
                    )
                  : null,
            ),

            Divider(
              height: Spacing.lg,
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),

            // ── 提醒(开关 + 时间) ──
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
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: hasReminder
                  ? Padding(
                      padding: const EdgeInsets.only(left: 32, top: Spacing.xs),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          label: Text(formatDateTimeCn(task.remindAt!)),
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.chip),
                          ),
                          side: BorderSide(
                            color: scheme.primary.withValues(alpha: 0.3),
                          ),
                          backgroundColor: scheme.primary.withValues(
                            alpha: 0.06,
                          ),
                          onPressed: () => _pickReminder(task),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 面板内一行「标签 + 值按钮(+ 清除)」。
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String? valueLabel;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasValue = valueLabel != null;

    return Row(
      children: [
        Icon(icon, size: 20, color: hasValue ? scheme.primary : scheme.outline),
        const SizedBox(width: Spacing.md),
        Text(label, style: theme.textTheme.bodyLarge),
        const Spacer(),
        if (hasValue && onClear != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: Icon(Icons.close_rounded, color: scheme.outline),
            tooltip: '清除',
            onPressed: onClear,
          ),
        ActionChip(
          label: Text(hasValue ? valueLabel! : '未设置'),
          labelStyle: theme.textTheme.labelMedium?.copyWith(
            color: hasValue ? scheme.primary : scheme.outline,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          side: BorderSide(
            color: hasValue
                ? scheme.primary.withValues(alpha: 0.3)
                : scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          backgroundColor: hasValue
              ? scheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          onPressed: onTap,
        ),
      ],
    );
  }
}
