import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:flutter/material.dart';

/// 只读 tag 行(TaskTile / 列表使用)。空列表时返回 [SizedBox.shrink]。
class TagsRow extends StatelessWidget {
  const TagsRow({required this.tags, super.key});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall;

    return Wrap(
      spacing: Spacing.xs + 2,
      runSpacing: Spacing.xs,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Text(
              '#${tag.name}',
              style: textStyle?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
      ],
    );
  }
}
