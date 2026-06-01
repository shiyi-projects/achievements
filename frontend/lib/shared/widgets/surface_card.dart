import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 通用分组卡片容器。
///
/// 全局统一的分区视觉：`surfaceContainer` 背景 + 圆角 + 可见边框,
/// 供任务详情面板、设置页等所有「分组卡」场景复用,保证跨页一致。
/// 可选标题行带图标 + 标题 + 右侧 widget（如统计 badge）。
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.children,
    this.icon,
    this.title,
    this.trailing,
    this.padding,
    super.key,
  });

  final List<Widget> children;
  final Widget? icon;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // 用 Material（而非 Container+BoxDecoration）作为卡片底色:
    // 卡片本身即一个 Material 表面,内部 ListTile / InkWell 的水波纹
    // 才能画在卡片上而非被不透明背景遮挡（否则触发 ListTile 断言）。
    return Material(
      color: scheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(Spacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: Spacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: Spacing.md),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
