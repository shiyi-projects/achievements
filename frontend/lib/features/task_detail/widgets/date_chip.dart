import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/features/task_detail/widgets/date_helpers.dart';
import 'package:flutter/material.dart';

/// 智能日期 Chip — 未设值时显示淡色 ActionChip，已设值时带颜色反馈。
///
/// 颜色规则:
/// - 已过期 → 红底 (errorContainer)
/// - 今天到期 → 橙底
/// - 未来 → 主色淡底
class DateChip extends StatelessWidget {
  const DateChip({
    required this.date,
    required this.icon,
    required this.emptyLabel,
    required this.onTap,
    this.onClear,
    this.showTime = false,
    super.key,
  });
  final DateTime? date;
  final Widget icon;
  final String emptyLabel;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (date == null) {
      // 未设值：淡色 ActionChip
      return ActionChip(
        avatar: icon,
        label: Text(
          '+ $emptyLabel',
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        backgroundColor: Colors.transparent,
        onPressed: onTap,
      );
    }

    // 已设值：带颜色反馈的 Chip
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date!.year, date!.month, date!.day);
    final isOverdue = dateOnly.isBefore(today) && !showTime;
    final isToday = dateOnly == today;

    Color chipBg;
    Color chipFg;
    if (isOverdue) {
      chipBg = scheme.errorContainer;
      chipFg = scheme.onErrorContainer;
    } else if (isToday) {
      chipBg = AppColors.high.withValues(alpha: 0.12);
      chipFg = AppColors.high;
    } else {
      chipBg = scheme.primaryContainer.withValues(alpha: 0.5);
      chipFg = scheme.onPrimaryContainer;
    }

    final label = showTime ? formatDateTimeCn(date!) : formatDateCn(date!);

    return InputChip(
      avatar: icon,
      label: Text(label),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: chipFg,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: chipBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      side: BorderSide.none,
      deleteIcon: AppIcons.svgIcon(AppIcons.close, size: 14),
      onDeleted: onClear,
      onPressed: onTap,
    );
  }
}
