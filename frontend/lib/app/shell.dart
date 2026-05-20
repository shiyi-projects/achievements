import 'package:achievements/core/constants.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/features/achievement/achievement_page.dart';
import 'package:achievements/features/calendar/calendar_page.dart';
import 'package:achievements/features/focus/focus_page.dart';
import 'package:achievements/features/list_view/list_page.dart';
import 'package:achievements/features/search/providers/search_providers.dart';
import 'package:achievements/features/sidebar/sidebar.dart';
import 'package:achievements/features/statistics/statistics_page.dart';
import 'package:achievements/features/task_detail/task_detail_panel.dart';
import 'package:achievements/features/today/today_page.dart';
import 'package:achievements/platform/windows/command_palette.dart';
import 'package:achievements/shared/animations/motion_tokens.dart';
import 'package:achievements/shared/animations/page_transitions.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 响应式应用外壳。
///
/// 三档断点(ui_design_spec §6.1):
/// - Compact(<600):Sidebar 进 Drawer;任务详情走 modal bottom sheet
/// - Medium(600–839):Sidebar 常驻;任务详情走 modal bottom sheet
/// - Expanded(≥ 840):Sidebar + 主视图 + 任务详情面板 三列并存
///
/// 主视图根据 [currentListProvider] 在 [TodayPage] / [ListPage] 间切换。

/// 自定义 [AnimatedSwitcher.layoutBuilder]。
///
/// 默认的 layoutBuilder 使用 `Stack` 包裹子组件，导致过渡期间旧组件
/// 获得无界约束（Column 中的 Expanded 失效 → 溢出 99000+ px）。
/// 这里用 `SizedBox.expand` 包裹 Stack，使所有子组件继承父级有界尺寸。
Widget _fillLayoutBuilder(Widget? currentChild, List<Widget> previousChildren) {
  return SizedBox.expand(
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        ...previousChildren,
        if (currentChild != null) currentChild,
      ],
    ),
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const double _kCompactBreakpoint = 600;
  static const double _kExpandedBreakpoint = 840;
  static const double _kSidebarWidth = 260;
  static const double _kDetailWidth = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final showSidebarInline = width >= _kCompactBreakpoint;
    final dockDetail = width >= _kExpandedBreakpoint;

    final currentAsync = ref.watch(currentListProvider);
    final selectedTaskId = ref.watch(selectedTaskIdProvider);

    // 非桌面:监听选中任务变化,触发 bottom sheet
    if (!dockDetail) {
      ref.listen<String?>(selectedTaskIdProvider, (prev, next) {
        if (next != null && prev != next) {
          _openTaskSheet(context, ref);
        }
      });
    }

    // 切换视图时关闭搜索
    ref.listen<AppView>(currentViewNotifierProvider, (_, __) {
      closeSearch(ref);
    });

    final view = ref.watch(currentViewNotifierProvider);

    final title = switch (view) {
      AppView.calendar => '日历',
      AppView.focus => '专注',
      AppView.statistics => '统计',
      AppView.achievement => '成就',
      AppView.list => currentAsync.maybeWhen(
        data: (list) => list?.name ?? 'Achievements',
        orElse: () => 'Achievements',
      ),
    };

    final mainBody = switch (view) {
      AppView.calendar => const CalendarPage(),
      AppView.focus => const FocusPage(),
      AppView.statistics => const StatisticsPage(),
      AppView.achievement => const AchievementPage(),
      AppView.list => currentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Text('加载失败: $e'),
          ),
        ),
        data: (list) {
          final kind = SystemListKind.fromValue(list?.systemKind);
          if (kind == SystemListKind.today) return const TodayPage();
          return const ListPage();
        },
      ),
    };

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (showSidebarInline) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              () => showCommandPalette(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: _kSidebarWidth, child: Sidebar()),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _ModernAppBar(title: title),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MotionDurations.normal,
                          switchInCurve: MotionCurves.emphasizedDecelerate,
                          switchOutCurve: MotionCurves.emphasizedAccelerate,
                          transitionBuilder: sharedAxisTransition,
                          layoutBuilder: _fillLayoutBuilder,
                          child: KeyedSubtree(
                            key: ValueKey(view),
                            child: mainBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── 详情面板：带动画的滑入/滑出 ──
                AnimatedSize(
                  duration: MotionDurations.normal,
                  curve: MotionCurves.emphasizedDecelerate,
                  alignment: Alignment.centerLeft,
                  child: dockDetail && selectedTaskId != null
                      ? SizedBox(
                          width: _kDetailWidth,
                          child: Row(
                            children: [
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: scheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                              const Expanded(child: TaskDetailPanel()),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentList = currentAsync.maybeWhen(
      data: (l) => l,
      orElse: () => null,
    );
    final canCreate =
        view == AppView.list &&
        currentList != null &&
        (!currentList.isSystem ||
            SystemListKind.fromValue(currentList.systemKind) ==
                SystemListKind.inbox);

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: MotionDurations.fast,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(title, key: ValueKey(title)),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [_SyncStatusIcon(), SizedBox(width: 8)],
      ),
      drawer: const Drawer(
        child: SizedBox(width: _kSidebarWidth, child: Sidebar()),
      ),
      body: AnimatedSwitcher(
        duration: MotionDurations.normal,
        switchInCurve: MotionCurves.emphasizedDecelerate,
        switchOutCurve: MotionCurves.emphasizedAccelerate,
        transitionBuilder: sharedAxisTransition,
        layoutBuilder: _fillLayoutBuilder,
        child: KeyedSubtree(key: ValueKey(view), child: mainBody),
      ),
      bottomNavigationBar: _MobileBottomNav(current: view),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => _openQuickCreate(context, ref, currentList),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Future<void> _openTaskSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: TaskDetailPanel(),
      ),
    );
    ref.read(selectedTaskIdProvider.notifier).clear();
  }

  Future<void> _openQuickCreate(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
  ) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          left: Spacing.base,
          right: Spacing.base,
          top: Spacing.base,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: '新建任务…',
                  border: InputBorder.none,
                  filled: false,
                ),
                onSubmitted: (title) {
                  if (title.trim().isEmpty) return;
                  ref.read(taskRepositoryProvider).createTask(
                    listId: list.id,
                    title: title.trim(),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () {
                final title = controller.text.trim();
                if (title.isEmpty) return;
                ref.read(taskRepositoryProvider).createTask(
                  listId: list.id,
                  title: title,
                );
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Modern AppBar (inline mode)
// ─────────────────────────────────────────────────────────────────────

class _ModernAppBar extends ConsumerWidget {
  const _ModernAppBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSearching = ref.watch(searchActiveProvider);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: MotionDurations.fast,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                title,
                key: ValueKey(title),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const _SyncStatusIcon(),
          IconButton(
            icon: AnimatedSwitcher(
              duration: MotionDurations.fast,
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween(begin: 0.5, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.search_rounded,
                key: ValueKey(isSearching),
                color: isSearching ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            tooltip: isSearching ? '关闭搜索' : '搜索',
            onPressed: () {
              if (isSearching) {
                closeSearch(ref);
              } else {
                ref.read(searchActiveProvider.notifier).state = true;
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sync status indicator
// ─────────────────────────────────────────────────────────────────────

class _SyncStatusIcon extends ConsumerWidget {
  const _SyncStatusIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSwitcher(
      duration: MotionDurations.fast,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: switch (status) {
        SyncStatus.idle => const SizedBox.shrink(key: ValueKey('idle')),
        SyncStatus.syncing => Tooltip(
          key: const ValueKey('syncing'),
          message: '正在同步…',
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: scheme.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
        SyncStatus.offline => Tooltip(
          key: const ValueKey('offline'),
          message: '已离线',
          child: Icon(Icons.cloud_off_outlined, size: 20, color: scheme.outline),
        ),
        SyncStatus.error => Tooltip(
          key: const ValueKey('error'),
          message: '同步失败,30 秒后重试',
          child: Icon(
            Icons.sync_problem_outlined,
            size: 20,
            color: scheme.error,
          ),
        ),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Mobile bottom navigation bar
// ─────────────────────────────────────────────────────────────────────

class _MobileBottomNav extends ConsumerWidget {
  const _MobileBottomNav({required this.current});

  final AppView current;

  static const _items = [
    (icon: Icons.format_list_bulleted_rounded, label: '清单', view: AppView.list),
    (icon: Icons.calendar_month_rounded, label: '日历', view: AppView.calendar),
    (icon: Icons.timer_outlined, label: '专注', view: AppView.focus),
    (icon: Icons.bar_chart_rounded, label: '统计', view: AppView.statistics),
    (icon: Icons.emoji_events_rounded, label: '成就', view: AppView.achievement),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(currentViewNotifierProvider.notifier);
    final selectedIndex =
        _items.indexWhere((e) => e.view == current).clamp(0, _items.length - 1);

    return NavigationBar(
      selectedIndex: selectedIndex,
      animationDuration: MotionDurations.normal,
      onDestinationSelected: (i) {
        final item = _items[i];
        switch (item.view) {
          case AppView.list:
            notifier.showList();
          case AppView.calendar:
            notifier.showCalendar();
          case AppView.focus:
            notifier.showFocus();
          case AppView.statistics:
            notifier.showStatistics();
          case AppView.achievement:
            notifier.showAchievement();
        }
      },
      destinations: [
        for (final item in _items)
          NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
          ),
      ],
    );
  }
}
