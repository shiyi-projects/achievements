import 'package:achievements/core/constants.dart';
import 'package:achievements/core/sync/sync_engine.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/calendar/calendar_page.dart';
import 'package:achievements/features/list_view/list_page.dart';
import 'package:achievements/features/sidebar/sidebar.dart';
import 'package:achievements/features/task_detail/task_detail_panel.dart';
import 'package:achievements/features/today/today_page.dart';
import 'package:achievements/state/current_view.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:achievements/state/selected_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 响应式应用外壳。
///
/// 三档断点(ui_design_spec §6.1):
/// - Compact(< 600):Sidebar 进 Drawer;任务详情走 modal bottom sheet
/// - Medium(600–839):Sidebar 常驻;任务详情走 modal bottom sheet
/// - Expanded(≥ 840):Sidebar + 主视图 + 任务详情面板 三列并存
///
/// 主视图根据 [currentListProvider] 在 [TodayPage] / [ListPage] 间切换。
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

    final view = ref.watch(currentViewNotifierProvider);

    final title = view == AppView.calendar
        ? '日历'
        : currentAsync.maybeWhen(
            data: (list) => list?.name ?? 'Achievements',
            orElse: () => 'Achievements',
          );

    final mainBody = view == AppView.calendar
        ? const CalendarPage()
        : currentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Text('Failed to load: $e'),
              ),
            ),
            data: (list) {
              final kind = SystemListKind.fromValue(list?.systemKind);
              if (kind == SystemListKind.today) return const TodayPage();
              return const ListPage();
            },
          );

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (showSidebarInline) {
      return Scaffold(
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
                  Expanded(child: mainBody),
                ],
              ),
            ),
            if (dockDetail && selectedTaskId != null) ...[
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(width: _kDetailWidth, child: TaskDetailPanel()),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [_SyncStatusIcon(), SizedBox(width: 8)],
      ),
      drawer: const Drawer(
        child: SizedBox(width: _kSidebarWidth, child: Sidebar()),
      ),
      body: mainBody,
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
    // sheet 关闭后清空选中
    ref.read(selectedTaskIdProvider.notifier).clear();
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
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const _SyncStatusIcon(),
          // ── Search button (placeholder) ──
          IconButton(
            icon: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
            tooltip: 'Search',
            onPressed: () {
              // Phase 3: open search
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

/// 同步状态小图标。idle 时隐藏;syncing 时显示旋转圈;
/// offline / error 时显示对应图标 + tooltip。
class _SyncStatusIcon extends ConsumerWidget {
  const _SyncStatusIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return switch (status) {
      SyncStatus.idle => const SizedBox.shrink(),
      SyncStatus.syncing => Tooltip(
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
        message: '已离线',
        child: Icon(
          Icons.cloud_off_outlined,
          size: 20,
          color: scheme.outline,
        ),
      ),
      SyncStatus.error => Tooltip(
        message: '同步失败,30 秒后重试',
        child: Icon(
          Icons.sync_problem_outlined,
          size: 20,
          color: scheme.error,
        ),
      ),
    };
  }
}
