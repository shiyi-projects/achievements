import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局指令面板(Ctrl+K)。
///
/// 内容分三组:
/// 1. 导航 — 内置视图(今天 / 日历 / 专注 / 统计 / 成就)
/// 2. 清单 — 所有用户自定义清单
/// 3. 任务 — 输入关键词后在所有任务中模糊匹配
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

class _CommandPaletteContentState extends ConsumerState<_CommandPaletteContent> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  int _selectedIndex = 0;
  List<_PaletteEntry> _entries = [];

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

    _entries = _buildEntries(lists, _query);

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
                        child: Text(
                          '没有匹配结果',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
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
                                  ? scheme.primaryContainer.withValues(alpha: 0.5)
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
                                      style: theme.textTheme.bodyMedium?.copyWith(
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
                                      style: theme.textTheme.labelSmall?.copyWith(
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

  List<_PaletteEntry> _buildEntries(List<TaskList> lists, String query) {
    final q = query.trim().toLowerCase();

    final navEntries = <_PaletteEntry>[
      _PaletteEntry(
        icon: AppIcons.svgIcon(AppIcons.today, size: 18),
        label: '今天',
        category: '导航',
        action: (ctx, ref) {
          final lists = ref.read(allListsProvider).valueOrNull ?? [];
          final today = lists.where(
            (l) => l.systemKind == 'today',
          ).firstOrNull;
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
        icon: AppIcons.svgIcon(AppIcons.stats, size: 18),
        label: '统计',
        category: '导航',
        action: (_, ref) =>
            ref.read(currentViewNotifierProvider.notifier).showStatistics(),
      ),
      _PaletteEntry(
        icon: AppIcons.svgIcon(AppIcons.achievement, size: 18),
        label: '成就',
        category: '导航',
        action: (_, ref) =>
            ref.read(currentViewNotifierProvider.notifier).showAchievement(),
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

    final all = [...navEntries, ...listEntries];

    if (q.isEmpty) return all;
    return all
        .where((e) => e.label.toLowerCase().contains(q))
        .toList();
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
