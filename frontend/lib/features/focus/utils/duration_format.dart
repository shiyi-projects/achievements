/// 将秒数格式化为可读文本。
///
/// - `< 60`  → `"45s"`
/// - `< 3600` → `"12m"`（或 `"12m 30s"` 如果 [showSeconds] 为 true）
/// - `≥ 3600` → `"1h 30m"`
String formatFocusDuration(int seconds, {bool showSeconds = false}) {
  if (seconds <= 0) return '0s';
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (showSeconds && s > 0) return '${m}m ${s}s';
    return '${m}m';
  }
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return m > 0 ? '${h}h ${m}m' : '${h}h';
}
