import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 番茄钟 / 自由模式切换选择器。
///
/// 仅在 [FocusPhase.idle] 时可交互；其他阶段呈现禁用外观。
class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  static const _modes = [
    (FocusMode.pomodoro, '番茄钟 25 min'),
    (FocusMode.free, '自由模式'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusTimerProvider);
    final notifier = ref.read(focusTimerProvider.notifier);
    final isEnabled = state.phase == FocusPhase.idle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.base),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (mode, label) in _modes) ...[
            _ModeChip(
              label: label,
              selected: state.mode == mode,
              enabled: isEnabled,
              onSelected: isEnabled ? () => notifier.setMode(mode) : null,
            ),
            if (mode != _modes.last.$1) const SizedBox(width: Spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      isEnabled: enabled,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      onSelected: onSelected != null ? (_) => onSelected!() : null,
    );
  }
}
