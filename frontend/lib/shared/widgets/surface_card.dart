import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 通用分组卡片容器。
///
/// 全局统一的分区视觉：`surfaceContainer` 背景 + 圆角 + 可见边框,
/// 供任务详情面板、设置页等所有「分组卡」场景复用,保证跨页一致。
/// 可选标题行带图标 + 标题 + 右侧 widget（如统计 badge）。
///
/// [collapsible] 为 true 且有 [title] 时,标题行可点击展开/收起,展开态通过
/// [PageStorage] 按 widget 的 key 记忆(传 PageStorageKey 即可跨重建保留)。
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    required this.children,
    this.icon,
    this.title,
    this.trailing,
    this.padding,
    this.collapsible = false,
    this.initiallyExpanded = true,
    super.key,
  });

  final List<Widget> children;
  final Widget? icon;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  late bool _expanded = widget.initiallyExpanded;
  bool _restored = false;

  bool get _canCollapse => widget.collapsible && widget.title != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_canCollapse && !_restored) {
      final saved = PageStorage.of(context).readState(context);
      if (saved is bool) _expanded = saved;
      _restored = true;
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    PageStorage.of(context).writeState(context, _expanded);
  }

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
        padding: widget.padding ?? const EdgeInsets.all(Spacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.title != null) ...[
              _buildTitleRow(theme, scheme),
              if (!_canCollapse || _expanded)
                const SizedBox(height: Spacing.md),
            ],
            AnimatedCrossFade(
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
              secondChild: const SizedBox(width: double.infinity),
              crossFadeState: (!_canCollapse || _expanded)
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(ThemeData theme, ColorScheme scheme) {
    final row = Row(
      children: [
        if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: Spacing.sm),
        ],
        Expanded(
          child: Text(
            widget.title!,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.trailing != null) widget.trailing!,
        if (_canCollapse)
          AnimatedRotation(
            turns: _expanded ? 0 : -0.25,
            duration: const Duration(milliseconds: 180),
            child: Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: scheme.outline,
            ),
          ),
      ],
    );
    if (!_canCollapse) return row;
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(Radii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: row,
      ),
    );
  }
}
