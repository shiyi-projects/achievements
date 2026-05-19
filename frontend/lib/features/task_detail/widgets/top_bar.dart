import 'package:achievements/core/theme/app_dimensions.dart';
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            icon: const Icon(Icons.close_rounded),
            tooltip: '关闭',
            onPressed: onClose,
          ),
          const Spacer(),
          // ── 完成切换 ──
          AnimatedCompleteButton(
            completed: completed,
            onTap: onToggleComplete,
          ),
          const SizedBox(width: Spacing.xs),
          IconButton(
            icon: Icon(
              starred ? Icons.star_rounded : Icons.star_outline_rounded,
              color: starred ? scheme.tertiary : null,
            ),
            tooltip: starred ? '取消星标' : '添加星标',
            onPressed: onToggleStar,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
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
            itemBuilder: (_) => [
              if (!isTrashed)
                const PopupMenuItem(value: 'del', child: Text('移至回收站'))
              else ...[
                const PopupMenuItem(value: 'res', child: Text('恢复')),
                const PopupMenuItem(
                  value: 'hdel',
                  child: Text('永久删除'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 带动画的完成按钮
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
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
            child: completed
                ? const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white)
                : null,
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
