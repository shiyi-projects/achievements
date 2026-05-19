import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 生成 UUIDv7(时间有序),用于本地与服务端共享的主键。
///
/// 选 v7 是为了:
/// 1. 客户端可生成,避免与服务端协调;
/// 2. 时间有序,B-tree 索引更友好,排序无需额外字段。
String newId() => _uuid.v7();
