import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/features/focus/utils/duration_format.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// 计划面板中的单个任务卡片。
///
/// 展示任务标题、进度条（actual / planned）和操作按钮。
class PlanTaskCard extends StatelessWidget {
  const PlanTaskCard({
    super.key,
    required this.plan,
    required this.taskTitle,
    required this.onStart,
    required this.onDelete,
    required this.onEditDuration,
    this.isActive = false,
    this.isOverdue = false,
  });

  final FocusPlan plan;
  final String taskTitle;
  final VoidCallback onStart;
  final VoidCallback onDelete;
  final VoidCallback onEditDuration;
  final bool isActive;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plannedSeconds = plan.plannedMinutes * 60;
    final isComplete = plan.actualSeconds >= plannedSeconds;
    final progress = plannedSeconds > 0
        ? (plan.actualSeconds / plannedSeconds).clamp(0.0, 1.0)
        : 0.0;

    final statusColor = isOverdue
        ? const Color(0xFFFF9800)
        : isComplete
            ? const Color(0xFF4CAF50)
            : isActive
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.3);

    return Dismissible(
      key: ValueKey(plan.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.base),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Icon(Icons.delete_outline, color: scheme.error, size: 20),
      ),
      child: GestureDetector(
        onTap: isComplete ? null : onStart,
        onLongPress: onEditDuration,
        child: AnimatedContainer(
          duration: MotionDurations.fast,
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: isActive
                ? scheme.primary.withValues(alpha: 0.08)
                : scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: isActive
                  ? scheme.primary.withValues(alpha: 0.2)
                  : scheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 标题行 ──
              Row(
                children: [
                  // 状态点
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // 标题
                  Expanded(
                    child: Text(
                      taskTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withValues(alpha: 0.85),
                        decoration:
                            isComplete ? TextDecoration.lineThrough : null,
                        decorationColor: scheme.outline,
                      ),
                    ),
                  ),
                  // 时间
                  Text(
                    '${formatFocusDuration(plan.actualSeconds)} / ${plan.plannedMinutes}m',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isComplete) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.8),
                    ),
                  ] else if (isOverdue) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: const Color(0xFFFF9800).withValues(alpha: 0.8),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Spacing.sm),
              // ── 进度条 ──
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(statusColor),
                ),
              ),
              // ── 操作按钮 ──
              if (!isComplete && !isOverdue) ...[
                const SizedBox(height: Spacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onStart,
                    icon: Icon(
                      isActive
                          ? Icons.play_circle_filled
                          : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isActive ? '继续专注' : '开始专注',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: 2,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
