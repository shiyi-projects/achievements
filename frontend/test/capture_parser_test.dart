import 'package:achievements/core/capture/capture_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = RuleCaptureParser();
  // 固定 now = 2026-06-06(周六)以便断言相对日期。
  final now = DateTime(2026, 6, 6, 8);

  test('每天 → DAILY,标题剔除频率词', () {
    final r = parser.parse('每天 写日记', now: now);
    expect(r.repeatRuleBody, 'FREQ=DAILY');
    expect(r.title, '写日记');
    expect(r.dueAt, isNotNull); // 锚点落今天
  });

  test('每周一三五 → WEEKLY + BYDAY', () {
    final r = parser.parse('每周一三五 交周报', now: now);
    expect(r.repeatRuleBody, 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
    expect(r.title, '交周报');
  });

  test('工作日 → 周一到周五', () {
    final r = parser.parse('工作日 站会', now: now);
    expect(r.repeatRuleBody, 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR');
    expect(r.title, '站会');
  });

  test('每2周 → INTERVAL', () {
    final r = parser.parse('每2周 复盘', now: now);
    expect(r.repeatRuleBody, 'FREQ=WEEKLY;INTERVAL=2');
    expect(r.title, '复盘');
  });

  test('每三个月 → 中文数字 + MONTHLY', () {
    final r = parser.parse('每三个月 体检', now: now);
    expect(r.repeatRuleBody, 'FREQ=MONTHLY;INTERVAL=3');
    expect(r.title, '体检');
  });

  test('明天9点 → 明天的提醒', () {
    final r = parser.parse('明天9点 开会', now: now);
    expect(r.title, '开会');
    expect(r.remindAt, DateTime(2026, 6, 7, 9));
    expect(r.dueAt, DateTime(2026, 6, 7, 9));
  });

  test('下午3点半 → 15:30', () {
    final r = parser.parse('下午3点半 取快递', now: now);
    expect(r.remindAt, DateTime(2026, 6, 6, 15, 30));
    expect(r.title, '取快递');
  });

  test('每周9点 → 重复 + 时间', () {
    final r = parser.parse('每天9点 吃药', now: now);
    expect(r.repeatRuleBody, 'FREQ=DAILY');
    expect(r.remindAt, DateTime(2026, 6, 6, 9));
    expect(r.title, '吃药');
  });

  test('明天(仅日期,无时间)→ 截止当天 23:59', () {
    final r = parser.parse('明天 交房租', now: now);
    expect(r.dueAt, DateTime(2026, 6, 7, 23, 59));
    expect(r.remindAt, isNull);
    expect(r.title, '交房租');
  });

  test('无任何时间/重复词 → 原样标题,无 meta', () {
    final r = parser.parse('买牛奶', now: now);
    expect(r.title, '买牛奶');
    expect(r.hasMeta, isFalse);
  });

  test('标题为空时回退到原始输入', () {
    final r = parser.parse('每天', now: now);
    expect(r.title, '每天');
    expect(r.repeatRuleBody, 'FREQ=DAILY');
  });
}
