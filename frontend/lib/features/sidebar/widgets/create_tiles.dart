import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/features/settings/settings_page.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// New List Tile — 在顶层新建清单
//
// 「文件夹」已并入清单树:要建一个分组,就建一个清单再往里放子清单,不再
// 需要在两种实体之间先做选择。子清单从清单行的菜单里建。
// ─────────────────────────────────────────────────────────────────────

class NewListTile extends ConsumerWidget {
  const NewListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: ListTile(
        dense: true,
        leading: AppIcons.svgIcon(AppIcons.add),
        title: Text(
          '新建清单',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: () => _onCreate(context, ref),
      ),
    );
  }

  Future<void> _onCreate(BuildContext context, WidgetRef ref) async {
    final name = await showNameInputDialog(
      context,
      title: '新建清单',
      confirm: '创建',
      icon: Icons.list_alt_rounded,
    );
    if (name == null) return;
    await ref.read(listRepositoryProvider).create(name: name);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Settings Tile
// ─────────────────────────────────────────────────────────────────────

class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.sm,
      ),
      child: ListTile(
        dense: true,
        leading: AppIcons.svgIcon(AppIcons.settings),
        title: Text(
          '设置',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () => showSettingsDialog(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────────────────────────────

class SidebarError extends StatelessWidget {
  const SidebarError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.base),
      child: Text(
        '侧边栏加载失败:$message',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
