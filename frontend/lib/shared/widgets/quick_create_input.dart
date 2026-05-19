import 'package:achievements/core/theme/app_dimensions.dart';
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
class QuickCreateInput extends StatefulWidget {
  const QuickCreateInput({
    required this.onSubmit,
    this.hint = 'Add a task',
    super.key,
  });

  final Future<void> Function(String title) onSubmit;
  final String hint;

  @override
  State<QuickCreateInput> createState() => _QuickCreateInputState();
}

class _QuickCreateInputState extends State<QuickCreateInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(raw);
      _controller.clear();
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
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
                  child: Icon(
                    Icons.add_circle_outline_rounded,
                    size: 22,
                    color: scheme.primary,
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
                  IconButton(
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    onPressed: _submit,
                    tooltip: 'Create',
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(Spacing.sm),
                      minimumSize: const Size(34, 34),
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
