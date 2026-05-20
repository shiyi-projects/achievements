import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/search/providers/search_providers.dart';
import 'package:achievements/shared/widgets/empty_state.dart';
import 'package:achievements/shared/widgets/pending_completed_list.dart';
import 'package:achievements/shared/widgets/quick_create_input.dart';
import 'package:achievements/shared/widgets/task_tile.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通用清单视图(System.{inbox/important/planned/all/completed/trash} 与
/// 用户自定义清单共用)。
///
/// 顶部嵌入 inline 搜索栏:当 [searchActiveProvider] 为 true 时,
/// 搜索栏展开,结果替换任务列表;关闭时恢复正常列表。
class ListPage extends ConsumerStatefulWidget {
  const ListPage({super.key});

  @override
  ConsumerState<ListPage> createState() => _ListPageState();
}

class _ListPageState extends ConsumerState<ListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksForCurrentListProvider);
    final currentAsync = ref.watch(currentListProvider);
    final current = currentAsync.maybeWhen(
      data: (list) => list,
      orElse: () => null,
    );
    final isSearching = ref.watch(searchActiveProvider);
    final searchResults = ref.watch(searchResultsProvider);

    final canQuickCreate =
        !isSearching &&
        current != null &&
        (!current.isSystem ||
            SystemListKind.fromValue(current.systemKind) ==
                SystemListKind.inbox);

    // 搜索栏展开/关闭时同步 controller
    ref.listen<bool>(searchActiveProvider, (_, active) {
      if (!active) {
        _searchController.clear();
      } else {
        // 展开后自动聚焦由 autofocus 处理
      }
    });

    return Column(
      children: [
        // ── Inline search bar ──
        if (isSearching) _SearchBar(controller: _searchController),

        // ── Main content ──
        Expanded(
          child: isSearching
              ? _SearchResults(resultsAsync: searchResults)
              : tasksAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Text('Failed to load: $e'),
                    ),
                  ),
                  data: (tasks) => PendingCompletedList(
                    tasks: tasks,
                    emptyState: const EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'No tasks here yet',
                      subtitle:
                          'Create from the input below or move tasks from other lists.',
                    ),
                  ),
                ),
        ),

        if (canQuickCreate)
          QuickCreateInput(
            hint: 'Add a task to ${current.name}',
            onSubmit: (title) => ref
                .read(taskRepositoryProvider)
                .createTask(listId: current.id, title: title),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Inline search bar
// ─────────────────────────────────────────────────────────────────────

class _SearchBar extends ConsumerWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.base, Spacing.sm, Spacing.base, Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: '搜索所有任务…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  )
                : const SizedBox.shrink(),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.input),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          isDense: true,
        ),
        onChanged: (value) =>
            ref.read(searchQueryProvider.notifier).state = value,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Search results
// ─────────────────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.resultsAsync});
  final AsyncValue<List<Task>> resultsAsync;

  @override
  Widget build(BuildContext context) {
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('搜索出错: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off_rounded,
            title: '没有匹配的任务',
            subtitle: '试试其他关键词',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: Spacing.base,
            endIndent: Spacing.base,
          ),
          itemBuilder: (_, i) => TaskTile(task: tasks[i]),
        );
      },
    );
  }
}
