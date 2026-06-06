import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'capture_parser.g.dart';

/// 自然语言捕获的解析结果。
class CaptureResult {
  const CaptureResult({
    required this.title,
    this.dueAt,
    this.remindAt,
    this.repeatRuleBody,
  });

  /// 去除时间 / 重复词后的纯标题。
  final String title;
  final DateTime? dueAt;
  final DateTime? remindAt;

  /// RRULE 主体(不含 RRULE: 前缀);无重复则 null。
  final String? repeatRuleBody;

  bool get hasMeta =>
      dueAt != null || remindAt != null || repeatRuleBody != null;
}

/// 捕获解析器接口。本地规则解析为主([RuleCaptureParser]),通过该接口 +
/// [captureParserProvider] 预留 AI 升级接缝。详见 dev_docs/recurring-tasks.md §8.1。
// 单方法抽象是刻意的:作为本地规则 → AI 解析的可替换接缝,保留接口。
// ignore: one_member_abstracts
abstract class CaptureParser {
  CaptureResult parse(String input, {DateTime? now});
}

/// 本地规则解析器:从中文输入里抽取「重复 / 日期 / 时间」,返回结构化结果。
///
/// 例:「每周一三五 9点 交周报」→ 标题「交周报」+ RRULE `FREQ=WEEKLY;BYDAY=MO,WE,FR`
/// + dueAt/remindAt 今天 9:00。无法识别的部分原样留在标题里。
class RuleCaptureParser implements CaptureParser {
  const RuleCaptureParser();

  static const _weekdayChar = {
    '一': 'MO',
    '二': 'TU',
    '三': 'WE',
    '四': 'TH',
    '五': 'FR',
    '六': 'SA',
    '日': 'SU',
    '天': 'SU',
  };

  static const _numerals = {
    '两': 2,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
  };

  @override
  CaptureResult parse(String input, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var work = input;

    String? repeat;
    int? intervalN;
    final weekdays = <String>[];
    DateTime? date;
    int? hour;
    int? minute;

    // 移除匹配到的子串(用于从标题里剔除)。
    void strip(Match m) {
      work = work.replaceRange(m.start, m.end, ' ');
    }

    // ── 1. 工作日 ──
    final workday = RegExp('(每个?|每天)?工作日').firstMatch(work);
    if (workday != null) {
      repeat = 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
      strip(workday);
    }

    // ── 2. 每 N 单位(间隔)──
    if (repeat == null) {
      final iv = RegExp(
        r'每\s*([0-9]+|[两二三四五六七八九十])\s*(天|日|周|星期|个月|月|年)',
      ).firstMatch(work);
      if (iv != null) {
        intervalN = int.tryParse(iv.group(1)!) ?? _numerals[iv.group(1)] ?? 1;
        repeat = 'FREQ=${_freqOf(iv.group(2)!)}';
        strip(iv);
      }
    }

    // ── 3. 每周X(、Y…) / 每星期X ──
    if (repeat == null) {
      final wk = RegExp(
        r'每(?:周|星期)\s*([一二三四五六日天](?:[、,，和\s]*[一二三四五六日天])*)',
      ).firstMatch(work);
      if (wk != null) {
        for (final ch in wk.group(1)!.split('')) {
          final tok = _weekdayChar[ch];
          if (tok != null && !weekdays.contains(tok)) weekdays.add(tok);
        }
        repeat = 'FREQ=WEEKLY';
        strip(wk);
      }
    }

    // ── 4. 简单频率词 ──
    if (repeat == null) {
      final simple = RegExp('(每天|每日|天天|每周|每星期|每月|每年)').firstMatch(work);
      if (simple != null) {
        repeat = 'FREQ=${_freqOf(simple.group(1)!)}';
        strip(simple);
      }
    }

    // ── 5. 相对日期 ──
    final dateM = RegExp('(大后天|后天|明天|明日|今天|今日)').firstMatch(work);
    if (dateM != null) {
      final base = DateTime(today.year, today.month, today.day);
      date = switch (dateM.group(1)) {
        '今天' || '今日' => base,
        '明天' || '明日' => base.add(const Duration(days: 1)),
        '后天' => base.add(const Duration(days: 2)),
        '大后天' => base.add(const Duration(days: 3)),
        _ => base,
      };
      strip(dateM);
    }

    // ── 6. 时间 ──
    final timeM = RegExp(
      r'(上午|早上|下午|晚上|中午|凌晨)?\s*([0-9]{1,2})\s*(?::|：|点|时)\s*([0-9]{1,2}|半)?\s*分?',
    ).firstMatch(work);
    if (timeM != null) {
      var h = int.parse(timeM.group(2)!);
      final period = timeM.group(1);
      final mg = timeM.group(3);
      minute = mg == '半' ? 30 : (mg != null ? int.tryParse(mg) : null);
      minute ??= 0;
      if ((period == '下午' || period == '晚上') && h < 12) h += 12;
      if (period == '中午') h = 12;
      if (period == '凌晨' && h == 12) h = 0;
      if (h >= 0 && h <= 23 && minute >= 0 && minute <= 59) {
        hour = h;
        strip(timeM);
      }
    }

    // 组装重复规则(补 INTERVAL / BYDAY)。
    String? ruleBody;
    if (repeat != null) {
      final parts = [repeat];
      if (intervalN != null && intervalN > 1) parts.add('INTERVAL=$intervalN');
      if (weekdays.isNotEmpty) parts.add('BYDAY=${weekdays.join(',')}');
      ruleBody = parts.join(';');
    }

    // 解析时间 / 日期 → dueAt / remindAt。
    DateTime? dueAt;
    DateTime? remindAt;
    final hasTime = hour != null;
    final resolvedDate =
        date ??
        ((hasTime || ruleBody != null)
            ? DateTime(today.year, today.month, today.day)
            : null);

    if (hasTime && resolvedDate != null) {
      final at = DateTime(
        resolvedDate.year,
        resolvedDate.month,
        resolvedDate.day,
        hour,
        minute ?? 0,
      );
      dueAt = at;
      remindAt = at;
    } else if (resolvedDate != null) {
      dueAt = DateTime(
        resolvedDate.year,
        resolvedDate.month,
        resolvedDate.day,
        23,
        59,
      );
    }

    final title = work.replaceAll(RegExp(r'\s+'), ' ').trim();
    return CaptureResult(
      title: title.isEmpty ? input.trim() : title,
      dueAt: dueAt,
      remindAt: remindAt,
      repeatRuleBody: ruleBody,
    );
  }

  static String _freqOf(String unit) => switch (unit) {
    '天' || '日' || '每天' || '每日' || '天天' => 'DAILY',
    '周' || '星期' || '每周' || '每星期' => 'WEEKLY',
    '月' || '个月' || '每月' => 'MONTHLY',
    '年' || '每年' => 'YEARLY',
    _ => 'DAILY',
  };
}

@Riverpod(keepAlive: true)
CaptureParser captureParser(Ref ref) => const RuleCaptureParser();
