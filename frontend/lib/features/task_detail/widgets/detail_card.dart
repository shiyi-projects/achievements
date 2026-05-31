import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 详情面板内的分组卡片容器。
///
/// 提供统一的视觉风格：`surfaceContainer` 背景 + 圆角 + subtle 边框。
/// 可选标题行带图标 + 标题 + 右侧 widget（如统计 badge）。
class DetailCard extends StatelessWidget {
  const DetailCard({
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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.input),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      padding: padding ?? const EdgeInsets.all(Spacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: Spacing.sm)],
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
    );
  }
}
