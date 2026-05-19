import 'package:achievements/core/constants.dart';
import 'package:flutter/material.dart';

/// 优先级标签:[TaskPriority.none] 时不渲染。
///
/// 配色:
/// - low    -> surfaceContainerHighest(中性,弱提示)
/// - medium -> tertiaryContainer
/// - high   -> errorContainer
class PriorityChip extends StatelessWidget {
  const PriorityChip({required this.priority, super.key});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    if (priority == TaskPriority.none) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (priority) {
      TaskPriority.high => (scheme.errorContainer, scheme.onErrorContainer),
      TaskPriority.medium => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      TaskPriority.low => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      TaskPriority.none => (Colors.transparent, Colors.transparent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
