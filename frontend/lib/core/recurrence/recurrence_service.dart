import 'package:achievements/core/id.dart';
import 'package:achievements/data/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rrule/rrule.dart';

part 'recurrence_service.g.dart';

/// 重复系列在某窗口内一个发生点的最终呈现。
///
/// [materialized] 非 null 表示该发生点已被实体化(完成 / 改期 = override 实体);
/// 为 null 表示纯虚影(尚未落库)。[date] 是用于排序 / 展示的本地时刻:虚影取规则
/// 算出的发生点,实体取 override 的 dueAt(允许用户把某次挪到别的时间)。
class OccurrenceView {
  const OccurrenceView({required this.date, this.materialized});

  final DateTime date;
  final Task? materialized;

  bool get isVirtual => materialized == null;
}

/// 纯计算的重复规则引擎:解析 RRULE、按窗口展开虚拟发生点、与已实体化 override 合并。
///
/// 不触碰数据库 —— DB 读写(实体化 / 完成 / 删除)在 [`TaskRepository`] 中,二者共同
/// 构成「重复引擎」。详见 dev_docs/recurring-tasks.md。
///
/// 时区策略:对外一律用**本地墙上时间**语义(用户说的「每天 9 点」是墙钟)。内部把
/// 本地时刻按组件搬到 UTC 进行展开(rrule 包强制 UTC),再搬回本地。中国无 DST,该
/// 「UTC 墙钟」法可避免任何时区 / 夏令时漂移。
class RecurrenceService {
  const RecurrenceService();

  /// 解析 RRULE 主体(不含 `DTSTART` / `RRULE:` 前缀);非法返回 null,不抛异常。
  RecurrenceRule? tryParse(String body) {
    if (body.trim().isEmpty) return null;
    final normalized = body.toUpperCase().startsWith('RRULE:')
        ? body
        : 'RRULE:$body';
    try {
      return RecurrenceRule.fromString(normalized);
    } on Object {
      return null;
    }
  }

  /// 把 [rule] 在 `[from, to)` 窗口内的发生点展开为本地时刻列表(升序)。
  ///
  /// [dtStart] 为系列锚点(模板的 dueAt)。[max] 是防御性上限,避免病态规则把内存撑爆。
  List<DateTime> expand({
    required String rule,
    required DateTime dtStart,
    required DateTime from,
    required DateTime to,
    int max = 750,
  }) {
    final parsed = tryParse(rule);
    if (parsed == null) return const [];

    final anchor = _toUtcWall(dtStart);
    final afterU = _toUtcWall(from);
    final beforeU = _toUtcWall(to);
    if (!beforeU.isAfter(afterU)) return const [];
    // 窗口整体早于系列锚点 → 无发生点(首个发生点必 ≥ 锚点)。
    if (!beforeU.isAfter(anchor)) return const [];
    // rrule 要求 after ≥ start;窗口下界早于锚点时省略 after,由 start 兜底下界。
    final effectiveAfter = afterU.isAfter(anchor) ? afterU : null;

    final out = <DateTime>[];
    for (final inst in parsed.getInstances(
      start: anchor,
      after: effectiveAfter,
      includeAfter: true,
      before: beforeU,
    )) {
      out.add(_fromUtcWall(inst));
      if (out.length >= max) break;
    }
    return out;
  }

  /// 返回首个 ≥ [after] 的发生点(本地);无则 null。
  ///
  /// 今天页取「代表实例」、提醒滚动补点都用它。惰性求值,不展开整个无穷序列。
  DateTime? nextOccurrence({
    required String rule,
    required DateTime dtStart,
    required DateTime after,
  }) {
    final parsed = tryParse(rule);
    if (parsed == null) return null;
    final anchor = _toUtcWall(dtStart);
    final afterU = _toUtcWall(after);
    final effectiveAfter = afterU.isAfter(anchor) ? afterU : null;
    for (final inst in parsed.getInstances(
      start: anchor,
      after: effectiveAfter,
      includeAfter: true,
    )) {
      return _fromUtcWall(inst);
    }
    return null;
  }

  /// 把虚拟展开结果与已实体化 override 合并成最终发生点视图(升序)。
  ///
  /// 匹配键用确定性 override id([occurrenceId])——override 的主键本身就编码了它属于
  /// 哪个发生点,避开 DateTime 相等性陷阱。规则:
  /// - override 软删([Task.deletedAt] 非空)→ 跳过该发生点(等价 RFC5545 EXDATE);
  /// - 其它 override → 用实体替代(展示在 override 的 dueAt,允许「挪到别的时间」);
  /// - 无 override → 纯虚影。
  List<OccurrenceView> mergeOverrides({
    required String templateId,
    required List<DateTime> virtualDates,
    required List<Task> overrides,
  }) {
    final byId = {for (final o in overrides) o.id: o};
    final out = <OccurrenceView>[];
    for (final date in virtualDates) {
      final o = byId[occurrenceId(templateId, date)];
      if (o == null) {
        out.add(OccurrenceView(date: date));
      } else if (o.deletedAt != null) {
        continue; // EXDATE:这一次被删
      } else {
        out.add(OccurrenceView(date: o.dueAt ?? date, materialized: o));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// 本地时刻 → 同组件的 UTC「墙钟」,喂给 rrule(它强制 UTC)。
  static DateTime _toUtcWall(DateTime local) => DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
  );

  /// UTC「墙钟」→ 同组件的本地时刻,展开结果搬回本地语义。
  static DateTime _fromUtcWall(DateTime utc) =>
      DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute, utc.second);
}

@Riverpod(keepAlive: true)
RecurrenceService recurrenceService(Ref ref) => const RecurrenceService();
