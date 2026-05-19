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
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '#${tag.name}',
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
