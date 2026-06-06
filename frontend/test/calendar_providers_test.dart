import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/features/calendar/providers/calendar_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task({
  required String id,
  required DateTime dueAt,
  String? repeatRule,
  String? recurrenceParentId,
  DateTime? occurrenceDate,
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
    title: 'T',
    priority: 0,
    dueAt: dueAt,
    repeatRule: repeatRule,
    recurrenceParentId: recurrenceParentId,
    occurrenceDate: occurrenceDate,
    completedAt: completedAt,
    sortOrder: 0,
    starred: false,
    focusedSeconds: 0,
  );
}

void main() {
  test('日历展开:一次性 + 重复虚拟展开 + override 合并 + EXDATE 跳过', () {
    const templateId = '0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b';
    final jun1 = DateTime(2026, 6, 1, 9);
    final jun3 = DateTime(2026, 6, 3, 9);
    final jun4 = DateTime(2026, 6, 4, 9);

    final oneTime = _task(id: 'o1', dueAt: DateTime(2026, 6, 5, 10));
    final template = _task(
      id: templateId,
      dueAt: jun1,
      repeatRule: 'FREQ=DAILY;COUNT=4', // 6/1,2,3,4
    );
    final completedOverride = _task(
      id: occurrenceId(templateId, jun3),
      dueAt: jun3,
      recurrenceParentId: templateId,
      occurrenceDate: jun3,
      completedAt: DateTime(2026, 6, 3, 10),
    );
    final skipOverride = _task(
      id: occurrenceId(templateId, jun4),
      dueAt: jun4,
      recurrenceParentId: templateId,
      occurrenceDate: jun4,
      deletedAt: DateTime(2026, 6, 3, 23),
    );

    // monthTasks = 未删行(含模板与已完成 override);recurring = 模板 + 全部 override。
    final monthTasks = [oneTime, template, completedOverride];
    final recurring = [template, completedOverride, skipOverride];

    final container = ProviderContainer(
      overrides: [
        focusedMonthProvider.overrideWith((ref) => DateTime(2026, 6)),
        monthTasksProvider.overrideWithValue(AsyncValue.data(monthTasks)),
        recurringRowsProvider.overrideWithValue(AsyncValue.data(recurring)),
      ],
    );
    addTearDown(container.dispose);

    final byDay = container.read(calendarEntriesByDayProvider);

    // 6/4 被 EXDATE 跳过;模板/override 不在一次性循环里重复计数。
    expect(byDay.keys.toSet(), {1, 2, 3, 5});
    expect(byDay[1]!.single.isVirtual, isTrue);
    expect(byDay[2]!.single.isVirtual, isTrue);
    // 6/3 是已实体化的完成 override(非虚拟)。
    expect(byDay[3]!.single.isVirtual, isFalse);
    expect(byDay[3]!.single.displayTask.completedAt, isNotNull);
    // 6/5 一次性任务。
    expect(byDay[5]!.single.isVirtual, isFalse);
    expect(byDay[5]!.single.displayTask.id, 'o1');

    final stats = container.read(monthStatsProvider);
    expect(stats.total, 4);
    expect(stats.completed, 1);
    expect(stats.activeDays, 4);
  });
}
