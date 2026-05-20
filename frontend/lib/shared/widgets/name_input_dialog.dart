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
}) async {
  final controller = TextEditingController(text: initial);
  final scheme = Theme.of(context).colorScheme;

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(icon, color: scheme.primary, size: 28),
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.base,
            vertical: Spacing.md,
          ),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(confirm),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.isEmpty) return null;
  return result;
}
