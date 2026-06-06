import 'package:achievements/core/recurrence/recurrence_rule_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toRuleBody', () {
    test('每天默认省略 INTERVAL', () {
      const d = RecurrenceRuleDraft(freq: RecurrenceFreq.daily);
      expect(d.toRuleBody(), 'FREQ=DAILY');
    });

    test('每 2 周 + 周一三五 + COUNT', () {
      const d = RecurrenceRuleDraft(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        byWeekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
        endMode: RecurrenceEndMode.count,
        count: 10,
      );
      expect(d.toRuleBody(), 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;COUNT=10');
    });

    test('UNTIL 编码为 UTC 当日终点', () {
      final d = RecurrenceRuleDraft(
        freq: RecurrenceFreq.daily,
        endMode: RecurrenceEndMode.until,
        until: DateTime(2026, 7, 1),
      );
      expect(d.toRuleBody(), contains('UNTIL='));
      expect(d.toRuleBody(), contains('20260701T235959Z'));
    });

    test('非每周时忽略 BYDAY', () {
      const d = RecurrenceRuleDraft(
        freq: RecurrenceFreq.monthly,
        byWeekdays: {DateTime.monday},
      );
      expect(d.toRuleBody(), 'FREQ=MONTHLY');
    });
  });

  group('fromRuleBody', () {
    test('round-trip 保真', () {
      const body = 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;COUNT=10';
      final d = RecurrenceRuleDraft.fromRuleBody(body);
      expect(d, isNotNull);
      expect(d!.toRuleBody(), body);
    });

    test('容忍 RRULE: 前缀', () {
      final d = RecurrenceRuleDraft.fromRuleBody('RRULE:FREQ=DAILY');
      expect(d?.freq, RecurrenceFreq.daily);
    });

    test('超出选择器能力的部件返回 null(交回只读展示)', () {
      // BYMONTHDAY 当前选择器不表达。
      expect(
        RecurrenceRuleDraft.fromRuleBody('FREQ=MONTHLY;BYMONTHDAY=-1'),
        isNull,
      );
      // 带序号 BYDAY(每月第二个周二)。
      expect(
        RecurrenceRuleDraft.fromRuleBody('FREQ=MONTHLY;BYDAY=2TU'),
        isNull,
      );
    });

    test('空串返回 null', () {
      expect(RecurrenceRuleDraft.fromRuleBody('  '), isNull);
    });

    test('UNTIL 解析回日期', () {
      final d = RecurrenceRuleDraft.fromRuleBody(
        'FREQ=DAILY;UNTIL=20260701T235959Z',
      );
      expect(d, isNotNull);
      expect(d!.endMode, RecurrenceEndMode.until);
      expect(d.until, DateTime(2026, 7, 1));
    });
  });

  group('describe', () {
    test('每天', () {
      expect(
        const RecurrenceRuleDraft(freq: RecurrenceFreq.daily).describe(),
        '每天',
      );
    });

    test('每 2 周的周一、周三', () {
      const d = RecurrenceRuleDraft(
        freq: RecurrenceFreq.weekly,
        interval: 2,
        byWeekdays: {DateTime.monday, DateTime.wednesday},
      );
      expect(d.describe(), '每 2 周的周一、周三');
    });

    test('附带次数', () {
      const d = RecurrenceRuleDraft(
        freq: RecurrenceFreq.daily,
        endMode: RecurrenceEndMode.count,
        count: 5,
      );
      expect(d.describe(), '每天，共 5 次');
    });
  });
}
