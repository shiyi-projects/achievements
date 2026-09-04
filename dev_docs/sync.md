# 同步引擎与同步 API 对接文档

> 本文是同步的**权威文档**:涵盖客户端同步引擎设计与 `/sync/*` 接口契约,供前后端对接。
> 概览见 [`plan.md`](plan.md) §7.1,本文为细化与更新。

## 1. 总体模型

- **Local-first**:本地 Drift(SQLite)是全量数据源,UI 只读本地;写操作在 Drift 事务里同时落业务表 + 一行 `outbox`(暂存区,类似 `git add`)。
- **逐实体增量合并**:同步是按实体(folder / list / task / tag / task_tag)逐条的增量协议,**不是整库快照覆盖**。不同设备改不同实体不会互相覆盖;只有改同一条时才按 LWW 取新。
- **游标增量**:`pull` 用服务端 `updated_at` 游标 `since` 取 `(since, now]` 的变更;响应里的 `cursor` 是服务端「拉取这一刻」的 UTC now,客户端存下次回传。
- **重叠窗口**:服务端查询实际用 `since - SINCE_OVERLAP`(60s,`sync_service.py`)。push 里各行 `updated_at` 在逐条 flush 时生成、commit 在整批末尾,并发 pull 的 cursor 可能晚于这些 `updated_at` 却读不到未提交行;严格 `> since` 会永久漏掉它们。宁可重复下发(客户端落库幂等)也不丢。
- **脏实体保护**:客户端 pull 落库时跳过 outbox 中仍有 pending mutation 的实体(`'$entity:$id'` 键匹配),避免服务端旧值覆盖本地未推送的修改;两端差异交由 push 的 conflict/LWW 收敛。pull 到 purge 墓碑则**不跳过**:物理删本地行并清掉该实体残留的 outbox 行(实体已死,推了也没意义)。

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
| 回收站「永久删除」 | 物理删本地行(递归含全部后代子任务 + 标签关联行) | 自身与**每个后代**各一条 `purge` |

> purge 必须逐行发:服务端 GC 物理删父行时 FK CASCADE 带走的子行**不会留墓碑**,其他端收不到。task_tag 关联同理——task/tag 墓碑在各端落地时由客户端本地一并清关联行,不单独发 mutation。
>
> ⚠️ 重复系列 override 的「删某次」(EXDATE)**必须用 `upsert` 携带完整字段 + `deleted_at`**,不能用 `delete` + 空 payload:override 往往是「新建即软删」,服务端对不存在实体的 `delete` 是幂等 no-op,软删行永远不会被创建,跳过的发生点无法跨端传播(`task_repository._upsertOverride`)。

> ⚠️ 永久删除**必须**用 `purge` 而非 `delete`。`delete` 只软删,会被下次 pull 当增量重新落库,导致已永久删除的任务又出现在回收站(回收站视图正是 `deletedAt 非空`)。这是本次重构修复的核心 bug。

## 3. 冲突解决(LWW)

- 客户端 push 带 `base_version`;服务端 `version` 不匹配 → 返回 `conflict` + `server_value`。
- 客户端比较 `outbox.createdAt`(本地写入时戳)与 `server_value.updated_at`:
  - 本地新 → 把 outbox 的 `base_version` 升到 `server.version`,**在同一次 `pushOnce` 内重发**。
  - 服务端新 → 用 `server_value` 覆盖本地(若 `server_value.purged_at` 非空则物理删本地),丢弃本地 mutation。
- **delete / purge 是终态,不参与 LWW**:遇 conflict 时,若服务端已达成该终态(purge 看 `purged_at`,delete 看 `deleted_at` 或 `purged_at`)则收下服务端 version 并完成;否则跟随服务端 version 重试,直到 `base_version` 对上后 apply。删除是用户的显式意图,不该被「服务端 `updated_at` 更晚」吞掉。
- **applied 无条件回写 version**:服务端对 `delete` / `purge` 同样 bump version 并返回。回写只做 upsert 会让本地 version 永久落后一格,此后这一行的每次操作都带陈旧 `base_version`、必然冲突并被 LWW 赌时间戳(典型症状:回收站恢复被静默丢弃)。purge 时本地行已物理删除,该 UPDATE 影响 0 行,无害。
- **重发必须在本次调用内完成**:「跟随服务端 version 重试」只改 outbox 行的 `baseVersion`、不改行数,`watchPendingCount` 不保证再次触发 push。`pushOnce` 因此内循环最多 `_maxPushRounds`(3)轮,只要上一轮有行被安排重发就继续。

### 批内因果链(服务端)

客户端本地行的 `version` 只在收到 `applied` 后才回写,所以**同一实体在一批里的第 2 条起必然带着陈旧的 `base_version`**(离线期间「改标题 → 删除」「编辑 → 永久删除」)。这不是并发冲突,是同一客户端同一批请求内的因果顺序。

服务端 `push()` 用 `applied_in_batch` 集合记住本批已成功应用过的实体,对其后继 mutation **跳过 `base_version` 检查、直接按序接续**;跨批次的真并发(另一台设备的写)不在集合中,仍照常判 conflict。`indexed.sort` 是稳定排序,同一实体内部保持客户端入队顺序 —— 接续依赖这一点。`task_tag` 不参与(无 version、不做乐观并发,且 `Mutation.id` 只是占位)。

> 不修的话:第 1 条 applied 把服务端 `updated_at` 刷新到「刚刚」,第 2 条 conflict 后客户端拿「本地入队时刻」去比,**服务端恒胜**,用户的删除被静默丢弃且无任何提示。`outbox_grouping` 的 upsert 合并只覆盖了连续 upsert 这一种情形,delete 打断合并后仍会中招。

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
      "version": 2, "server_value": { ... }, "reason": "validation" }
  ]
}
```

- `applied`:已写入,`version` 为最新值。实体不存在时:`delete`/`purge` 幂等返回 `applied`(version=1)。
- `conflict`:`base_version` 与服务端不符,回 `server_value`(实体 Read schema 的 JSON)。
- `rejected`:回 `reason` 说明原因。单条 savepoint 隔离,不影响同批其它 mutation。

`server_value` 在 `conflict` 与 `reason="purged"` 时回填。`reason` 仅 `rejected` 时非空:

| reason | 含义 | 客户端处置 |
|---|---|---|
| `validation` | payload 校验失败 / 建行缺必填字段 | 永久错误,消耗重试预算 |
| `ownership` | 实体不属于当前用户 | 永久错误,消耗重试预算 |
| `unknown` | 不认识的 entity | 永久错误,消耗重试预算 |
| `dependency` | 外键依赖未满足(父实体还没推上去) | 暂时错误,下一轮可能自愈 |
| `purged` | 目标已是永久删除墓碑 | **物理删本地行 + 清该实体 outbox** |

**墓碑不可复活**:`upsert` 打在 `purged_at` 非空的行上一律 `rejected` + `reason="purged"`。否则编辑会写进墓碑行,而墓碑随 delta 下发时各端(含发起端)都会物理删本地行 —— 用户刚编辑过的任务凭空消失。`delete`/`purge` 打在墓碑上是幂等的,放行。

**批内父子依赖排序**:tasks 之间有 `parent_id`(子任务)与 `recurrence_parent_id`(重复 override)两条自引用外键。服务端在 entity 类型排序之后,对 task 分片再做一次拓扑排序(`_sort_tasks_by_dependency`),把引用了本批另一条 task 的 mutation 排到被引用者之后;同一实体多条 mutation 的相对顺序保持不变(批内因果链接续依赖它)。顺序错了会 FK 违例被 rejected,重试耗尽即成死信,那条任务及其整棵子树再也上不了云。

## 5. 客户端触发策略

类 git 的「有改动才推、不每次打开都同」(`SyncCoordinator`):

| 触发源 | 行为 |
|---|---|
| **启动**(bootstrap) | `runFullSync()`:pull → push,**拉取仅此一次** |
| **本地写入**(outbox 非空) | 500ms 防抖后 `push`;outbox 空则不发 |
| **网络恢复**(offline→online 边沿) | 只 `push` flush 未推送的本地改动,**不自动 pull** |
| **手动** | 下拉刷新 / 设置页「立即同步」→ `runFullSync()` |
| **失败重试** | pull/push 报 error/offline → 30s 后重试直到成功 |

**push 批内合并**:同一实体的多条 upsert 在发送前合并为**一条** mutation(payload 按入队序浅合并,baseVersion 取首条,LWW 时戳取末条;delete/purge 打断合并,task_tag 永不合并,见 `lib/core/sync/outbox_grouping.dart`)。否则同批第 2 条起 baseVersion 必然陈旧 → 伪 conflict → LWW 拿「入队时刻」对比「前一条刚在服务端的应用时刻」必输 → 用户在 debounce 窗口内的连续操作被静默回滚。

**outbox retry 语义**:网络断 / 5xx 等**暂时性**错误只记 `last_error`,**不消耗 retry 预算**(否则离线几轮 30s 重试就把 pending 行推进死信,恢复网络后本地改动永远不上云);只有服务端明确 `rejected` 才 `retry_count + 1`,达到 `OutboxRepository.retryLimit`(20)后成为死信不再重发。

预算取 20 而非早先的 5:服务端已能区分永久错误与暂时错误,而 `dependency` 类错误需要跨若干轮才自愈,预算太小会把本可成功的 mutation 过早推进死信。

**死信不冻结实体**:`pendingEntityKeys()`(pull 的脏实体跳过集)**只统计 `retry_count < retryLimit` 的行**。死信行已经不会再被推送,若仍算作脏,该实体就既推不上去、也永远拒绝服务端下发,在这台设备上彻底冻结。让服务端的值盖回去,至少能回到与云端一致的状态。

**死信有出口**:设置页「同步」组在死信数 >0 时显示「N 条本地改动没能同步」,可查看明细(实体 / 操作 / 最后一次错误)并**全部重试**(`retry_count` 清零)或**全部丢弃**(删 outbox 行,本地那几行由下次 pull 用云端值覆盖)。没有这个出口,这些改动只会静默留在本地,用户永远不知道有东西没上云。

**pull 游标不越过被跳过的行**:`_applyPullResponse` 返回被跳过行里最早的 `updated_at`,`pullOnce` 据此写游标(没有跳过则用响应的 `cursor`)。否则一旦那条 outbox 行后来是被丢弃而非推送成功的,服务端那次更新就永远不会再下发。重复下发由 `SINCE_OVERLAP` 与客户端幂等落库兜住。

**存量自愈**:`SyncCursorKey.repairV1` 标记的一次性修复(`bootstrap_provider.dart`),在首次同步门之前跑。清零死信的 `retry_count`(让新的原因分类重新判定)、删掉 `last_pulled_at` 强制一次全量 pull(让服务端的权威 version 覆盖旧版遗留的落后 version)。这两种坏状态不会因为代码修好就自愈。

**已移除**的自动触发:App 切回前台(resume)、窗口聚焦、30s 周期轮询。远端变更靠启动拉取或用户手动刷新获取。

## 6. 关键文件

- 后端:`app/services/sync_service.py`(pull/push/_gc_purged)、`app/models/base.py`(`SoftDeleteMixin` 含 `deleted_at`/`purged_at`)、`app/models/task_tag.py`、`app/schemas/sync.py` / `sync_payload.py`。
- 迁移:`alembic/versions/e3f1a2b4c5d6_add_purge_tombstone_and_task_tag_sync.py`。
- 前端:`lib/core/sync/sync_engine.dart`(落库/墓碑/冲突)、`lib/core/sync/sync_coordinator.dart`(触发)、`lib/data/repositories/{task,tag,outbox}_repository.dart`。

## 7. 同步字段范围

Task 的 `recurrence_parent_id` / `occurrence_date` / `estimated_minutes` **参与同步**(pull 落库与 push payload 都含);`focused_seconds` 与 `FocusPlans` / `TaskSteps` / `FocusSessions` 表**仅本地**,不进 outbox。

## 8. 已知限制

- 跨设备只在「启动 / 手动刷新」时拉取远端变更,App 开着期间不会自动看到其它设备的改动(按产品决策刻意如此)。
- 离线超过保留期(30 天)的设备回来后,可能持有已被服务端 GC 的墓碑对应的本地行(孤儿,可手动软删),不会自动清理。
- LWW 用本地时钟与服务端 `updated_at` 比较,存在时钟漂移风险(沿用既有实现,未变更)。
- `dependency` 类 rejected 同样消耗重试预算(只是预算放宽到 20)。父实体被永久删除等「不会自愈的依赖失败」最终仍会进死信,由设置页出口兜底,而不是无限空转。
- delete / purge 的「跟随服务端 version 重试」无独立次数上限(与既有 purge 行为一致),仅受 `pushOnce` 的 3 轮内循环与协调器 30s 重试节流约束。
- pull 游标被压回时,若某实体长期是脏的,游标会反复停在同一处、每轮重拉同一段增量。死信不再计入脏集合后这一状态是短暂的,但极端情况下仍会多传。
- `focused_seconds` 不参与同步(服务端无此列),多设备间专注时长各算各的。
- 手动「立即同步」在已有同步进行中时被合并(不排队),极端情况下点了没反应。
