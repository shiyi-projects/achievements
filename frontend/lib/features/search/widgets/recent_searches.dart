import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/search/providers/search_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 最近搜索区域。
///
/// 仅在 [searchQueryProvider] 为空且 [recentSearchesProvider] 非空时显示。
/// 点击芯片时设置 [searchQueryProvider] 并调用 [onChipTapped] 传递关键词
/// (供父级同步到输入框并聚焦)。
class RecentSearches extends ConsumerWidget {
  const RecentSearches({
    required this.onChipTapped,
    super.key,
  });

  /// 点击某个最近搜索词时的回调(参数为该词)。
  final ValueChanged<String> onChipTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final recents = ref.watch(recentSearchesProvider);

    if (query.isNotEmpty || recents.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '最近搜索',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(recentSearchesProvider.notifier).state = const [];
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '清除',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: recents
                .map(
                  (s) => ActionChip(
                    label: Text(s),
                    onPressed: () {
                      ref.read(searchQueryProvider.notifier).state = s;
                      onChipTapped(s);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
