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

/// 同步 outbox。所有本地写操作在 Drift 事务里同时落业务表 + 一行 outbox,
/// SyncEngine 按 createdAt 顺序批量 POST /sync/push;applied / conflict 后删行,
/// rejected 增 retryCount + lastError 留作下次重试。
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// folder / list / task / tag / task_tag
  TextColumn get entity => text()();

  /// upsert / delete
  TextColumn get op => text()();

  /// 业务实体的 UUID 主键(关联表用 ``${taskId}:${tagId}`` 占位)。
  TextColumn get entityId => text()();

  /// 序列化后的 payload(JSON 字符串),客户端构造 mutation envelope 时 inline。
  TextColumn get payload => text()();

  /// 客户端入队时认为的服务端 version。服务端比对后:相等才 apply,
  /// 否则 conflict 回 server_value。
  IntColumn get baseVersion => integer().withDefault(const Constant(0))();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 同步游标键值表。已知 key:`last_pulled_at`(ISO datetime,服务端回的
/// SyncPullResponse.cursor)。
class SyncCursors extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 专注会话记录。Phase 3 本地优先,暂不进入 outbox(后续随 /focus-sessions 端点启用)。
class FocusSessions extends Table {
  /// 客户端生成的 UUIDv7。
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// 关联的任务(可选)。
  TextColumn get taskId => text().nullable()();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 实际专注时长(秒)。结束时写入。
  IntColumn get durationSeconds => integer().nullable()();

  /// pomodoro / free
  TextColumn get mode => text().withDefault(const Constant('pomodoro'))();

  /// 是否完整完成(非中途放弃)。
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
