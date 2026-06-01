# 同步引擎与同步 API 对接文档

> 本文是同步的**权威文档**:涵盖客户端同步引擎设计与 `/sync/*` 接口契约,供前后端对接。
> 概览见 [`plan.md`](plan.md) §7.1,本文为细化与更新。

## 1. 总体模型

- **Local-first**:本地 Drift(SQLite)是全量数据源,UI 只读本地;写操作在 Drift 事务里同时落业务表 + 一行 `outbox`(暂存区,类似 `git add`)。
- **逐实体增量合并**:同步是按实体(folder / list / task / tag / task_tag)逐条的增量协议,**不是整库快照覆盖**。不同设备改不同实体不会互相覆盖;只有改同一条时才按 LWW 取新。
- **游标增量**:`pull` 用服务端 `updated_at` 游标 `since` 取 `(since, now]` 的变更;响应里的 `cursor` 是服务端「拉取这一刻」的 UTC now,客户端存下次回传。

## 2. 删除两态(关键)

每个可同步实体有两种「删除」状态,**语义不同,不可混用**:

| 状态 | 字段 | 含义 | 各端表现 |
|---|---|---|---|
| 回收站 | `deleted_at != null` 且 `purged_at == null` | 可恢复 | 所有端保留行,显示在回收站视图(`deletedAt 非空`) |
| 永久删除(墓碑) | `purged_at != null` | 不可恢复 | pull 到墓碑的端**物理删除本地行**;服务端保留墓碑至超过保留期,再由惰性 GC 物理清除 |

为什么要墓碑:`updated_at > since` 的增量协议**先天无法传播硬删** —— 一旦服务端物理删一行,它就从 delta 中消失,其它端永远收不到「这行没了」。所以永久删除先写 `purged_at` 墓碑随 delta 下发,各端据此本地物理删,墓碑到期后才真删。

- **保留期**:`PURGE_RETENTION = 30 天`(`backend/app/services/sync_service.py`)。须 ≥ 任意设备最长可能离线时长,否则离线设备回来拿不到墓碑(它仍持本地副本,无害)。
- **惰性 GC**:每次 `pull` 开头按当前用户物理删除 `purged_at` / `task_tag.deleted_at` 超过保留期的行(`_gc_purged`),无需独立调度器。

### 操作 → 状态映射(客户端)

| 用户操作 | 本地 | Outbox op |
|---|---|---|
| 移入回收站 | `deleted_at = now()` | `delete` |
| 从回收站恢复 | `deleted_at = null` | `upsert`(payload `{deleted_at: null}`) |
| 回收站「永久删除」 | 物理删本地行 | `purge` |

> ⚠️ 永久删除**必须**用 `purge` 而非 `delete`。`delete` 只软删,会被下次 pull 当增量重新落库,导致已永久删除的任务又出现在回收站(回收站视图正是 `deletedAt 非空`)。这是本次重构修复的核心 bug。

## 3. 冲突解决(LWW)

- 客户端 push 带 `base_version`;服务端 `version` 不匹配 → 返回 `conflict` + `server_value`。
- 客户端比较 `outbox.createdAt`(本地写入时戳)与 `server_value.updated_at`:
  - 本地新 → 把 outbox 的 `base_version` 升到 `server.version`,下一轮 push 重发。
  - 服务端新 → 用 `server_value` 覆盖本地(若 `server_value.purged_at` 非空则物理删本地),丢弃本地 mutation。
- **purge 是终态,不参与 LWW**:purge 遇 conflict 时,若服务端已是墓碑则完成,否则跟随服务端 version 重试,直到 `base_version` 对上后 apply,保证永久删除最终生效。

## 4. 同步 API 契约

鉴权:`Authorization: Bearer <token>`(`auth_enabled=false` 时回落到 `local_user_id`,开发/测试用)。

### GET `/api/v1/sync/pull?since=<ISO datetime>`

`since` 省略 = 首次全量拉取(新设备据此从云端拉全量)。响应:

```jsonc
{
  "cursor": "2026-06-01T12:00:00+00:00",   // 下次 pull 回传
  "folders": [FolderRead, ...],
  "lists":   [TaskListRead, ...],
  "tasks":   [TaskRead, ...],
  "tags":    [TagRead, ...],
  "task_tags": [TaskTagRead, ...]
}
```

- 返回行**包含**软删(`deleted_at != null`)与永久删除墓碑(`purged_at != null`);客户端据此分别置回收站态 / 物理删本地行。
- 四个主实体 `*Read` 均含 `deleted_at`、`purged_at`、`version`、`updated_at`。
- `TaskTagRead`:`{ task_id, tag_id, created_at, updated_at, deleted_at }`,`deleted_at` 非空表示该关联已被移除(删除墓碑)。

### POST `/api/v1/sync/push`

```jsonc
{ "device_id": "<uuid?>", "mutations": [ Mutation, ... ] }
```

Mutation 信封:

```jsonc
{
  "entity": "folder|list|task|tag|task_tag",
  "op":     "upsert|delete|purge",
  "id":     "<uuid>",          // 主实体主键;task_tag 是复合键,此处用 task_id 占位,真正主键在 payload
  "base_version": 1,           // 客户端认为的服务端 version(task_tag 不参与,传 0)
  "payload": { ...部分字段... } // 仅含被修改的列;purge 通常为空 {}
}
```

- `op` 语义:`upsert` 创建/更新;`delete` 软删(写 `deleted_at`);`purge` 永久删除(写 `purged_at` 墓碑)。
- **task_tag** 特殊:复合键 `(task_id, tag_id)` 放在 `payload`;`upsert` 建立/恢复关联,`delete` 置 `deleted_at` 墓碑。归属校验失败(task/tag 不属于当前用户)→ `rejected`。

响应(`results` 与请求 `mutations` 顺序一一对应):

```jsonc
{
  "cursor": "...",
  "results": [
    { "entity": "...", "id": "...", "status": "applied|conflict|rejected",
      "version": 2, "server_value": { ... } }   // server_value 仅 conflict 时回填
  ]
}
```

- `applied`:已写入,`version` 为最新值。实体不存在时:`delete`/`purge` 幂等返回 `applied`(version=1)。
- `conflict`:`base_version` 与服务端不符,回 `server_value`(实体 Read schema 的 JSON)。
- `rejected`:payload 校验失败 / 不允许的实体 / 归属不符 / FK 违例(单条 savepoint 隔离,不影响同批其它 mutation)。

## 5. 客户端触发策略

类 git 的「有改动才推、不每次打开都同」(`SyncCoordinator`):

| 触发源 | 行为 |
|---|---|
| **启动**(bootstrap) | `runFullSync()`:pull → push,**拉取仅此一次** |
| **本地写入**(outbox 非空) | 500ms 防抖后 `push`;outbox 空则不发 |
| **网络恢复**(offline→online 边沿) | 只 `push` flush 未推送的本地改动,**不自动 pull** |
| **手动** | 下拉刷新 / 设置页「立即同步」→ `runFullSync()` |
| **失败重试** | pull/push 报 error/offline → 延时重试直到成功 |

**已移除**的自动触发:App 切回前台(resume)、窗口聚焦、30s 周期轮询。远端变更靠启动拉取或用户手动刷新获取。

## 6. 关键文件

- 后端:`app/services/sync_service.py`(pull/push/_gc_purged)、`app/models/base.py`(`SoftDeleteMixin` 含 `deleted_at`/`purged_at`)、`app/models/task_tag.py`、`app/schemas/sync.py` / `sync_payload.py`。
- 迁移:`alembic/versions/e3f1a2b4c5d6_add_purge_tombstone_and_task_tag_sync.py`。
- 前端:`lib/core/sync/sync_engine.dart`(落库/墓碑/冲突)、`lib/core/sync/sync_coordinator.dart`(触发)、`lib/data/repositories/{task,tag,outbox}_repository.dart`。

## 7. 已知限制

- 跨设备只在「启动 / 手动刷新」时拉取远端变更,App 开着期间不会自动看到其它设备的改动(按产品决策刻意如此)。
- 离线超过保留期(30 天)的设备回来后,可能持有已被服务端 GC 的墓碑对应的本地行(孤儿,可手动软删),不会自动清理。
- LWW 用本地时钟与服务端 `updated_at` 比较,存在时钟漂移风险(沿用既有实现,未变更)。
