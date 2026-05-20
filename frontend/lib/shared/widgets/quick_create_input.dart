import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:flutter/material.dart';

/// 底部快速创建任务输入框。
///
/// 仅负责呈现 + 收集输入,创建任务的副作用由调用方在 [onSubmit] 里完成
/// (拿到去空后的 title 字符串)。空字符串会被吞掉,不触发回调。
///
/// 样式遵循 ui_design_spec §7.1:
///   - surfaceContainerHigh 背景
///   - add_circle_outline 前缀图标
///   - 16px 圆角
///
/// 美化:
///   - 获取焦点时容器上浮(translateY) + 阴影增加
///   - 发送按钮有/无文字时颜色过渡
///   - 提交成功后短暂 ✓ 反馈
class QuickCreateInput extends StatefulWidget {
  const QuickCreateInput({
    required this.onSubmit,
    this.hint = '添加任务…',
    super.key,
  });

  final Future<void> Function(String title) onSubmit;
  final String hint;

  @override
  State<QuickCreateInput> createState() => _QuickCreateInputState();
}

class _QuickCreateInputState extends State<QuickCreateInput>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;
  bool _showSuccess = false;
  bool _hasFocus = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  void _onTextChange() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(raw);
      _controller.clear();
      // 短暂显示成功反馈
      setState(() => _showSuccess = true);
      await Future<void>.delayed(MotionDurations.bouncy);
      if (mounted) {
        setState(() => _showSuccess = false);
        _focusNode.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = scheme.brightness == Brightness.light;

    return AnimatedContainer(
      duration: MotionDurations.fast,
      curve: MotionCurves.emphasizedDecelerate,
      transform: Matrix4.translationValues(0, _hasFocus ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: _hasFocus
                ? scheme.primary.withValues(alpha: 0.3)
                : scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isLight ? 0.08 : 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: Spacing.sm),
                  child: AnimatedRotation(
                    turns: _hasFocus ? 0.125 : 0, // 45° 旋转
                    duration: MotionDurations.fast,
                    curve: MotionCurves.bouncySpring,
                    child: Icon(
                      Icons.add_circle_outline_rounded,
                      size: 22,
                      color: _hasFocus ? scheme.primary : scheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !_submitting,
                    onSubmitted: (_) => _submit(),
                    textInputAction: TextInputAction.done,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.outline,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: Spacing.md,
                      ),
                    ),
                  ),
                ),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.all(Spacing.sm),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  AnimatedSwitcher(
                    duration: MotionDurations.fast,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: child,
                    ),
                    child: _showSuccess
                        ? IconButton(
                            key: const ValueKey('success'),
                            icon: Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: Colors.green.shade400,
                            ),
                            onPressed: null,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green.shade400.withValues(alpha: 0.15),
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(Spacing.sm),
                              minimumSize: const Size(34, 34),
                            ),
                          )
                        : IconButton(
                            key: const ValueKey('send'),
                            icon: Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: _hasText ? scheme.onPrimaryContainer : scheme.outline,
                            ),
                            onPressed: _submit,
                            tooltip: '创建',
                            style: IconButton.styleFrom(
                              backgroundColor: _hasText
                                  ? scheme.primaryContainer
                                  : Colors.transparent,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(Spacing.sm),
                              minimumSize: const Size(34, 34),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
