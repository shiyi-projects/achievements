import 'dart:async';

import 'package:achievements/core/constants.dart';
import 'package:achievements/core/notifications/reminder_checker.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/core/update/update_checker.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/features/insights/insights_page.dart';
import 'package:achievements/features/calendar/calendar_page.dart';
import 'package:achievements/features/focus/focus_page.dart';
import 'package:achievements/features/list_view/list_page.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/settings_page.dart';
import 'package:achievements/features/sidebar/sidebar.dart';

import 'package:achievements/features/task_detail/task_detail_panel.dart';
import 'package:achievements/features/today/today_page.dart';
import 'package:achievements/platform/windows/command_palette.dart';
import 'package:achievements/platform/windows/shell_commands.dart';
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
      children: [...previousChildren, if (currentChild != null) currentChild],
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

    // 启动自动检查更新:有新版本时弹一次轻量提示,引导去「设置 → 检查更新」。
    ref.listen(updateCheckProvider, (_, next) {
      final info = next.valueOrNull;
      if (info == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发现新版本 v${info.version},可在「设置 → 检查更新」获取'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    });

    // Windows 端托盘/窗口监听器把 UI 意图丢到 shellCommandProvider,这里统一兑现。
    ref.listen<ShellCommand?>(shellCommandProvider, (_, cmd) {
      if (cmd == null) return;
      _handleShellCommand(context, ref, cmd);
      ref.read(shellCommandProvider.notifier).state = null;
    });

    final view = ref.watch(currentViewNotifierProvider);

    final title = switch (view) {
      AppView.calendar => '日历',
      AppView.focus => '专注',
      AppView.insights => '成就',
      AppView.list => currentAsync.maybeWhen(
        data: (list) => list == null
            ? 'Achievements'
            : displayNameOfList(
                systemKind: list.systemKind,
                fallback: list.name,
              ),
        orElse: () => 'Achievements',
      ),
    };

    final mainBody = switch (view) {
      AppView.calendar => const CalendarPage(),
      AppView.focus => const FocusPage(),
      AppView.insights => const InsightsPage(),
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
      return ReminderChecker(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                showCommandPalette(context),
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
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.3,
                                  ),
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
        ),
      );
    }

    final mobileScaffold = Scaffold(
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
        actions: [
          IconButton(
            icon: AppIcons.svgIcon(AppIcons.search),
            tooltip: '搜索',
            onPressed: () => showCommandPalette(context),
          ),
          const _SyncStatusIcon(),
          const SizedBox(width: 8),
        ],
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
      floatingActionButton: null,
    );

    return ReminderChecker(child: mobileScaffold);
  }

  Future<void> _openTaskSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        // 把 sheet 的 scrollController 接进面板内部列表,拖拽与内容滚动统一,
        // 不再各管各地打架。
        builder: (context, scrollController) =>
            TaskDetailPanel(scrollController: scrollController),
      ),
    );
    ref.read(selectedTaskIdProvider.notifier).clear();
  }

  void _handleShellCommand(
    BuildContext context,
    WidgetRef ref,
    ShellCommand cmd,
  ) {
    switch (cmd) {
      case ShowTodayCommand():
        final lists = ref.read(allListsProvider).valueOrNull ?? const [];
        final today = lists
            .where((l) => l.systemKind == SystemListKind.today.value)
            .firstOrNull;
        if (today != null) {
          ref.read(selectedListIdProvider.notifier).select(today.id);
        }
        ref.read(currentViewNotifierProvider.notifier).showList();
      case ShowFocusCommand():
        ref.read(currentViewNotifierProvider.notifier).showFocus();
      case OpenSettingsCommand():
        showSettingsDialog(context);
      case AskCloseCommand(completer: final completer):
        _showAskCloseDialog(context, ref, completer);
    }
  }

  Future<void> _showAskCloseDialog(
    BuildContext context,
    WidgetRef ref,
    Completer<CloseAction> completer,
  ) async {
    final picked = await showDialog<CloseAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭 Achievements'),
        content: const Text('要最小化到托盘继续在后台运行,还是真正退出?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(CloseAction.exitApp),
            child: const Text('退出'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(CloseAction.minimizeToTray),
            child: const Text('最小化到托盘'),
          ),
        ],
      ),
    );
    // 取消(picked == null) → 视为最小化(等价于不退出,保留窗口可见性最稳)
    completer.complete(picked ?? CloseAction.minimizeToTray);
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
            icon: AppIcons.svgIcon(AppIcons.search),
            tooltip: '搜索 (Ctrl+K)',
            onPressed: () => showCommandPalette(context),
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
          child: AppIcons.svgIcon(AppIcons.cloudOff, size: 20),
        ),
        SyncStatus.error => Tooltip(
          key: const ValueKey('error'),
          message: '同步失败,30 秒后重试',
          child: AppIcons.svgIcon(AppIcons.cloudError, size: 20),
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

  static final _items = [
    (svgPath: AppIcons.list, label: '清单', view: AppView.list),
    (svgPath: AppIcons.calendar, label: '日历', view: AppView.calendar),
    (svgPath: AppIcons.focusTimer, label: '专注', view: AppView.focus),
    (svgPath: AppIcons.achievement, label: '成就', view: AppView.insights),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(currentViewNotifierProvider.notifier);
    final selectedIndex = _items
        .indexWhere((e) => e.view == current)
        .clamp(0, _items.length - 1);

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
          case AppView.insights:
            notifier.showInsights();
        }
      },
      destinations: [
        for (final item in _items)
          NavigationDestination(
            icon: AppIcons.svgIcon(item.svgPath, size: 24),
            label: item.label,
          ),
      ],
    );
  }
}
