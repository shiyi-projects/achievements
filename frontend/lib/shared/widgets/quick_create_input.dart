import 'package:flutter/material.dart';

/// 底部快速创建任务输入框。
///
/// 仅负责呈现 + 收集输入,创建任务的副作用由调用方在 [onSubmit] 里完成
/// (拿到去空后的 title 字符串)。空字符串会被吞掉,不触发回调。
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
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.add, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_submitting,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_outlined, size: 20),
              onPressed: _submitting ? null : _submit,
              tooltip: 'Create',
            ),
          ],
        ),
      ),
    );
  }
}
