import 'package:achievements/core/constants.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:achievements/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 显示设置页弹窗(桌面用 dialog,移动用 bottom sheet)。
void showSettingsDialog(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 600) {
    showDialog<void>(context: context, builder: (_) => const _SettingsDialog());
  } else {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          const FractionallySizedBox(heightFactor: 0.9, child: SettingsPage()),
    );
  }
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sheet),
          child: const SettingsPage(showCloseButton: true),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main Settings Page
// ─────────────────────────────────────────────────────────────────────

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showCloseButton = false});

  final bool showCloseButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('设置'),
        automaticallyImplyLeading: false,
        actions: [
          if (showCloseButton)
            IconButton(
              icon: AppIcons.svgIcon(AppIcons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          children: [
            const _SectionHeader('外观'),
            _ThemeModeSection(current: settings.themeMode),
            const SizedBox(height: Spacing.sm),
            _ColorSection(current: settings.seedColor),
            const Divider(height: Spacing.xl),
            const _SectionHeader('同步'),
            const _SyncSection(),
            const Divider(height: Spacing.xl),
            const _SectionHeader('关于'),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.base,
        Spacing.lg,
        Spacing.xs,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Theme mode
// ─────────────────────────────────────────────────────────────────────

class _ThemeModeSection extends ConsumerWidget {
  const _ThemeModeSection({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text('主题模式', style: theme.textTheme.titleSmall),
          ),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('跟随系统'),
                icon: Icon(Icons.brightness_auto_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('浅色'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('深色'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {current},
            onSelectionChanged: (sel) => notifier.setThemeMode(sel.first),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Seed color picker
// ─────────────────────────────────────────────────────────────────────

class _ColorSection extends ConsumerWidget {
  const _ColorSection({required this.current});

  final Color current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text('主题色', style: theme.textTheme.titleSmall),
          ),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: kPresetColors.map((preset) {
              final isSelected = current.toARGB32() == preset.color.toARGB32();
              return Tooltip(
                message: preset.name,
                child: GestureDetector(
                  onTap: () => notifier.setSeedColor(preset.color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: preset.color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 2.5,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: preset.color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? AppIcons.svgIcon(AppIcons.check, size: 20)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sync (user_id 展示 + 复制)
// ─────────────────────────────────────────────────────────────────────

class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: AppIcons.svgIcon(AppIcons.sync),
      title: const Text('用户 ID'),
      subtitle: Text(
        kLocalUserId,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy_rounded, size: 20),
        tooltip: '复制',
        onPressed: () async {
          await Clipboard.setData(const ClipboardData(text: kLocalUserId));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已复制到剪贴板'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// About
// ─────────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          leading: AppIcons.svgIcon(AppIcons.info),
          title: const Text('版本'),
          trailing: Text(
            '0.0.1',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('开源许可'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showLicensePage(context: context),
        ),
      ],
    );
  }
}
