import 'package:flutter/foundation.dart';

/// 重复频率。
enum RecurrenceFreq { daily, weekly, monthly, yearly }

/// 结束方式。
enum RecurrenceEndMode { never, count, until }

/// 重复规则的「可编辑草稿」:UI 选择器的状态模型,负责与 RRULE 主体串双向转换,
/// 并产出中文摘要。纯逻辑、可单测,不依赖 Flutter widget。
///
/// 覆盖选择器当前提供的能力(频率 / 间隔 / 周几 / 结束条件)。RRULE 存储层支持更
/// 丰富的部件(BYMONTHDAY / BYSETPOS 等),[fromRuleBody] 对无法表达的部件返回 null
/// (回退到「只读展示原始串」),不会丢数据。详见 dev_docs/recurring-tasks.md。
@immutable
class RecurrenceRuleDraft {
  const RecurrenceRuleDraft({
    required this.freq,
    this.interval = 1,
    this.byWeekdays = const {},
    this.endMode = RecurrenceEndMode.never,
    this.count,
    this.until,
  });

  final RecurrenceFreq freq;

  /// 间隔,≥1。
  final int interval;

  /// 仅 [RecurrenceFreq.weekly] 有效:DateTime.monday(1)..sunday(7)。
  final Set<int> byWeekdays;

  final RecurrenceEndMode endMode;

  /// [RecurrenceEndMode.count] 时的总次数。
  final int? count;

  /// [RecurrenceEndMode.until] 时的结束日期(本地)。
  final DateTime? until;

  RecurrenceRuleDraft copyWith({
    RecurrenceFreq? freq,
    int? interval,
    Set<int>? byWeekdays,
    RecurrenceEndMode? endMode,
    int? count,
    DateTime? until,
  }) {
    return RecurrenceRuleDraft(
      freq: freq ?? this.freq,
      interval: interval ?? this.interval,
      byWeekdays: byWeekdays ?? this.byWeekdays,
      endMode: endMode ?? this.endMode,
      count: count ?? this.count,
      until: until ?? this.until,
    );
  }

  static const _freqToken = {
    RecurrenceFreq.daily: 'DAILY',
    RecurrenceFreq.weekly: 'WEEKLY',
    RecurrenceFreq.monthly: 'MONTHLY',
    RecurrenceFreq.yearly: 'YEARLY',
  };

  static const _weekdayToken = {
    DateTime.monday: 'MO',
    DateTime.tuesday: 'TU',
    DateTime.wednesday: 'WE',
    DateTime.thursday: 'TH',
    DateTime.friday: 'FR',
    DateTime.saturday: 'SA',
    DateTime.sunday: 'SU',
  };

  static final _tokenToWeekday = {
    for (final e in _weekdayToken.entries) e.value: e.key,
  };

  /// 编码为 RRULE 主体(不含 `RRULE:` 前缀)。
  String toRuleBody() {
    final parts = <String>['FREQ=${_freqToken[freq]}'];
    if (interval > 1) parts.add('INTERVAL=$interval');
    if (freq == RecurrenceFreq.weekly && byWeekdays.isNotEmpty) {
      final sorted = byWeekdays.toList()..sort();
      parts.add('BYDAY=${sorted.map((d) => _weekdayToken[d]).join(',')}');
    }
    switch (endMode) {
      case RecurrenceEndMode.never:
        break;
      case RecurrenceEndMode.count:
        if (count != null && count! >= 1) parts.add('COUNT=$count');
      case RecurrenceEndMode.until:
        if (until != null) {
          // UNTIL 取该日终点。注意:展开全程用「本地组件标记为 UTC」的墙钟语义
          // (见 RecurrenceService),故此处直接用本地年月日组件标 Z,**不做时区换算**,
          // 与锚点 / 发生点保持同一时间系,否则跨时区会整体偏移一天。
          final u = until!;
          final s =
              '${u.year.toString().padLeft(4, '0')}'
              '${u.month.toString().padLeft(2, '0')}'
              '${u.day.toString().padLeft(2, '0')}'
              'T235959Z';
          parts.add('UNTIL=$s');
        }
    }
    return parts.join(';');
  }

  /// 从 RRULE 主体解析。无法用当前选择器表达(含 BYMONTHDAY / BYSETPOS / 多 FREQ 等)
  /// 时返回 null。
  static RecurrenceRuleDraft? fromRuleBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    final raw = trimmed.toUpperCase().startsWith('RRULE:')
        ? trimmed.substring(6)
        : trimmed;

    RecurrenceFreq? freq;
    var interval = 1;
    final weekdays = <int>{};
    var endMode = RecurrenceEndMode.never;
    int? count;
    DateTime? until;

    for (final part in raw.split(';')) {
      if (part.isEmpty) continue;
      final kv = part.split('=');
      if (kv.length != 2) return null;
      final key = kv[0].toUpperCase();
      final value = kv[1].toUpperCase();
      switch (key) {
        case 'FREQ':
          freq = switch (value) {
            'DAILY' => RecurrenceFreq.daily,
            'WEEKLY' => RecurrenceFreq.weekly,
            'MONTHLY' => RecurrenceFreq.monthly,
            'YEARLY' => RecurrenceFreq.yearly,
            _ => null,
          };
          if (freq == null) return null;
        case 'INTERVAL':
          final n = int.tryParse(value);
          if (n == null || n < 1) return null;
          interval = n;
        case 'BYDAY':
          for (final tok in value.split(',')) {
            // 带序号的 BYDAY(如 2MO、-1FR)超出选择器能力。
            final wd = _tokenToWeekday[tok];
            if (wd == null) return null;
            weekdays.add(wd);
          }
        case 'COUNT':
          final n = int.tryParse(value);
          if (n == null || n < 1) return null;
          count = n;
          endMode = RecurrenceEndMode.count;
        case 'UNTIL':
          until = _parseUntil(value);
          if (until == null) return null;
          endMode = RecurrenceEndMode.until;
        default:
          // BYMONTHDAY / BYSETPOS / WKST 等当前选择器不表达 → 交回只读展示。
          return null;
      }
    }
    if (freq == null) return null;
    if (count != null && until != null) return null;
    return RecurrenceRuleDraft(
      freq: freq,
      interval: interval,
      byWeekdays: weekdays,
      endMode: endMode,
      count: count,
      until: until,
    );
  }

  static DateTime? _parseUntil(String value) {
    // 形如 20260701T235959Z 或 20260701。
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(value);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  /// 中文摘要,如「每 2 周的周一、周三，共 10 次」。
  String describe() {
    final unit = switch (freq) {
      RecurrenceFreq.daily => '天',
      RecurrenceFreq.weekly => '周',
      RecurrenceFreq.monthly => '个月',
      RecurrenceFreq.yearly => '年',
    };
    final base = interval > 1 ? '每 $interval $unit' : '每$unit';

    final buf = StringBuffer(base);
    if (freq == RecurrenceFreq.weekly && byWeekdays.isNotEmpty) {
      const names = {
        DateTime.monday: '一',
        DateTime.tuesday: '二',
        DateTime.wednesday: '三',
        DateTime.thursday: '四',
        DateTime.friday: '五',
        DateTime.saturday: '六',
        DateTime.sunday: '日',
      };
      final sorted = byWeekdays.toList()..sort();
      buf.write('的周${sorted.map((d) => names[d]).join('、周')}');
    }
    switch (endMode) {
      case RecurrenceEndMode.never:
        break;
      case RecurrenceEndMode.count:
        if (count != null) buf.write('，共 $count 次');
      case RecurrenceEndMode.until:
        if (until != null) {
          buf.write(
            '，至 ${until!.year}-'
            '${until!.month.toString().padLeft(2, '0')}-'
            '${until!.day.toString().padLeft(2, '0')}',
          );
        }
    }
    return buf.toString();
  }
}
