import 'package:achievements/core/id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const templateId = '0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b';

  test('同一 (模板, 发生点) 始终派生同一 override id（确定性）', () {
    final t = DateTime.utc(2026, 6, 8, 1, 0);
    expect(occurrenceId(templateId, t), occurrenceId(templateId, t));
  });

  test('不同发生点派生不同 id', () {
    final a = DateTime.utc(2026, 6, 8, 1, 0);
    final b = DateTime.utc(2026, 6, 15, 1, 0);
    expect(occurrenceId(templateId, a), isNot(occurrenceId(templateId, b)));
  });

  test('不同模板派生不同 id', () {
    const otherTemplate = '0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5c';
    final t = DateTime.utc(2026, 6, 8, 1, 0);
    expect(occurrenceId(templateId, t), isNot(occurrenceId(otherTemplate, t)));
  });

  test('与时区无关：本地时刻先归一到 UTC 再散列', () {
    // 同一物理时刻的不同时区表示应得到相同 id。
    final utc = DateTime.utc(2026, 6, 8, 1, 0);
    final sameInstant = utc.toLocal();
    expect(
      occurrenceId(templateId, utc),
      occurrenceId(templateId, sameInstant),
    );
  });

  test('输出是合法 UUID 格式', () {
    final id = occurrenceId(templateId, DateTime.utc(2026, 6, 8, 1, 0));
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(id),
      isTrue,
    );
  });
}
