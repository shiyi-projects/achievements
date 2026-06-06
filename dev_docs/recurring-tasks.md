# 周期性重复任务设计文档

> 本文是「重复任务（recurring task）」功能的**权威设计文档**：涵盖数据模型、规则表达、
> 操作语义、提醒、同步与分阶段实施计划。相关：同步契约见 [`sync.md`](sync.md)，
> 路线图见 [`plan.md`](plan.md)。

## 0. 背景与现状

应用此前的排期是**一次性**的：任务只有 `due_at` / `remind_at`，到点提醒一次即止。
代码里其实早已埋了半套重复能力，但链路是断的：

| 层 | `repeat_rule` 现状（实施前） |
|---|---|
| 前端 Drift 表 `tasks` | ✅ 有字段 |
| 后端 ORM `Task` | ✅ 有字段 |
| sync payload `TaskPayload` | ✅ 带字段，能同步 |
| 后端 REST `TaskCreate/Update/Read` | ❌ 三个 schema 全缺，HTTP 读写不了 |
| 前端 `TaskRepository.update()` | ❌ 无 `repeatRule` 参数，改不了 |
| 前端 UI（创建/详情/快捷条） | ❌ 无任何入口 |
| 完成时「滚动生成下一实例」`_maybeCreateNextRepeat` | ⚠️ 逻辑在，但只支持 `DAILY/WEEKLY/MONTHLY/YEARLY` |

提醒机制本身完整且可复用：`flutter_local_notifications` + 双保险
（`ReminderScheduler` 后台系统通知 + `ReminderChecker` 前台轮询全屏闹钟），100% 本地驱动，
后端不参与提醒。

## 1. 核心设计决策

| 维度 | 选定方案 | 理由 |
|---|---|---|
| 规则表达 | **RFC5545 RRULE 子集** | 业界标准，能表达「每2周一三五」「每月最后一天共12次」；手搓易错，用成熟库 |
| 实例模型 | **模板 + 虚拟展开** | 日历能预览未来发生点而数据不膨胀；这是日历类 App 的经典做法 |
| 落库时机 | **按需实体化（materialize）** | 仅当用户对某发生点「动手」（完成/改时间/删单次）才落一条 override 记录 |
| 多端去重 | **override id 用确定性 UUIDv5** | 两端同时操作同一发生点会生成同一 id，同步层天然合并 |

### 1.1 三种记录形态

- **模板（series master）**：一条 `tasks` 记录，`repeat_rule != null`，`due_at` = 系列锚点
  （DTSTART，首次发生时间），`completed_at == null`。它代表整个系列。
- **虚拟实例（occurrence）**：**不落库**。由 `(模板, RRULE)` 在内存按规则算出。日历、今天页消费它。
- **override 实体**：用户操作某发生点时才落库的独立 `tasks` 记录，带
  `recurrence_parent_id`（指向模板）+ `occurrence_date`（原系列的哪个发生点）。
  展开时凡命中 override 的发生点就用它替代虚影（去重）。

## 2. 数据模型改造

`repeat_rule` 字段已存在，沿用。**新增两列**（前端 Drift + 后端 ORM + sync payload + REST schema 全链路）：

| 字段 | 类型 | 含义 |
|---|---|---|
| `recurrence_parent_id` | UUID / text，nullable | override 指回模板；模板自身与普通任务为 null |
| `occurrence_date` | datetime，nullable | 这条 override 对应系列里的哪个发生点（去重锚点，UTC 存储） |

### 2.1 RRULE 锚点与时区

- DTSTART 取模板的 `due_at`（无 `due_at` 的重复任务无意义，UI 强制要求设日期）。
- 展开在**本地时区**进行（用户语义上的「每天 9 点」是墙上时间）；存储统一 UTC。
- `repeat_rule` 只存 RRULE 的 `RRULE:` 行主体，例如 `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR`。
  DTSTART 不进 `repeat_rule`，由 `due_at` 提供，避免两处冗余。

### 2.2 确定性 override id

```
overrideId = UUIDv5(namespace = templateId-as-namespace, name = occurrence_date.toUtc().toIso8601String())
```

两台设备对同一模板的同一发生点操作 → 生成同一 UUID → 同步 LWW 自动合并，不会出现重复实体。

## 3. 操作语义（核心）

| 操作 | 行为 |
|---|---|
| **完成某次** | 实体化为 override（确定性 id），写 `completed_at`；该发生点从虚影变历史记录，系列继续 |
| **改这一次的时间/内容** | 实体化 override，写入新值；展开时该发生点用 override 显示 |
| **删这一次** | 实体化「墓碑 override」（`deleted_at` 置值），展开时跳过该发生点（等价 RFC5545 EXDATE） |
| **本次及以后修改/停止** | 给模板 RRULE 追加 `UNTIL=该发生点前一刻` 截断系列；需新规则则另起一条模板 *(留后做)* |
| **删整个系列** | 软删模板 + 其所有 override |

**MVP 收敛**：第一版实现「完成某次」「删这一次」「删整个系列」（覆盖约 95% 使用），
「本次及以后」留接缝后做。

### 3.1 列表页 vs 日历页的呈现

- **今天页 / 收集箱 / 自定义清单**：不展开全部未来。今天页取「≤今天的最早一个未完成发生点」
  作为模板的代表虚拟实例渲染（带 🔁 标记）；收集箱/自定义清单显示模板本身（带 🔁）。
- **日历页**：完整展开当前可见窗口内所有发生点（虚影），命中 override 的用实体替代。

## 4. 重复提醒

复用现有 `ReminderScheduler` / `ReminderChecker`，改动：

1. `ReminderScheduler._reconcile` 当前只监听真实记录流。扩展：对带 `repeat_rule` 的模板，
   虚拟展开未来窗口（默认 60 天）内每个发生点的 `remind_at`，逐个注册系统通知。
2. **notification id 改造**：现用 `task.hashCode` → 改为 `hash(templateId + occurrenceEpoch)`，
   每个发生点独立 id，避免模板内多发生点撞 id。
3. 滚动补充：窗口随时间推移，app 启动 + 每日触发时把新进入窗口的发生点补注册。
4. `flutter_local_notifications` 的 `matchDateTimeComponents` 只能表达简单日/周循环，撑不起
   RRULE，故走「虚拟展开 + 注册 N 个 one-shot」路线。

## 5. 同步

- 新增 `recurrence_parent_id` / `occurrence_date` 全链路打通（Drift / ORM / REST / payload / 迁移）。
- 模板和 override 都是普通 `tasks` 记录，走现有 LWW 增量同步，无需新协议。
- 虚拟实例不落库 → 不进同步，零负担。
- 确定性 override id（§2.2）解决「双端完成同一次」并发去重。

## 6. 数据库迁移

- **前端 Drift**：`schemaVersion 10 → 11`，`if (from < 11)` 两条
  `ALTER TABLE tasks ADD COLUMN recurrence_parent_id TEXT` /
  `ALTER TABLE tasks ADD COLUMN occurrence_date INTEGER`（Drift datetime 存 unix 秒）。
- **后端 Alembic**：新迁移 `down_revision = e3f1a2b4c5d6`，`add_column` 两列（带 index on
  `recurrence_parent_id`）。
- **REST schema**：`TaskCreate/Update/Read` 补 `repeat_rule` + 两个新字段（修复历史断点）。

## 7. 依赖

- **前端新增 `rrule`（pub.dev）**：RFC5545 标准实现，含展开器。选用理由：RRULE 方案下手搓
  展开（BYDAY/BYMONTHDAY/UNTIL/COUNT + 时区）极易出 bug。
- 确定性 id 复用已有 `uuid: ^4.5.1` 的 `v5`，无需新依赖。
- 后端**不加**依赖（只存串、做同步；展开/提醒全在前端）。

## 8. 分阶段实施计划

每阶段一条 feature 分支，独立可测、可提交、可回滚。

| 阶段 | 分支 | 内容 |
|---|---|---|
| **P0 地基** | `feat/recurrence-schema` | Drift v11 + Alembic 迁移 + REST/payload 补字段 + 确定性 id 工具 + 删旧滚动逻辑 |
| **P1 引擎** | `feat/recurrence-engine` | 引入 `rrule`；`RecurrenceService`（展开/实体化/完成/删除）；Repository 支持 `repeatRule` |
| **P2 设置 UI** | `feat/recurrence-ui` | 详情面板 + 快捷条加重复设置器（频率/间隔/周几/月第几天/结束）；🔁 标记 |
| **P3 日历呈现** | `feat/calendar-recurrence` | 日历消费虚拟实例 + planned/important 导航收敛 |
| **P4 重复提醒** | `feat/recurrence-reminders` | ReminderScheduler 虚拟展开调度 + notification id 改造 |
| **P5 体验收尾** | `feat/list-section-refactor` / `feat/nl-capture` | 列表分段抽组件 + important ⭐ 筛选 + 自然语言捕获 |

P0→P4 是重复功能主链；P5 是独立体验项。每阶段遵循 `dart format` + `flutter analyze` /
`ruff` + `mypy` 门禁，测试落 `frontend/test/`、`backend/tests/`。

### 8.1 顺带处理的冗余/交互改进（P3、P5）

- **planned/日历收敛**（落地既有决策）：sidebar 隐藏 `planned`/`important`；planned 并入日历；
  important 变列表内 ⭐ 筛选开关。与重复功能协同——日历成为统一「时间维度」入口。
- **列表分段重复代码**：Today/List/Trash 三处重复的「待完成+已完成」分段抽成统一组件。
- **自然语言捕获**：`RuleCaptureParser`（本地规则）解析「每周一9点交周报」→ `due_at`+`remind_at`+
  RRULE；`CaptureParser` 接口 + provider 留 AI 升级接缝；预览 chip 可撤销。

## 9. 实施落地记录

- **P0–P4**：核心重复功能全链路打通,前后端测试齐备。
- **P5**:
  - 「重要」从侧边栏收敛为**任意清单内的 ⭐ 仅星标筛选开关**(`listStarFilterProvider`)。
  - 自然语言捕获落地:`lib/core/capture/`,集成进底部 `QuickCreateInput`(预览 chip),
    覆盖 中文「每天/每周X/工作日/每N单位/相对日期/时间」。
  - 列表分段重构:抽出共享 `SwipeableTaskTile`,顺带**修复今天页此前用裸 TaskTile
    无滑动手势**的历史不一致(与清单页语义对齐:右滑完成、左滑删除)。
- **已知后续(留接缝,未做)**:
  - 操作语义「本次及以后修改/停止」(§3,UNTIL 截断 + 另起模板)。
  - 选择器尚不能编辑 BYMONTHDAY / 带序号 BYDAY(如「每月最后一天」「每月第二个周二」);
    存储/展开层已支持,`RecurrenceRuleDraft.fromRuleBody` 对这类规则回退为只读不丢数据。
  - 后端 RRULE 合法性校验(当前仅存字符串,展开/校验在客户端)。
