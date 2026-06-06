import 'package:achievements/core/id.dart';
import 'package:achievements/core/notifications/reminder_scheduler.dart';
import 'package:achievements/core/recurrence/recurrence_service.dart';
import 'package:achievements/data/local/database.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task({
  required String id,
  DateTime? dueAt,
  DateTime? remindAt,
  String? repeatRule,
  String? recurrenceParentId,
  DateTime? occurrenceDate,
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
    title: 'T-$id',
    priority: 0,
    dueAt: dueAt,
    remindAt: remindAt,
    repeatRule: repeatRule,
    recurrenceParentId: recurrenceParentId,
    occurrenceDate: occurrenceDate,
    sortOrder: 0,
    starred: false,
    focusedSeconds: 0,
  );
}

int idFor(String key) => key.hashCode & 0x7fffffff;

void main() {
  const svc = RecurrenceService();
  const templateId = '0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b';
  final now = DateTime(2026, 6, 6, 8);

  test('一次性提醒被排程,过期的跳过', () {
    final future = _task(id: 'a', remindAt: now.add(const Duration(hours: 2)));
    final past = _task(
      id: 'b',
      remindAt: now.subtract(const Duration(hours: 2)),
    );
    final out = ReminderScheduler.computeSchedule(
      activeReminders: [future, past],
      recurringRows: const [],
      now: now,
      recurrence: svc,
    );
    expect(out, hasLength(1));
    expect(out.single.payload, 'a');
  });

  test('重复模板:窗口展开多个发生点,锚点不走普通路径(无重复)', () {
    final due = DateTime(2026, 6, 7, 9);
    final template = _task(
      id: templateId,
      dueAt: due,
      remindAt: DateTime(2026, 6, 7, 8, 45), // 提前 15 分钟
      repeatRule: 'FREQ=DAILY;COUNT=3', // 6/7,6/8,6/9
    );
    final out = ReminderScheduler.computeSchedule(
      activeReminders: [template], // 模板自身也带 remindAt,出现在普通流里
      recurringRows: [template],
      now: now,
      recurrence: svc,
    );

    // 3 个发生点,各排一条;模板不走普通路径(无 id == idFor(templateId))。
    expect(out, hasLength(3));
    expect(out.every((r) => r.payload == templateId), isTrue);
    expect(out.any((r) => r.id == idFor(templateId)), isFalse);

    // 提醒时刻 = 各发生点 - 15 分钟。
    final whens = out.map((r) => r.when).toList()..sort();
    expect(whens.first, DateTime(2026, 6, 7, 8, 45));
    expect(whens[1], DateTime(2026, 6, 8, 8, 45));
    expect(whens[2], DateTime(2026, 6, 9, 8, 45));
  });

  test('已实体化 override 的发生点在重复路径中跳过(由普通路径覆盖)', () {
    final due = DateTime(2026, 6, 7, 9);
    final template = _task(
      id: templateId,
      dueAt: due,
      remindAt: DateTime(2026, 6, 7, 8, 45),
      repeatRule: 'FREQ=DAILY;COUNT=3',
    );
    final occ8 = DateTime(2026, 6, 8, 9);
    final override = _task(
      id: occurrenceId(templateId, occ8),
      dueAt: occ8,
      remindAt: DateTime(2026, 6, 8, 8, 45),
      recurrenceParentId: templateId,
      occurrenceDate: occ8,
    );

    final out = ReminderScheduler.computeSchedule(
      activeReminders: [template, override], // override 是真实任务,走普通路径
      recurringRows: [template, override],
      now: now,
      recurrence: svc,
    );

    // 6/8 由 override(普通路径)排,重复路径跳过 → 仍是 3 条且无重复 id。
    expect(out, hasLength(3));
    final ids = out.map((r) => r.id).toSet();
    expect(ids, hasLength(3));
    // override 走普通路径,其 id 来自 override.id。
    expect(out.any((r) => r.id == idFor(override.id)), isTrue);
  });

  test('无提醒的模板不产生重复提醒', () {
    final template = _task(
      id: templateId,
      dueAt: DateTime(2026, 6, 7, 9),
      repeatRule: 'FREQ=DAILY',
      // remindAt 为空
    );
    final out = ReminderScheduler.computeSchedule(
      activeReminders: const [],
      recurringRows: [template],
      now: now,
      recurrence: svc,
    );
    expect(out, isEmpty);
  });
}
