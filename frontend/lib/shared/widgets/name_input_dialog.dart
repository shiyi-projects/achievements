import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 通用 "名称输入" 对话框。
///
/// 返回 trim 后的字符串(空字符串视为取消,自动返回 null)。
/// 用于新建/重命名 文件夹、清单、标签。
Future<String?> showNameInputDialog(
  BuildContext context, {
  required String title,
  String? initial,
  String hint = '名称',
  String confirm = '保存',
  IconData icon = Icons.edit_rounded,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _NameInputDialog(
      title: title,
      initial: initial,
      hint: hint,
      confirm: confirm,
      icon: icon,
    ),
  ).then((result) {
    if (result == null || result.isEmpty) return null;
    return result;
  });
}

class _NameInputDialog extends StatefulWidget {
  const _NameInputDialog({
    required this.title,
    required this.confirm,
    required this.icon,
    this.initial,
    this.hint = '名称',
  });

  final String title;
  final String? initial;
  final String hint;
  final String confirm;
  final IconData icon;

  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(widget.icon, color: scheme.primary, size: 28),
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.base,
            vertical: Spacing.md,
          ),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
