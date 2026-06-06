import 'package:achievements/core/id.dart';
import 'package:achievements/core/recurrence/recurrence_rule_draft.dart';
import 'package:achievements/core/recurrence/recurrence_service.dart';
import 'package:achievements/data/local/database.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一个最小可用的 Task(override)用于合并测试。
Task _override({
  required String id,
  required String templateId,
  required DateTime occurrence,
  DateTime? completedAt,
  DateTime? deletedAt,
}) {
  final now = DateTime(2026, 1, 1);
  return Task(
    id: id,
    userId: 'u',
    createdAt: now,
    updatedAt: now,
    deletedAt: deletedAt,
    version: 1,
    listId: 'list',
    title: 'X',
    priority: 0,
    dueAt: occurrence,
    recurrenceParentId: templateId,
    occurrenceDate: occurrence,
    completedAt: completedAt,
    sortOrder: 0,
    starred: false,
    focusedSeconds: 0,
  );
}

void main() {
  const svc = RecurrenceService();
  const templateId = '0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b';

  group('expand', () {
    test('DAILY 在窗口内逐日展开', () {
      final dates = svc.expand(
        rule: 'FREQ=DAILY',
        dtStart: DateTime(2026, 6, 1, 9),
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 6),
      );
      expect(dates, hasLength(5));
      expect(dates.first, DateTime(2026, 6, 1, 9));
      expect(dates.last, DateTime(2026, 6, 5, 9));
      expect(dates.every((d) => d.hour == 9), isTrue);
    });

    test('COUNT 限制总次数', () {
      final dates = svc.expand(
        rule: 'FREQ=DAILY;COUNT=3',
        dtStart: DateTime(2026, 6, 1, 9),
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(dates, hasLength(3));
    });

    test('UNTIL 截断系列(含界)', () {
      final dates = svc.expand(
        rule: 'FREQ=DAILY;UNTIL=20260603T090000Z',
        dtStart: DateTime(2026, 6, 1, 9),
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(dates, hasLength(3)); // 6/1, 6/2, 6/3
    });

    test('WEEKLY + BYDAY 只落指定周几', () {
      final dates = svc.expand(
        rule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
        dtStart: DateTime(2026, 6, 1, 8),
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 15),
      );
      expect(dates, isNotEmpty);
      expect(
        dates.every(
          (d) => {
            DateTime.monday,
            DateTime.wednesday,
            DateTime.friday,
          }.contains(d.weekday),
        ),
        isTrue,
      );
    });

    test('INTERVAL=2 周展开间隔为两周', () {
      final dates = svc.expand(
        rule: 'FREQ=WEEKLY;INTERVAL=2',
        dtStart: DateTime(2026, 6, 1, 8),
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 7, 1),
      );
      // 6/1, 6/15, 6/29
      expect(dates, hasLength(3));
      expect(dates[1].difference(dates[0]).inDays, 14);
    });

    test('非法规则返回空,不抛异常', () {
      expect(
        svc.expand(
          rule: 'NONSENSE',
          dtStart: DateTime(2026, 6, 1),
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 7, 1),
        ),
        isEmpty,
      );
    });

    test('窗口在系列锚点之前返回空', () {
      final dates = svc.expand(
        rule: 'FREQ=DAILY',
        dtStart: DateTime(2026, 6, 10),
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 5),
      );
      expect(dates, isEmpty);
    });
  });

  group('draft 与 expand 跨模块一致性', () {
    test('draft 的 UNTIL 喂给 expand 不偏移一天(墙钟时间系一致)', () {
      final draft = RecurrenceRuleDraft(
        freq: RecurrenceFreq.daily,
        endMode: RecurrenceEndMode.until,
        until: DateTime(2026, 7, 1),
      );
      final dates = svc.expand(
        rule: draft.toRuleBody(),
        dtStart: DateTime(2026, 6, 28, 9),
        from: DateTime(2026, 6, 28),
        to: DateTime(2026, 7, 10),
      );
      // 应含 7/1,不含 7/2(UNTIL 当日终点截断),且不被时区偏移成 6/30。
      expect(dates.last, DateTime(2026, 7, 1, 9));
      expect(dates.map((d) => d.day), contains(1));
      expect(dates.every((d) => !d.isAfter(DateTime(2026, 7, 1, 9))), isTrue);
    });
  });

  group('nextOccurrence', () {
    test('返回首个 ≥ after 的发生点', () {
      final next = svc.nextOccurrence(
        rule: 'FREQ=DAILY',
        dtStart: DateTime(2026, 6, 1, 9),
        after: DateTime(2026, 6, 3, 12),
      );
      expect(next, DateTime(2026, 6, 4, 9));
    });

    test('after 恰为某发生点时含界返回它', () {
      final next = svc.nextOccurrence(
        rule: 'FREQ=DAILY',
        dtStart: DateTime(2026, 6, 1, 9),
        after: DateTime(2026, 6, 3, 9),
      );
      expect(next, DateTime(2026, 6, 3, 9));
    });
  });

  group('mergeOverrides', () {
    test('完成 override 替换虚影、软删 override 作为 EXDATE 跳过', () {
      final d1 = DateTime(2026, 6, 1, 9);
      final d2 = DateTime(2026, 6, 2, 9);
      final d3 = DateTime(2026, 6, 3, 9);
      final virtual = [d1, d2, d3];

      final completed = _override(
        id: occurrenceId(templateId, d2),
        templateId: templateId,
        occurrence: d2,
        completedAt: DateTime(2026, 6, 2, 10),
      );
      final skipped = _override(
        id: occurrenceId(templateId, d3),
        templateId: templateId,
        occurrence: d3,
        deletedAt: DateTime(2026, 6, 3, 1),
      );

      final views = svc.mergeOverrides(
        templateId: templateId,
        virtualDates: virtual,
        overrides: [completed, skipped],
      );

      expect(views, hasLength(2)); // d3 被跳过
      expect(views[0].date, d1);
      expect(views[0].isVirtual, isTrue);
      expect(views[1].date, d2);
      expect(views[1].isVirtual, isFalse);
      expect(views[1].materialized!.completedAt, isNotNull);
    });

    test('无 override 时全部为虚影', () {
      final virtual = [DateTime(2026, 6, 1, 9), DateTime(2026, 6, 2, 9)];
      final views = svc.mergeOverrides(
        templateId: templateId,
        virtualDates: virtual,
        overrides: const [],
      );
      expect(views, hasLength(2));
      expect(views.every((v) => v.isVirtual), isTrue);
    });
  });
}
