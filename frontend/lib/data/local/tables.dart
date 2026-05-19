import 'package:drift/drift.dart';

/// 所有可同步实体的通用列定义,通过 mixin 复用。
///
/// 字段含义见 [`dev_docs/plan.md`](../../../../dev_docs/plan.md) §4 数据模型。
/// Phase 1 仅本地使用 `version` / `deletedAt` / `updatedAt`,Phase 2 接入同步
/// 引擎时直接复用,无需迁移。
mixin SyncableMixin on Table {
  /// 客户端生成的 UUIDv7,字符串存储。
  TextColumn get id => text()();

  /// Phase 0/1 固定为 LOCAL_USER_ID;启用真实账号后写入用户主键。
  TextColumn get userId => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 软删时间戳。同步引擎据此向其他端广播删除。
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// LWW 冲突解决用,服务端每次写入自增。
  IntColumn get version => integer().withDefault(const Constant(1))();
}

class Folders extends Table with SyncableMixin {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 清单。`isSystem = true` 表示内置(Today / Important / Planned 等),
/// 不可删除,[systemKind] 标识具体类别。
class TaskLists extends Table with SyncableMixin {
  TextColumn get folderId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get systemKind => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Tasks extends Table with SyncableMixin {
  TextColumn get listId => text()();

  /// 自引用支持子任务无限嵌套。
  TextColumn get parentId => text().nullable()();

  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get notes => text().nullable()();

  /// 0=none, 1=low, 2=medium, 3=high
  IntColumn get priority => integer().withDefault(const Constant(0))();

  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get remindAt => dateTime().nullable()();
  TextColumn get repeatRule => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Tags extends Table with SyncableMixin {
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get color => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 任务 ↔ 标签多对多关联表。无同步元数据,变更跟随 Task / Tag 自身。
class TaskTags extends Table {
  TextColumn get taskId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column<Object>> get primaryKey => {taskId, tagId};
}
