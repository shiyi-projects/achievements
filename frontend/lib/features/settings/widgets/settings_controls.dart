import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// 设置页的控件集合(极简风格,仅设置页使用)。
///
/// 设计取向:Apple 的克制 + Linear 的效率感。
/// - 层级只靠**排版、间距、发丝分割线**建立,不用卡片投影与填充色块
/// - 背景保持中性(白 / 浅灰 / 深灰),品牌色只用来标记「当前选中」和主操作
/// - 圆角收在 6–10px([Radii.control] / [Radii.panel]),避免 Material 的圆润感
/// - 行高紧凑,桌面端一屏能看到更多设置项
///
/// 组件:
/// - [SettingsSection] 分节:小号全大写标题 + 通栏细线分隔的若干行
/// - [SettingsRow] 标准行:标题(+ 副标题) + 右侧值 / 控件
/// - [SettingsField] 自定义控件行:标签在上、控件在下
/// - [SettingsSegmented] 分段选择器:替代 Material 的 SegmentedButton
/// - [SettingsMiniButton] 行内小按钮:替代 Filled/Outlined/TextButton

/// 行的左右内边距。分割线通栏(不缩进),这是 Linear 式列表的关键特征之一。
const double kSettingsHPad = Spacing.lg;

/// 行的上下内边距。比 Material 的 ListTile 紧,信息密度更高。
const double _vPad = 10;

/// 发丝线:1 物理像素观感的浅灰,深浅色下都不抢注意力。
class SettingsHairline extends StatelessWidget {
  const SettingsHairline({super.key, this.inset = false});

  /// 是否内缩到与文字左对齐(组内行之间用),否则通栏(分节之间用)。
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 1,
      margin: EdgeInsets.only(left: inset ? kSettingsHPad : 0),
      color: scheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

/// 一个设置分节:标题 + 若干行 + 可选脚注。没有卡片、没有边框,行与行之间
/// 用发丝线分隔,分节之间靠留白与一条通栏线区隔。
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.title,
    this.footer,
    super.key,
  });

  final List<Widget> children;
  final String? title;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const SettingsHairline(inset: true));
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSettingsHPad,
              Spacing.xl,
              kSettingsHPad,
              Spacing.sm,
            ),
            child: Text(
              title!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: scheme.outline,
              ),
            ),
          ),
        const SettingsHairline(),
        ...rows,
        const SettingsHairline(),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSettingsHPad,
              Spacing.sm,
              kSettingsHPad,
              0,
            ),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.5,
                color: scheme.outline,
              ),
            ),
          ),
      ],
    );
  }
}

/// 标准设置行:标题(+ 副标题) + 右侧值文字 / 控件。
///
/// [accent] 为 true 时标题用品牌色 —— 全页只留给「立即同步」这类主操作,
/// 以及需要提示的异常态(此时传 [titleColor])。
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.leadingDot,
    this.titleColor,
    this.monospaceTitle = false,
    this.showChevron = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// 右侧弱化值文字。
  final String? value;

  /// 右侧控件(与 [value] 可共存)。
  final Widget? trailing;

  /// 标题前的状态圆点(同步状态等)。极简风格里用一个 6px 圆点代替彩色图标。
  final Color? leadingDot;

  final Color? titleColor;

  /// 用等宽字体渲染标题(用户 ID 这类标识串)。
  final bool monospaceTitle;

  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kSettingsHPad,
        vertical: _vPad,
      ),
      child: Row(
        children: [
          if (leadingDot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: leadingDot,
                shape: BoxShape.circle,
              ),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: monospaceTitle ? 12 : 14,
                    letterSpacing: monospaceTitle ? 0 : null,
                    fontFamily: monospaceTitle ? 'Consolas' : null,
                    fontFamilyFallback: monospaceTitle
                        ? const ['Menlo', 'monospace']
                        : null,
                    // 标识串(用户 ID)是给人复制的,不是要读的:弱化成次要文字,
                    // 免得一长串等宽字符在页面上压过真正的设置项。
                    color:
                        titleColor ??
                        (monospaceTitle
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: scheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.md),
              child: Text(
                value!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.md),
            trailing!,
          ],
          if (showChevron)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.xs),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: scheme.outline,
              ),
            ),
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) return content;
    return _HoverHighlight(onTap: tap, child: content);
  }
}

/// 承载自定义控件的行:标签在上、控件在下。
class SettingsField extends StatelessWidget {
  const SettingsField({
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
      padding: const EdgeInsets.fromLTRB(
        kSettingsHPad,
        Spacing.md,
        kSettingsHPad,
        Spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          const SizedBox(height: Spacing.md),
          child,
        ],
      ),
    );
  }
}

/// 行的悬停反馈:极轻的底色变化,不用水波纹(水波纹是 Material 的签名动效)。
class _HoverHighlight extends StatefulWidget {
  const _HoverHighlight({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<_HoverHighlight> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: MotionDurations.instant,
          color: _hovering
              ? scheme.onSurface.withValues(alpha: 0.04)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 分段选择器。外框一条细边,选中项是一块「浮起」的中性色块(靠底色与边框
/// 区分,不用品牌色填充),纯文字、无图标,比 Material 的 SegmentedButton 更紧凑。
class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<({T value, String label})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isLight
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: _Segment(
                label: segment.label,
                selected: segment.value == selected,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: MotionDurations.instant,
          curve: MotionCurves.decelerate,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.controlInner),
            border: selected
                ? Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  )
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              letterSpacing: 0,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// 行内小按钮。扁平、细边、小圆角;[accent] 时用品牌色文字标记主操作,
/// [danger] 时用错误色。任何状态都不填充大色块。
class SettingsMiniButton extends StatelessWidget {
  const SettingsMiniButton({
    required this.label,
    required this.onPressed,
    this.accent = false,
    this.danger = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final fg = !enabled
        ? scheme.outline
        : danger
        ? scheme.error
        : accent
        ? scheme.primary
        : scheme.onSurface;

    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              letterSpacing: 0,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// 细线进度指示:替代 CircularProgressIndicator 在行内的存在感。
class SettingsSpinner extends StatelessWidget {
  const SettingsSpinner({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
