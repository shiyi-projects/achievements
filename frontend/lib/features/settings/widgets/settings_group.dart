import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// iOS 风格分组列表组件集合(仅设置页使用)。
///
/// - [SettingsGroup]: 一块圆角分组卡,内部子行自动用细分隔线隔开,组标题渲染在
///   卡片上方、组脚注渲染在卡片下方(均为弱化的辅助文字)。
/// - [SettingsTile]: 标准行——图标 + 标题(+ 副标题) + 右侧值/控件/箭头,可点击。
/// - [SettingsBlock]: 承载自定义控件的行(标签在上、控件在下),用于分段选择器、
///   色卡等不适合塞进单行的场景。
///
/// 全局沿用 `surfaceContainer` 表面 + 细边框,与 [SurfaceCard] 的视觉语言一致,
/// 但排版改为「分组内嵌列表」而非一块块独立卡片,贴近 iOS 设置页观感。

/// 行内统一的水平/垂直内边距,保证组内各行对齐。
const double _hPad = Spacing.base;
const double _vPad = Spacing.md;

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.children,
    this.title,
    this.footer,
    super.key,
  });

  /// 组内各行;相邻两行间自动插入内嵌分隔线。
  final List<Widget> children;

  /// 组标题(卡片上方的弱化小标题)。
  final String? title;

  /// 组脚注(卡片下方的弱化说明文字,iOS 习惯把解释性文案放这里)。
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: _hPad, endIndent: _hPad));
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.lg,
              Spacing.md,
              Spacing.sm,
            ),
            child: Text(
              title!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
        // 用 Material(而非 Container)作为分组底色,内部 InkWell 水波纹才能正确
        // 绘制在卡片表面上。
        Material(
          color: scheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.sm,
              Spacing.md,
              0,
            ),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
          ),
      ],
    );
  }
}

/// 标准设置行。[value] 是右侧弱化值文字的便捷写法;需要按钮/开关等控件时用
/// [trailing]。[showChevron] 在最右侧追加一个跳转箭头。
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    this.leading,
    this.leadingWidget,
    this.leadingColor,
    this.titleColor,
    this.subtitle,
    this.value,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData? leading;

  /// 自定义前导图(如 SVG 品牌图标);优先于 [leading]。
  final Widget? leadingWidget;
  final Color? leadingColor;
  final Color? titleColor;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: _vPad),
      child: Row(
        children: [
          if (leadingWidget != null) ...[
            SizedBox(
              width: 22,
              height: 22,
              child: Center(child: leadingWidget),
            ),
            const SizedBox(width: Spacing.md),
          ] else if (leading != null) ...[
            Icon(
              leading,
              size: 22,
              color: leadingColor ?? scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(color: titleColor),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.sm),
              child: Text(
                value!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.sm),
            trailing!,
          ],
          if (showChevron)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.xs),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.outline,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// 承载自定义控件的行:标签在上、控件在下,可附一行说明。
class SettingsBlock extends StatelessWidget {
  const SettingsBlock({
    required this.label,
    required this.child,
    this.description,
    super.key,
  });

  final String label;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: _vPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: Spacing.sm),
          child,
        ],
      ),
    );
  }
}
