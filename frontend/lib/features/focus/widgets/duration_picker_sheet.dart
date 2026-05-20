import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:achievements/features/focus/providers/focus_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 番茄/休息时长调节底部弹窗。
class DurationPickerSheet extends ConsumerStatefulWidget {
  const DurationPickerSheet({super.key});

  static void show(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const DurationPickerSheet(),
    );
  }

  @override
  ConsumerState<DurationPickerSheet> createState() =>
      _DurationPickerSheetState();
}

class _DurationPickerSheetState extends ConsumerState<DurationPickerSheet> {
  static const _workPresets = [15, 25, 45, 60];
  static const _breakPresets = [3, 5, 10, 15];

  late int _workMinutes;
  late int _breakMinutes;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    // 首次初始化，读取当前计时器状态
    if (!_initialized) {
      final state = ref.read(focusTimerProvider);
      _workMinutes = state.workDuration.inMinutes;
      _breakMinutes = state.breakDuration.inMinutes;
      _initialized = true;
    }

    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        Spacing.md,
        Spacing.xl,
        Spacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Spacing.lg),

          // ── 工作时长 ──
          Text(
            '专注时长',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _PresetRow(
            presets: _workPresets,
            selected: _workMinutes,
            unit: 'min',
            onSelect: (v) => setState(() => _workMinutes = v),
          ),
          const SizedBox(height: Spacing.sm),
          _SliderRow(
            value: _workMinutes,
            min: 5,
            max: 90,
            onChanged: (v) => setState(() => _workMinutes = v),
          ),
          const SizedBox(height: Spacing.lg),

          // ── 休息时长 ──
          Text(
            '休息时长',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _PresetRow(
            presets: _breakPresets,
            selected: _breakMinutes,
            unit: 'min',
            onSelect: (v) => setState(() => _breakMinutes = v),
          ),
          const SizedBox(height: Spacing.sm),
          _SliderRow(
            value: _breakMinutes,
            min: 1,
            max: 30,
            onChanged: (v) => setState(() => _breakMinutes = v),
          ),
          const SizedBox(height: Spacing.xl),

          // ── 确认按钮 ──
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final notifier = ref.read(focusTimerProvider.notifier);
                notifier.setWorkDuration(
                  Duration(minutes: _workMinutes),
                );
                notifier.setBreakDuration(
                  Duration(minutes: _breakMinutes),
                );
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              ),
              child: Text(
                '$_workMinutes 分钟专注 · $_breakMinutes 分钟休息',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.presets,
    required this.selected,
    required this.unit,
    required this.onSelect,
  });

  final List<int> presets;
  final int selected;
  final String unit;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (final v in presets) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected == v
                      ? scheme.primary.withValues(alpha: 0.2)
                      : scheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(Radii.chip),
                  border: Border.all(
                    color: selected == v
                        ? scheme.primary.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$v$unit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected == v ? FontWeight.w600 : FontWeight.w400,
                    color: selected == v
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
          if (v != presets.last) const SizedBox(width: Spacing.sm),
        ],
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          '$min',
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: scheme.primary,
              inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.1),
              thumbColor: scheme.onSurface,
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        Text(
          '$max',
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
