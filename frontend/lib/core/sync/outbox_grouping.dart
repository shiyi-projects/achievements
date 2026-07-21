import 'dart:convert';

import 'package:achievements/data/local/database.dart';

/// push 批内的一组 outbox 行,作为**一条** mutation 发送,响应回填到组内所有行。
///
/// 为什么要合并:outbox 的 baseVersion 在入队时读本地 version,而本地 version
/// 只在 push applied 后才更新。同一实体在两次 push 之间连改 N 次(debounce 窗口
/// 内快速操作 / 离线积累),N 条 mutation 会带着**相同的**陈旧 baseVersion 进同
/// 一批:第 1 条 applied 后服务端 version 已 bump,第 2 条起立即 conflict,而
/// LWW 拿「后续条的入队时刻」对比「第 1 条刚在服务端的应用时刻」——后者必然
/// 更晚,误判服务端赢,用户的后续操作被静默丢弃并回滚。合并后整组只有一条
/// mutation、一个 baseVersion,链式 conflict 不复存在。
class MutationGroup {
  MutationGroup(this.rows);

  final List<OutboxData> rows;

  OutboxData get _first => rows.first;

  String get entity => _first.entity;
  String get entityId => _first.entityId;
  String get op => _first.op;
  int get baseVersion => _first.baseVersion;

  /// LWW 冲突比较用的本地时戳:组内**最后**一次写入的时刻。
  DateTime get latestCreatedAt => rows.last.createdAt;

  /// 组内 payload 按入队顺序浅合并(后者覆盖前者)。payload 语义是「被修改
  /// 字段的集合」,合并结果即用户操作序列的最终意图。单行组等价于原 payload。
  Map<String, dynamic> mergedPayload() {
    final out = <String, dynamic>{};
    for (final row in rows) {
      out.addAll(jsonDecode(row.payload) as Map<String, dynamic>);
    }
    return out;
  }

  Map<String, dynamic> toMutation() {
    return {
      'entity': entity,
      'op': op,
      'id': entityId,
      'base_version': baseVersion,
      'payload': mergedPayload(),
    };
  }
}

/// 把 pending outbox 行(createdAt 升序)分组:
///
/// - 同一实体的 upsert 并入该实体当前开放的 upsert 组(允许被其他实体的行
///   打断——服务端本就按实体依赖重排,交错不影响语义)。
/// - delete / purge 自成一组,并**封闭**该实体的开放组:删除前后的 upsert
///   语义不同(如软删前的编辑 vs 恢复),不可跨删除合并。
/// - task_tag 永不合并:其 entityId 只是 task_id 占位,真正主键 (task_id,
///   tag_id) 在 payload 里,浅合并会把不同 tag 的关联揉成一条。
List<MutationGroup> groupPending(List<OutboxData> pending) {
  final groups = <MutationGroup>[];
  final open = <String, MutationGroup>{};
  for (final row in pending) {
    final key = '${row.entity}:${row.entityId}';
    if (row.entity != 'task_tag' && row.op == 'upsert') {
      final existing = open[key];
      if (existing != null) {
        existing.rows.add(row);
      } else {
        final group = MutationGroup([row]);
        groups.add(group);
        open[key] = group;
      }
    } else {
      open.remove(key);
      groups.add(MutationGroup([row]));
    }
  }
  return groups;
}
