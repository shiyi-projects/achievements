import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/search/providers/search_providers.dart';
import 'package:achievements/features/search/widgets/recent_searches.dart';
import 'package:achievements/features/search/widgets/search_bar_field.dart';
import 'package:achievements/features/search/widgets/search_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局搜索页(组装层)。
///
/// 布局:
/// ```
/// Column
///   SearchBarField          ← 固定顶部
///   Divider
///   Expanded
///     query 为空  → RecentSearches / 空态提示
///     query 非空  → searchResultsProvider.when(...)
/// ```
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 最近搜索芯片被点击时:同步文本框内容并聚焦。
  void _onRecentChipTapped(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _focusNode.requestFocus();
  }

  void _onSubmitted(String value) {
    addRecentSearch(ref, value);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchBarField(
          controller: _controller,
          focusNode: _focusNode,
          onSubmitted: _onSubmitted,
        ),
        const Divider(height: 1),
        Expanded(
          child: query.trim().isEmpty
              ? _EmptyQueryContent(onChipTapped: _onRecentChipTapped)
              : _SearchResults(query: query, scheme: scheme, theme: theme),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Private: content when query is empty
// ─────────────────────────────────────────────────────────────────────

class _EmptyQueryContent extends ConsumerWidget {
  const _EmptyQueryContent({required this.onChipTapped});

  final ValueChanged<String> onChipTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);

    if (recents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Text(
            '输入关键词开始搜索',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: RecentSearches(onChipTapped: onChipTapped),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Private: content when query is non-empty
// ─────────────────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.scheme,
    required this.theme,
  });

  final String query;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Text(
            '搜索出错:$error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.error,
            ),
          ),
        ),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Text(
                '没有找到匹配的任务',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: Spacing.base,
            endIndent: Spacing.base,
          ),
          itemBuilder: (context, index) =>
              SearchResultTile(task: tasks[index]),
        );
      },
    );
  }
}
