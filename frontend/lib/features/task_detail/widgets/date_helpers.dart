// 中文相对时间 & 日期格式化工具函数。
import 'package:intl/intl.dart';

String relativeTimeCn(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.isNegative) {
    final absDiff = dt.difference(now);
    if (absDiff.inMinutes < 60) return '${absDiff.inMinutes} 分钟后';
    if (absDiff.inHours < 24) return '${absDiff.inHours} 小时后';
    if (absDiff.inDays < 7) return '${absDiff.inDays} 天后';
    return DateFormat('M月d日').format(dt);
  }

  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  if (diff.inDays < 365) return DateFormat('M月d日').format(dt);
  return DateFormat('yyyy年M月d日').format(dt);
}

String formatDateCn(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateOnly = DateTime(dt.year, dt.month, dt.day);
  final diff = dateOnly.difference(today).inDays;

  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == -1) return '昨天';
  if (diff > 1 && diff <= 7) return '$diff 天后';
  if (diff < -1 && diff >= -7) return '${-diff} 天前';
  if (dt.year == now.year) return DateFormat('M月d日').format(dt);
  return DateFormat('yyyy年M月d日').format(dt);
}

String formatDateTimeCn(DateTime dt) {
  final datePart = formatDateCn(dt);
  final timePart = DateFormat('HH:mm').format(dt);
  return '$datePart $timePart';
}
