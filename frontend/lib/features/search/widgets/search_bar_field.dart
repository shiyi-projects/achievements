import 'dart:async';

import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/search/providers/search_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 搜索输入框。
///
/// - 自动聚焦
/// - 输入防抖 300ms 后更新 [searchQueryProvider]
/// - 非空时显示清除按钮
/// - 提交(回车/完成)时调用 [onSubmitted] 回调(供父级写入最近搜索)
///
/// [controller] 和 [focusNode] 由父级提供,以便父级在外部(如最近搜索芯片)
/// 填充搜索词并重新聚焦。
class SearchBarField extends ConsumerStatefulWidget {
  const SearchBarField({
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  ConsumerState<SearchBarField> createState() => _SearchBarFieldState();
}

class _SearchBarFieldState extends ConsumerState<SearchBarField> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    // 刷新清除按钮可见性
    setState(() {});
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = value;
    widget.onSubmitted?.call(value);
  }

  void _clear() {
    widget.controller.clear();
    _debounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = '';
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = widget.controller.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.sm,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: _onChanged,
        onSubmitted: _onSubmitted,
        decoration: InputDecoration(
          hintText: '搜索任务…',
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '清除',
                  onPressed: _clear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.input),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.input),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.input),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
        ),
      ),
    );
  }
}
