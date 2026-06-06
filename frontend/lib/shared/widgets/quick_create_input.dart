import 'package:achievements/core/capture/capture_parser.dart';
import 'package:achievements/core/recurrence/recurrence_rule_draft.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/features/task_detail/widgets/date_helpers.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/shared/widgets/capture_help_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 底部快速创建任务输入框。
///
/// 仅负责呈现 + 收集输入。创建副作用由调用方完成:
/// - 提供 [onSubmitCapture] 时,启用**自然语言捕获**——实时解析输入里的
///   日期 / 时间 / 重复词,在输入框上方显示可见的预览 chip,提交时回传
///   结构化 [CaptureResult]。
/// - 否则回退到 [onSubmit],只拿去空后的 title 字符串。
///
/// 空字符串会被吞掉,不触发回调。样式遵循 ui_design_spec §7.1。
class QuickCreateInput extends ConsumerStatefulWidget {
  const QuickCreateInput({
    required this.onSubmit,
    this.onSubmitCapture,
    this.hint = '添加任务…',
    super.key,
  });

  final Future<void> Function(String title) onSubmit;

  /// 提供时启用自然语言捕获,回传解析后的结构化结果。
  final Future<void> Function(CaptureResult result)? onSubmitCapture;
  final String hint;

  @override
  ConsumerState<QuickCreateInput> createState() => _QuickCreateInputState();
}

class _QuickCreateInputState extends ConsumerState<QuickCreateInput>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;
  bool _showSuccess = false;
  bool _hasFocus = false;
  bool _hasText = false;
  CaptureResult? _preview;

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
    final text = _controller.text.trim();
    final has = text.isNotEmpty;
    CaptureResult? preview;
    if (widget.onSubmitCapture != null && has) {
      final parsed = ref.read(captureParserProvider).parse(text);
      if (parsed.hasMeta) preview = parsed;
    }
    if (has != _hasText || preview != _preview) {
      setState(() {
        _hasText = has;
        _preview = preview;
      });
    }
  }

  /// 打开「智能输入」说明面板;点选示例后自动填入并聚焦,顺带触发预览。
  void _showHelp() {
    showCaptureHelp(
      context,
      onPick: (text) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
        // 设置 text 会触发 _onTextChange 监听 → 预览 chip 自动出现。
        _focusNode.requestFocus();
      },
    );
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final capture = widget.onSubmitCapture;
      if (capture != null) {
        await capture(ref.read(captureParserProvider).parse(raw));
      } else {
        await widget.onSubmit(raw);
      }
      _controller.clear();
      _preview = null;
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
                  color: scheme.primary.withValues(
                    alpha: isLight ? 0.08 : 0.15,
                  ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_preview != null) _CapturePreview(result: _preview!),
              Container(
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
                        child: AppIcons.svgIcon(AppIcons.add, size: 22),
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
                    // 智能模式下提供「?」说明入口(纯标题模式不显示)。
                    if (widget.onSubmitCapture != null && !_submitting)
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded, size: 20),
                        color: scheme.outline,
                        tooltip: '智能输入说明',
                        onPressed: _showHelp,
                        padding: const EdgeInsets.all(Spacing.sm),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
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
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: _showSuccess
                            ? IconButton(
                                key: const ValueKey('success'),
                                icon: AppIcons.svgIcon(
                                  AppIcons.completedStatus,
                                  size: 20,
                                ),
                                onPressed: null,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.green.shade400
                                      .withValues(alpha: 0.15),
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(Spacing.sm),
                                  minimumSize: const Size(34, 34),
                                ),
                              )
                            : IconButton(
                                key: const ValueKey('send'),
                                icon: AppIcons.svgIcon(AppIcons.send, size: 20),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 自然语言捕获的预览条:展示解析出的日期 / 提醒 / 重复,提交即应用。
class _CapturePreview extends StatelessWidget {
  const _CapturePreview({required this.result});

  final CaptureResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chips = <Widget>[];

    void chip(IconData icon, String label) {
      chips.add(
        Chip(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          avatar: Icon(icon, size: 14, color: scheme.primary),
          label: Text(label),
          labelStyle: theme.textTheme.labelSmall?.copyWith(
            color: scheme.primary,
          ),
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.4),
          side: BorderSide.none,
        ),
      );
    }

    if (result.repeatRuleBody != null) {
      final summary =
          RecurrenceRuleDraft.fromRuleBody(
            result.repeatRuleBody!,
          )?.describe() ??
          '重复';
      chip(Icons.repeat_rounded, summary);
    }
    if (result.remindAt != null) {
      chip(Icons.notifications_rounded, formatDateTimeCn(result.remindAt!));
    } else if (result.dueAt != null) {
      chip(Icons.event_rounded, formatDateCn(result.dueAt!));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Spacing.xs, left: Spacing.xs),
        child: Wrap(spacing: Spacing.xs, children: chips),
      ),
    );
  }
}
