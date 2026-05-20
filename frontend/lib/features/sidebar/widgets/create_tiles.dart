import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/features/settings/settings_page.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Create Tile — 合并「新建清单」与「新建文件夹」
// ─────────────────────────────────────────────────────────────────────

enum _CreateAction { list, folder }

class NewItemTile extends ConsumerWidget {
  const NewItemTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: PopupMenuButton<_CreateAction>(
        offset: const Offset(0, -88),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: _CreateAction.list,
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded, size: 18),
                SizedBox(width: Spacing.md),
                Text('新建清单'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: _CreateAction.folder,
            child: Row(
              children: [
                Icon(Icons.create_new_folder_rounded, size: 18),
                SizedBox(width: Spacing.md),
                Text('新建文件夹'),
              ],
            ),
          ),
        ],
        onSelected: (action) => _onCreate(context, ref, action),
        child: ListTile(
          dense: true,
          leading: AppIcons.svgIcon(AppIcons.add),
          title: Text(
            '新建',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onCreate(
    BuildContext context,
    WidgetRef ref,
    _CreateAction action,
  ) async {
    switch (action) {
      case _CreateAction.list:
        final name = await showNameInputDialog(
          context,
          title: '新建清单',
          confirm: '创建',
          icon: Icons.list_alt_rounded,
        );
        if (name == null) return;
        await ref.read(listRepositoryProvider).create(name: name);
      case _CreateAction.folder:
        final name = await showNameInputDialog(
          context,
          title: '新建文件夹',
          confirm: '创建',
          icon: Icons.create_new_folder_rounded,
        );
        if (name == null) return;
        await ref.read(folderRepositoryProvider).create(name: name);
    }
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
