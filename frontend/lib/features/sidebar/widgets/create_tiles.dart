import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/shared/widgets/name_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────
// Create Tiles
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
        leading: Icon(
          Icons.add_rounded,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          '新建清单',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: () async {
          final name = await showNameInputDialog(
            context,
            title: '新建清单',
            confirm: '创建',
          );
          if (name == null) return;
          await ref.read(listRepositoryProvider).create(name: name);
        },
      ),
    );
  }
}

class NewFolderTile extends ConsumerWidget {
  const NewFolderTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.create_new_folder_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          '新建文件夹',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        onTap: () async {
          final name = await showNameInputDialog(
            context,
            title: '新建文件夹',
            confirm: '创建',
          );
          if (name == null) return;
          await ref.read(folderRepositoryProvider).create(name: name);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Settings Tile (placeholder)
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
        leading: Icon(
          Icons.settings_rounded,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          '设置',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: () {
          // Phase 4: navigate to settings
        },
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
