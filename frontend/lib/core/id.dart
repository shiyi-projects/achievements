import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 生成 UUIDv7(时间有序),用于本地与服务端共享的主键。
///
/// 选 v7 是为了:
/// 1. 客户端可生成,避免与服务端协调;
/// 2. 时间有序,B-tree 索引更友好,排序无需额外字段。
String newId() => _uuid.v7();

/// 为重复系列某个发生点生成**确定性**的 override id。
///
/// 同一 (模板 id, 发生点时刻) 在任意设备上都派生出同一 UUID,使得多端同时
/// 操作同一发生点时只会产生一条实体(同步层 LWW 自动合并),不会出现重复。
/// 用 UUIDv5(SHA-1 命名空间散列),namespace 取模板 id,name 取发生点 UTC ISO 串。
/// 详见 dev_docs/recurring-tasks.md §2.2。
String occurrenceId(String templateId, DateTime occurrence) {
  return _uuid.v5(templateId, occurrence.toUtc().toIso8601String());
}
