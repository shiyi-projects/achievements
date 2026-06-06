import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';

/// 「智能输入」说明面板:列出快速创建框支持的自然语言规则与可点击示例。
///
/// 内容须与 `lib/core/capture/capture_parser.dart` 的解析规则保持一致——
/// 改解析器时同步改这里的示例,二者是同一份「用户契约」的两面。
void showCaptureHelp(
  BuildContext context, {
  required ValueChanged<String> onPick,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CaptureHelpSheet(onPick: onPick),
  );
}

/// 一类规则:图标 + 标题 + 若干「词」示例(只读)。
class _RuleGroup {
  const _RuleGroup(this.icon, this.title, this.tokens);
  final IconData icon;
  final String title;
  final List<String> tokens;
}

const _groups = [
  _RuleGroup(Icons.repeat_rounded, '重复', [
    '每天',
    '每周',
    '每月',
    '每年',
    '每周一三五',
    '工作日',
    '每2周',
    '每3天',
  ]),
  _RuleGroup(Icons.event_rounded, '日期', ['今天', '明天', '后天', '大后天']),
  _RuleGroup(Icons.schedule_rounded, '时间', [
    '9点',
    '9:30',
    '9点半',
    '上午10点',
    '下午3点',
    '晚上8点',
    '中午',
  ]),
];

/// 可点击的整句示例(点击后自动填入输入框)。
const _examples = [
  '每天9点 吃药',
  '每周一三五 上午10点 交周报',
  '工作日 18:00 写日报',
  '明天下午3点 开会',
  '每2周 周五 团队同步',
];

class _CaptureHelpSheet extends StatelessWidget {
  const _CaptureHelpSheet({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
                const SizedBox(width: Spacing.sm),
                Text('智能输入', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              '在创建框里随手打一句,自动识别时间和重复规则,无需逐项设置。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),

            // ── 规则分类 ──
            for (final g in _groups) ...[
              Row(
                children: [
                  Icon(g.icon, size: 16, color: scheme.primary),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    g.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: [
                  for (final t in g.tokens)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                      child: Text(t, style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.lg),
            ],

            // ── 可点击示例 ──
            Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: Spacing.sm),
                Text(
                  '点我试试(自动填入)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            for (final e in _examples)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Material(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(Radii.input),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      onPick(e);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.base,
                        vertical: Spacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(e, style: theme.textTheme.bodyMedium),
                          ),
                          Icon(
                            Icons.north_west_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
