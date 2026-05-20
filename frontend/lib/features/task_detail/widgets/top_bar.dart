import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────
// Top Bar for Task Detail Panel
// ─────────────────────────────────────────────────────────────────────

class TaskDetailTopBar extends StatelessWidget {
  const TaskDetailTopBar({
    required this.starred,
    required this.completed,
    required this.isTrashed,
    required this.onClose,
    required this.onToggleComplete,
    required this.onToggleStar,
    required this.onSoftDelete,
    required this.onRestore,
    required this.onHardDelete,
    this.parentTaskTitle,
    this.onBackToParent,
    super.key,
  });

  final bool starred;
  final bool completed;
  final bool isTrashed;
  final VoidCallback onClose;
  final VoidCallback onToggleComplete;
  final VoidCallback onToggleStar;
  final VoidCallback onSoftDelete;
  final VoidCallback onRestore;
  final VoidCallback onHardDelete;

  /// 父任务标题。非 null 时显示面包屑导航。
  final String? parentTaskTitle;

  /// 返回父任务的回调。
  final VoidCallback? onBackToParent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
            icon: AppIcons.svgIcon(AppIcons.close),
            tooltip: '关闭 (Esc)',
            onPressed: onClose,
          ),
          // ── 面包屑：显示父任务名，可一键返回 ──
          if (parentTaskTitle != null) ...[
            const SizedBox(width: Spacing.xs),
            Icon(
              Icons.chevron_left_rounded,
              size: 16,
              color: scheme.outline,
            ),
            Flexible(
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.chip),
                onTap: onBackToParent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  child: Text(
                    parentTaskTitle!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          // ── 完成切换（带弹性动画） ──
          AnimatedCompleteButton(
            completed: completed,
            onTap: onToggleComplete,
          ),
          const SizedBox(width: Spacing.xs),
          // ── 星标（带旋转缩放，ValueKey 驱动动画） ──
          IconButton(
            icon: AnimatedSwitcher(
              duration: MotionDurations.fast,
              transitionBuilder: (child, anim) {
                return RotationTransition(
                  turns: Tween(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(
                      parent: anim,
                      curve: MotionCurves.bouncySpring,
                    ),
                  ),
                  child: ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                key: ValueKey(starred),
                child: AppIcons.svgIcon(AppIcons.important),
              ),
            ),
            tooltip: starred ? '取消星标' : '添加星标',
            onPressed: onToggleStar,
          ),
          PopupMenuButton<String>(
            icon: AppIcons.svgIcon(AppIcons.more),
            tooltip: '更多',
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
            itemBuilder: (ctx) {
              final errColor = Theme.of(ctx).colorScheme.error;
              return [
                if (!isTrashed)
                  PopupMenuItem(
                    value: 'del',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18,
                          color: errColor),
                        const SizedBox(width: Spacing.md),
                        Text('移至回收站',
                          style: TextStyle(color: errColor)),
                      ],
                    ),
                  )
                else ...[
                  const PopupMenuItem(
                    value: 'res',
                    child: Row(
                      children: [
                        Icon(Icons.restore_rounded, size: 18),
                        SizedBox(width: Spacing.md),
                        Text('恢复'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'hdel',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever_rounded, size: 18,
                          color: errColor),
                        const SizedBox(width: Spacing.md),
                        Text('永久删除',
                          style: TextStyle(color: errColor)),
                      ],
                    ),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 带动画的完成按钮 — 弹性缩放 + 颜色过渡
// ─────────────────────────────────────────────────────────────────────

class AnimatedCompleteButton extends StatelessWidget {
  const AnimatedCompleteButton({
    required this.completed,
    required this.onTap,
    super.key,
  });

  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.circle),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: AnimatedScale(
            scale: completed ? 1.08 : 1.0,
            duration: MotionDurations.fast,
            curve: MotionCurves.bouncySpring,
            child: AnimatedContainer(
              duration: MotionDurations.normal,
              curve: MotionCurves.bouncySpring,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? scheme.primary : Colors.transparent,
                border: Border.all(
                  color: completed ? scheme.primary : scheme.outline,
                  width: 2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: MotionDurations.fast,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: MotionCurves.bouncySpring,
                  ),
                  child: child,
                ),
                child: completed
                    ? SizedBox(
                        key: const ValueKey('done'),
                        width: 14,
                        height: 14,
                        child: AppIcons.svgIcon(AppIcons.check, size: 14),
                      )
                    : const SizedBox.shrink(key: ValueKey('undone')),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 分区标题
// ─────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.outline,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}
