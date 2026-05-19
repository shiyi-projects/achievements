import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/features/task_detail/widgets/date_helpers.dart';
import 'package:flutter/material.dart';

/// 可折叠的任务元信息区域。
///
/// 默认只显示"更新于 X 分钟前"，点击展开显示全部时间戳。
class CollapsibleMeta extends StatelessWidget {
  const CollapsibleMeta({required this.task, super.key});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = '更新于 ${relativeTimeCn(task.updatedAt)}';

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: Spacing.sm),
        dense: true,
        leading:
            Icon(Icons.info_outline_rounded, size: 18, color: scheme.outline),
        title: Text(
          summary,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
        children: [
          _MetaLine(label: '创建', value: relativeTimeCn(task.createdAt)),
          _MetaLine(label: '更新', value: relativeTimeCn(task.updatedAt)),
          if (task.completedAt != null)
            _MetaLine(
              label: '完成',
              value: relativeTimeCn(task.completedAt!),
            ),
          if (task.deletedAt != null)
            _MetaLine(
              label: '删除',
              value: relativeTimeCn(task.deletedAt!),
            ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 48,
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
