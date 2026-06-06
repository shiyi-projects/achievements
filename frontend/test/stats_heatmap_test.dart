import 'package:achievements/data/local/database.dart';
import 'package:achievements/features/statistics/data/stats_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归测试:DateTime 以 unix 秒整数存储,且本项目 sqlite 的 'localtime' 修饰符返回
/// NULL → 统计须用「时间戳 + 本地偏移后按 unixepoch 格式化」。否则热力图 / 连续天数 /
/// 单日最多 / 早起夜猫成就全部恒为 0/false。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> completeAt(String id, DateTime localCompletedAt) async {
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            userId: 'u',
            listId: 'list',
            title: 'T-$id',
            completedAt: Value(localCompletedAt),
          ),
        );
  }

  String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  test('completionHeatmap 按本地日聚合(非乱码键/非 0)', () async {
    final repo = StatsRepository(db, 'u');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    await completeAt('a', today);
    await completeAt('b', today.add(const Duration(hours: 1)));

    final hm = await repo.completionHeatmap();
    expect(hm[dayKey(today)], 2);
  });

  test('maxDailyCompletedTasks 取单日最多', () async {
    final repo = StatsRepository(db, 'u');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    await completeAt('a', today);
    await completeAt('b', today.add(const Duration(hours: 2)));
    await completeAt('c', today.add(const Duration(hours: 4)));
    expect(await repo.maxDailyCompletedTasks(), 3);
  });

  test('早起 / 夜猫 完成判定(本地时刻)', () async {
    final repo = StatsRepository(db, 'u');
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    await completeAt('early', base.add(const Duration(hours: 6))); // 06:00 本地
    expect(await repo.hasEarlyCompletion(), isTrue);
    expect(await repo.hasLateCompletion(), isFalse);

    await completeAt(
      'late',
      base.add(const Duration(hours: 23, minutes: 30)),
    ); // 23:30
    expect(await repo.hasLateCompletion(), isTrue);
  });
}
