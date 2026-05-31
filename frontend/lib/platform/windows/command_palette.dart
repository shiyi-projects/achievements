import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/features/search/providers/search_providers.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局指令面板(Ctrl+K),同时承担全局搜索职责。
///
/// 内容分三组:
/// 1. 导航 — 内置视图(今天 / 日历 / 专注 / 成就)
/// 2. 清单 — 所有用户自定义清单
/// 3. 任务 — 输入关键词后在所有任务中按标题/备注模糊匹配
///
/// 关闭时清空全局 [searchQueryProvider],避免下次打开时残留旧 query。
void showCommandPalette(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _CommandPaletteDialog(),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Dialog wrapper
// ─────────────────────────────────────────────────────────────────────

class _CommandPaletteDialog extends StatelessWidget {
  const _CommandPaletteDialog();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.3),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 480),
          child: const _CommandPaletteContent(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Content (stateful for query + selection)
// ─────────────────────────────────────────────────────────────────────

class _CommandPaletteContent extends ConsumerStatefulWidget {
  const _CommandPaletteContent();

  @override
  ConsumerState<_CommandPaletteContent> createState() =>
      _CommandPaletteContentState();
}

class _CommandPaletteContentState
    extends ConsumerState<_CommandPaletteContent> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  int _selectedIndex = 0;
  List<_PaletteEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    // 打开面板时清空全局 query,避免上次的搜索结果在用户键入前闪现。
    Future.microtask(() {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = '';
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    setState(() {
      _query = q;
      _selectedIndex = 0;
    });
    // 驱动 searchResultsProvider 异步加载任务结果。
    ref.read(searchQueryProvider.notifier).state = q;
  }

  void _activate(_PaletteEntry entry) {
    Navigator.of(context).pop();
    entry.action(context, ref);
  }

  void _moveSelection(int delta) {
    if (_entries.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _entries.length - 1);
    });
    _scrollToSelected();
  }

  void _scrollToSelected() {
    const itemHeight = 48.0;
    final offset = _selectedIndex * itemHeight;
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allLists = ref.watch(allListsProvider);
    final lists = allLists.valueOrNull ?? const [];
    final tasksAsync = ref.watch(searchResultsProvider);
    final tasks = tasksAsync.valueOrNull ?? const <Task>[];
    final tasksLoading = tasksAsync.isLoading && _query.trim().isNotEmpty;

    _entries = _buildEntries(lists, _query, tasks);
    if (_selectedIndex >= _entries.length) {
      _selectedIndex = _entries.isEmpty ? 0 : _entries.length - 1;
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.arrowDown:
            _moveSelection(1);
          case LogicalKeyboardKey.arrowUp:
            _moveSelection(-1);
          case LogicalKeyboardKey.enter:
            if (_entries.isNotEmpty) _activate(_entries[_selectedIndex]);
          case LogicalKeyboardKey.escape:
            Navigator.of(context).pop();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.sheet),
        child: ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Query input ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.base,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    AppIcons.svgIcon(AppIcons.search),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: '输入命令或搜索…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: theme.textTheme.bodyLarge,
                        onChanged: _onQueryChanged,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Esc',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Results ──
              Flexible(
                child: _entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(Spacing.xl),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (tasksLoading) ...[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: scheme.primary.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                            ],
                            Text(
                              tasksLoading ? '搜索中…' : '没有匹配结果',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.xs,
                        ),
                        itemCount: _entries.length,
                        itemExtent: 48,
                        itemBuilder: (_, i) {
                          final entry = _entries[i];
                          final isSelected = i == _selectedIndex;
                          return InkWell(
                            onTap: () => _activate(entry),
                            onHover: (hovering) {
                              if (hovering) {
                                setState(() => _selectedIndex = i);
                              }
                            },
                            child: Container(
                              color: isSelected
                                  ? scheme.primaryContainer.withValues(
                                      alpha: 0.5,
                                    )
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.base,
                              ),
                              child: Row(
                                children: [
                                  entry.icon,
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Text(
                                      entry.label,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: isSelected
                                                ? scheme.primary
                                                : scheme.onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (entry.category.isNotEmpty)
                                    Text(
                                      entry.category,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ── Keyboard hint footer ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.base,
                  vertical: Spacing.xs,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: const Row(
                  children: [
                    _KeyHint('↑↓', '选择'),
                    SizedBox(width: Spacing.base),
                    _KeyHint('↵', '确认'),
                    SizedBox(width: Spacing.base),
                    _KeyHint('Esc', '关闭'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_PaletteEntry> _buildEntries(
    List<TaskList> lists,
    String query,
    List<Task> tasks,
  ) {
    final q = query.trim().toLowerCase();

    final navEntries = <_PaletteEntry>[
      _PaletteEntry(
        icon: AppIcons.svgIcon(AppIcons.today, size: 18),
        label: '今天',
        category: '导航',
        action: (ctx, ref) {
          final lists = ref.read(allListsProvider).valueOrNull ?? [];
          final today = lists.where((l) => l.systemKind == 'today').firstOrNull;
          if (today != null) {
            ref.read(selectedListIdProvider.notifier).select(today.id);
            ref.read(currentViewNotifierProvider.notifier).showList();
          }
        },
      ),
      _PaletteEntry(
        icon: AppIcons.svgIcon(AppIcons.calendar, size: 18),
        label: '日历',
        category: '导航',
        action: (_, ref) =>
            ref.read(currentViewNotifierProvider.notifier).showCalendar(),
      ),
      _PaletteEntry(
        icon: AppIcons.svgIcon(AppIcons.focusTimer, size: 18),
        label: '专注',
        category: '导航',
        action: (_, ref) =>
            ref.read(currentViewNotifierProvider.notifier).showFocus(),
      ),
      _PaletteEntry(
        icon: AppIcons.svgIcon(AppIcons.achievement, size: 18),
        label: '成就',
        category: '导航',
        action: (_, ref) =>
            ref.read(currentViewNotifierProvider.notifier).showInsights(),
      ),
    ];

    final listEntries = lists
        .where((l) => !l.isSystem)
        .map(
          (l) => _PaletteEntry(
            icon: AppIcons.svgIcon(AppIcons.list, size: 18),
            label: l.name,
            category: '清单',
            action: (_, ref) {
              ref.read(selectedListIdProvider.notifier).select(l.id);
              ref.read(currentViewNotifierProvider.notifier).showList();
            },
          ),
        )
        .toList();

    final navAndLists = [...navEntries, ...listEntries];
    final navAndListsFiltered = q.isEmpty
        ? navAndLists
        : navAndLists.where((e) => e.label.toLowerCase().contains(q)).toList();

    if (q.isEmpty) return navAndListsFiltered;

    // 任务搜索结果(已由 searchResultsProvider 异步加载,q 为空时为空列表)
    final listById = {for (final l in lists) l.id: l};
    final taskEntries = tasks.map((t) {
      final parent = listById[t.listId];
      final done = t.completedAt != null;
      final category = parent == null
          ? '任务'
          : displayNameOfList(
              systemKind: parent.systemKind,
              fallback: parent.name,
            );
      return _PaletteEntry(
        icon: AppIcons.svgIcon(
          done ? AppIcons.completedStatus : AppIcons.incomplete,
          size: 18,
        ),
        label: t.title,
        category: category,
        action: (_, ref) {
          ref.read(selectedListIdProvider.notifier).select(t.listId);
          ref.read(currentViewNotifierProvider.notifier).showList();
          ref.read(selectedTaskIdProvider.notifier).select(t.id);
        },
      );
    }).toList();

    return [...navAndListsFiltered, ...taskEntries];
  }
}

// ─────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────

class _PaletteEntry {
  const _PaletteEntry({
    required this.icon,
    required this.label,
    required this.category,
    required this.action,
  });

  final Widget icon;
  final String label;
  final String category;
  final void Function(BuildContext context, WidgetRef ref) action;
}

// ─────────────────────────────────────────────────────────────────────
// Key hint chip
// ─────────────────────────────────────────────────────────────────────

class _KeyHint extends StatelessWidget {
  const _KeyHint(this.key_, this.label);

  final String key_;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            key_,
            style: theme.textTheme.labelSmall?.copyWith(
              fontFamily: 'monospace',
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
