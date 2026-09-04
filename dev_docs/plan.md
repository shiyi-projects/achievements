# Todo 应用功能规划文档

## Context

依据 `dev_docs/prd.md`,需要构建一个跨端 Todo 应用,覆盖任务管理、日历、专注、成就、统计、提醒、搜索、设置等模块,并具备多端同步、离线优先、丰富动效的能力。

目前 `D:\SoftwareData\Flutter\Achievements` 仅有 `dev_docs/prd.md`,无任何代码,属于从 0 起步的项目。本规划用于建立技术栈选型、仓库结构、模块划分、数据模型、API 契约、分阶段实施路线,使后续开发可以按规划逐步推进而不需要反复返工。

**已确认的关键决策**(来自本轮对齐):

| 决策项 | 选择 |
|---|---|
| 后端框架 | **FastAPI**(Python) |
| 前端框架 | **Flutter** |
| 目标平台 | **Windows + Android** |
| 存储架构 | **Local-first**(本地 SQLite 全量存储 + 增量云同步) |
| 实施节奏 | **分阶段**(MVP → P1 → P2 → P3) |
| 账号体系 | **暂不做 / 仅占位**(本地单用户跑通,预留接口与表结构,后续再启用) |
| 生产部署 | **Docker**(docker-compose 编排 FastAPI + Postgres + Redis) |
| 图片附件存储 | **本地磁盘**(后端 `./storage/attachments`),**后续切换 OSS** |

---

## 1. 技术栈

### 1.1 前端 (Flutter)

| 维度 | 选型 | 说明 |
|---|---|---|
| Flutter SDK | 3.22+(Dart 3.4+) | 支持 Records / Patterns,Material 3 |
| 状态管理 | **Riverpod 2.x** | 编译期安全、跨页面共享、易测试,优于 Provider/GetX |
| 路由 | **go_router** | 声明式,支持深链/Web URL/桌面快捷键导航 |
| 本地数据库 | **Drift (SQLite)** | 类型安全 SQL,跨 Windows/Android,迁移成熟 |
| 网络 | **dio** + **retrofit** | 拦截器、重试、生成式 API 客户端 |
| 序列化 | **freezed** + **json_serializable** | 不可变模型 + 自动 fromJson |
| 本地通知 | **flutter_local_notifications** | Android 通道、Windows toast |
| 后台任务 | **workmanager**(Android)+ Windows 本地定时器 | 提醒兜底、同步队列 |
| 图表 | **fl_chart** | 热力图、趋势图、专注柱状图 |
| 拖拽 | **flutter_reorderable_list** / 内置 ReorderableListView | 任务/侧边栏/日历拖拽 |
| 国际化 | **flutter_intl + arb** | 中英文 |
| 桌面增强 | **window_manager**、**tray_manager**、**hotkey_manager** | 系统托盘、全局快捷键、窗口置顶(Windows) |
| 动效 | **flutter_animate** + 内置 Hero/Implicit | 统一动画 DSL |

### 1.2 后端 (Python / FastAPI)

| 维度 | 选型 | 说明 |
|---|---|---|
| 运行时 | Python 3.12 | |
| Web 框架 | **FastAPI** + Uvicorn(prod 用 Gunicorn+UvicornWorker) | |
| ORM | **SQLAlchemy 2.0 (async)** + **Alembic** | 异步、迁移 |
| 数据库 | **PostgreSQL 16** | 生产;开发可降级 SQLite |
| 缓存 | **Redis** | 同步增量游标、限流、提醒队列 |
| 校验 | Pydantic v2 | |
| 认证 | **占位**(MVP 期固定 `local-user` 单用户;预留 JWT 接口与中间件骨架,后续启用 Argon2 + JWT) | |
| 实时同步 | **HTTP 轮询**（定时 pull + push） | 增量同步,已放弃 WebSocket |
| 任务队列 | **APScheduler**(MVP 阶段足够,后期可换 Celery) | 提醒触发、统计聚合 |
| 文件存储 | **本地磁盘**(`./storage/attachments/{user_id}/{yyyy}/{mm}/`),抽象 `StorageBackend` 接口,后续切 OSS 仅替换实现 | 任务图片附件 |
| 测试 | pytest + httpx.AsyncClient + pytest-asyncio | |
| 工程 | uv / poetry、ruff、mypy(严格) | |

---

## 2. 仓库结构

采用单仓多包(monorepo)布局,前后端独立但共享 API 契约。

```
Achievements/
├── dev_docs/
│   ├── prd.md
│   └── plan.md                         # 本规划的可分享副本(可选)
├── backend/                            # FastAPI 服务
│   ├── pyproject.toml
│   ├── Dockerfile
│   ├── docker-compose.yml              # FastAPI + Postgres + Redis
│   ├── docker-compose.prod.yml         # 生产 override(端口/Volume/HTTPS 反代)
│   ├── .env.example
│   ├── alembic.ini
│   ├── alembic/versions/
│   ├── storage/                        # 本地附件存储(挂 docker volume)
│   ├── app/
│   │   ├── main.py                     # FastAPI 入口
│   │   ├── core/                       # 配置、安全(占位)、日志、依赖注入
│   │   ├── db/                         # 引擎、Session、基类
│   │   ├── models/                     # SQLAlchemy ORM
│   │   ├── schemas/                    # Pydantic DTO
│   │   ├── api/v1/                     # 路由(auth占位/tasks/lists/sync/...)
│   │   ├── services/                   # 业务逻辑层
│   │   ├── storage/                    # StorageBackend 抽象 + LocalDisk 实现(OSS 实现后续追加)
│   │   ├── sync/                       # 同步引擎(增量游标、冲突解决)

│   │   └── workers/                    # APScheduler 任务
│   └── tests/
├── frontend/                           # Flutter 应用
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app/                        # 主题、路由、本地化、根 Widget
│   │   ├── core/                       # 工具、常量、异常、日志
│   │   ├── data/
│   │   │   ├── local/                  # Drift 表、DAO、迁移
│   │   │   ├── remote/                 # dio + retrofit API
│   │   │   ├── repositories/           # 仓储模式,封装本地+远程
│   │   │   └── sync/                   # 同步引擎(出队、拉取、合并)
│   │   ├── domain/                     # 实体、用例
│   │   ├── features/                   # 按业务模块切分
│   │   │   ├── today/
│   │   │   ├── sidebar/
│   │   │   ├── task/
│   │   │   ├── task_detail/
│   │   │   ├── reminder/
│   │   │   ├── calendar/
│   │   │   ├── focus/
│   │   │   ├── achievement/
│   │   │   ├── statistics/
│   │   │   ├── search/
│   │   │   ├── settings/
│   │   │   └── empty_state/
│   │   ├── shared/                     # 通用 widget、动效、Toast、空状态组件
│   │   └── platform/
│   │       ├── android/                # 通知通道、震动、分享
│   │       └── windows/                # 托盘、全局快捷键、Command Palette
│   └── test/
├── shared/                             # 跨端契约
│   └── openapi.yaml                    # 由 FastAPI 导出,前端生成客户端
└── README.md
```

---

## 3. 系统架构

### 3.1 Local-first 数据流

```
┌─────────────────────────┐                ┌─────────────────────────┐
│  Flutter UI (Riverpod)  │                │  Flutter UI (其他设备)   │
└──────────┬──────────────┘                └────────────┬────────────┘
           │ 读/写 (始终走本地)                          │
┌──────────▼──────────────┐                ┌────────────▼────────────┐
│ Repository              │                │ Repository              │
│  ├ Drift (本地 SQLite)   │                │  ├ Drift                │
│  └ Outbox 变更队列        │                │  └ Outbox               │
└──────────┬──────────────┘                └────────────┬────────────┘
           │ 增量同步 (HTTP 轮询)                       │
           └────────────┬─────────────────────────┬─────┘
                        ▼                         ▼
              ┌─────────────────────────────────────────┐
              │  FastAPI                                 │
              │  ├ /sync/pull  (since=<cursor>)          │
              │  ├ /sync/push  (mutations[])             │
              │  └ Postgres + Redis                      │
              └─────────────────────────────────────────┘
```

**核心原则**:
- UI **永远只读写本地 Drift**,保证离线即时响应。
- 所有写操作进入 **Outbox 表**(待同步队列),由同步引擎异步推送。
- 同步引擎维护 `lastPulledAt` 游标,定期 `pull` 拉取变更。
- 冲突解决采用 **LWW(Last-Write-Wins by `updated_at`)**,每条记录带 `version` 字段防丢失更新;附件等不可合并字段服务端为准。
- 离线状态通过本地网络连通性 + 同步队列长度计算,对应 PRD「离线状态提示」与「多端同步状态显示」。

### 3.2 模块到 PRD 章节映射

| PRD 章节 | Flutter 模块 | 后端接口/服务 |
|---|---|---|
| 1 全局 | `app/`、`shared/` | `/auth/*`、`/sync/*` |
| 2 Today | `features/today` | `/tasks?scope=today` |
| 3 Sidebar | `features/sidebar` | `/sync`(清单树) |
| 4 任务 | `features/task` | `/tasks`、`/tasks/{id}/subtasks` |
| 6 详情 | `features/task_detail` | `/tasks/{id}`、`/tasks/{id}/activities` |
| 7 提醒 | `features/reminder` + `platform/*` | `/reminders`、APScheduler 推送 |
| 8 日历 | `features/calendar` | `/tasks?range=` |
| 9 专注 | `features/focus` | `/focus-sessions` |
| 10 成就 | `features/achievement` | `/achievements`、`services/achievement_evaluator` |
| 11 统计 | `features/statistics` | `/stats/*`(预聚合) |
| 13 搜索 | `features/search` | `/search?q=`(后期接 Postgres FTS) |
| 15 设置 | `features/settings` | `/settings`、`/import`、`/export` |
| 16 动效 | `shared/animations` | — |
| 17 桌面增强 | `platform/windows` | — |
| 18 移动增强 | `platform/android` | — |
| 20 空状态 | `features/empty_state` | — |

---

## 4. 数据模型(后端权威 Schema)

主键统一用 **UUIDv7**(时间有序、客户端可生成,免协调)。所有可同步表带 `updated_at`、`deleted_at`(软删)、`version`、`user_id`。

| 表 | 关键字段 | 说明 |
|---|---|---|
| `users` | id, email, password_hash, display_name, created_at | 账户体系 |
| `devices` | id, user_id, name, platform, last_sync_at | 多端登录追踪 |
| `task_lists` | id, user_id, parent_id?, name, color, icon, sort_order, is_system, system_kind?, trashed_with? | 清单树(自引用,任何一级都能装任务与子清单;含内置 Today/Important/Planned 等虚拟清单)。详见 [list-tree.md](./list-tree.md) |
| `tasks` | id, user_id, list_id, parent_id?, title, notes, priority, due_at?, remind_at?, repeat_rule?, color?, sort_order, completed_at?, archived_at?, starred, trashed_with?, created_at, updated_at, deleted_at, version | 任务/子任务(自引用) |
| `tags` | id, user_id, name, color | 标签 |
| `task_tags` | task_id, tag_id | 多对多 |
| `attachments` | id, task_id, kind(image), url, size | 图片附件 |
| `reminders` | id, task_id, fire_at, repeat_rule?, snooze_until?, channel | 提醒计划 |
| `activities` | id, task_id, kind, payload(json), created_at | 任务活动记录 |
| `focus_sessions` | id, user_id, task_id?, started_at, ended_at, duration, mode(pomodoro/free), completed | 专注会话 |
| `achievements` | id, code, name, desc, icon, criteria(json) | 成就定义(种子数据) |
| `user_achievements` | user_id, achievement_id, unlocked_at | 解锁记录 |
| `settings` | user_id, key, value(json) | 个人设置 |
| `sync_cursors` | device_id, cursor | 同步游标 |

**前端 Drift 表**:结构镜像后端,额外维护 `outbox(id, entity, op, payload, retry_count, created_at)`。

---

## 5. API 契约(主干)

全部 `/api/v1` 前缀,JWT Bearer。

```
POST   /auth/register
POST   /auth/login
POST   /auth/refresh
POST   /auth/logout

GET    /sync/pull?since=<cursor>          → { tasks[], lists[], tags[], task_tags[], cursor }
POST   /sync/push                          ← { mutations: [{entity, op, payload, version}] }
       两者都要求 X-Client-Version 头,低于门槛回 426(见 list-tree.md §5)

CRUD   /tasks, /tasks/{id}, /tasks/{id}/subtasks, /tasks/{id}/complete
CRUD   /tags
       清单没有 REST 端点:local-first,读写一律走 /sync
CRUD   /reminders
POST   /attachments (multipart)
GET    /search?q=&filters=

GET    /stats/overview, /stats/heatmap, /stats/focus, /stats/trends
CRUD   /focus-sessions

GET    /achievements, /achievements/me
GET    /settings, PUT /settings/{key}
POST   /export, POST /import
```

由 FastAPI 自动导出 `openapi.yaml` 到 `shared/`,Flutter 端用 `openapi-generator` 或手写 retrofit 客户端。

---

## 6. 分阶段路线图

### Phase 0 — 工程基线 (0.5 周)

- 初始化 `backend/`(`fastapi`、`uvicorn`、`sqlalchemy[asyncio]`、`alembic`、`pydantic-settings`)与 `frontend/`(`flutter create`,启用 Windows + Android)。
- 配置 `ruff`、`mypy`、`pytest`;Flutter 端 `analysis_options.yaml`(very_good_analysis)。
- **Docker 化**:`backend/Dockerfile`(多阶段 + 非 root 用户)+ `docker-compose.yml`(FastAPI / Postgres / Redis / storage volume)。`docker compose up` 一键起开发环境;生产用 `docker-compose.prod.yml` override 端口与持久化卷。
- Riverpod、go_router、Drift、dio、freezed 接入;空 App 跑通首页占位。
- 主题骨架(Material 3 + 浅深色 + 动态主题切换),实现 PRD 1.动态主题切换、响应式布局(LayoutBuilder + breakpoints)、Toast。
- **账号占位**:后端注入固定 `local-user` 作为 `current_user` 依赖;Auth 路由保留空实现返回 501,前端不做登录页,直接进主界面。

### Phase 1 — MVP 核心 (2.5 周)

**目标:单机本地可用的 Todo,无云同步**。

后端:
- Tasks/Lists/Folders/Tags 的 CRUD,Pydantic schema + service + router(均默认 `user_id = local-user`)。
- Alembic 初版迁移(`users` 表预建但仅有占位行)。
- Auth 路由保留占位(返回 501),路由签名保持稳定,后续直接补实现。

前端:
- 本地 Drift 表 + DAO + Repository。
- **Sidebar**(3):内置项 + 自定义文件夹/清单 + 拖拽排序 + 数量徽标。
- **Today**(2):欢迎语、日期、统计、连续天数(由本地 `focus_sessions`/`tasks` 计算)、快速输入、列表、已完成折叠、下拉刷新、空状态。
- **任务核心**(4):创建/编辑/删除/完成/恢复/子任务嵌套/折叠/优先级/标签/截止时间/备注/收藏/拖拽排序/复制/移动/批量操作。
- **任务详情面板**(6):桌面侧栏 + 移动底部抽屉(根据 breakpoint 切换)。
- **空状态**(20)统一组件。

验收:Windows + Android 双端 APK 可装,所有 P0 任务操作无云端也能正常工作。

### Phase 2 — 提醒、日历、同步 (3 周)

后端:
- `/sync/pull` + `/sync/push` 增量协议、LWW 冲突解决、`updated_at`/`version` 字段。
- `/reminders` CRUD + APScheduler 触发 + 服务端推送通道。

前端:
- 同步引擎(Outbox、游标、定时 pull、网络变化触发)、登录态、设备注册。
- 多端同步状态指示器、离线提示(1)。
- **提醒系统**(7):本地通知通道、稍后提醒、重复规则、声音/震动、紧急模式、权限引导;Windows 用 toast + 兜底窗口,Android 用 `flutter_local_notifications` + AlarmManager。
- **日历**(8):月/周/时间轴视图,日期任务数量、预览、拖拽改期、快速创建。
- **重复规则**:任务模型加 `repeat_rule`(RRULE 子集),完成时生成下一实例。
- **图片附件**(4):前端本地缓存 + 上传队列;后端 `StorageBackend` 接口落 `LocalDiskStorage`,文件存到挂载卷 `./storage/attachments/...`,通过 `/attachments/{id}` 流式下发(带条件请求头)。

验收:两台设备登录同一账号,任意一端的增删改在 ≤2s 内出现在另一端;断网下操作离线可见,联网后自动同步成功。

### Phase 3 — 专注、成就、统计、搜索 (2.5 周)

后端:
- `/focus-sessions` CRUD。
- 成就评估器:基于事件(任务完成、连续天数、专注时长、清单完成)触发,写入 `user_achievements`,同步通过 WS 推送。
- 预聚合统计端点(`/stats/*`);搜索接 Postgres FTS(GIN 索引在 `title || notes || tags`)。

前端:
- **专注模式**(9):全屏、番茄钟、倒计时、暂停、动画、自动完成、统计。
- **成就系统**(10):成就中心、解锁动画、详情、时间记录、分享(Android 原生分享 / Windows 复制链接)。
- **统计页**(11):热力图、趋势、专注、分类、连续、完成率、时段、导出 CSV/JSON。
- **全局搜索**(13):本地优先模糊 + 远端 FTS 兜底,最近搜索历史。

### Phase 4 — 平台增强、动效、设置打磨 (1.5 周)

- **桌面端**(17):多栏布局、快捷键系统(`hotkey_manager`)、Command Palette(Cmd/Ctrl+K)、系统托盘、全局快捷创建、窗口置顶、多窗口、拖拽文件上传。
- **移动端**(18):Bottom Tab、左右滑手势、长按菜单、FAB、震动反馈、原生分享。
- **动效系统**(16)统一审计:页面切换(go_router pageBuilder)、任务完成(checkmark + fade)、列表过渡(AnimatedList)、拖拽、展开折叠、提醒弹窗、成就解锁、数字滚动(`AnimatedFlipCounter`)。
- **设置页**(15):主题/字体/提醒/通知/同步/语言(zh、en)/快捷键/导入导出/关于。

### Phase 5 — 加固与发布 (1 周)

- 自动化测试覆盖:后端 ≥70%,前端关键 Repository / 同步引擎 ≥60%。
- 性能:任务列表 10k 数据流畅滚动(Sliver + 懒加载);同步增量包大小压缩。
- 端到端验证清单(下节)。
- 打包:Windows MSIX、Android Release APK / AAB,签名脚本。
- **Docker 生产部署**:`docker-compose.prod.yml`(FastAPI + Postgres + Redis + Nginx 反代 + Let's Encrypt),Volume 持久化 Postgres data 与 `storage/`;部署脚本 `deploy.sh` 拉镜像 / 迁移 / 重启。
- **OSS 切换准备**:在 `app/storage/` 下新增 `S3Storage` 实现(boto3 / 阿里云 OSS SDK),通过环境变量 `STORAGE_BACKEND=local|oss` 切换;迁移工具脚本把已有本地附件批量回传 OSS。本阶段仅留接口与文档,实际启用按业务量再触发。

**总工期估算**:~11 周(单人全栈)。

---

## 7. 关键设计要点

### 7.1 同步引擎(Phase 2 重点)

- 写路径:UI → Repository → Drift 事务(主表 + Outbox)→ 立刻返回 → 后台 worker 出队 → `POST /sync/push` → 成功后删除 outbox 行,失败指数退避(最多 5 次)。
- 读路径:**仅启动拉一次** `GET /sync/pull?since=cursor`,合并到本地;不再周期/聚焦轮询。
- 冲突:本地 `version != server.version` 时,按 `updated_at` 较大者胜,落败方进入 `activities` 表留痕,以便后续查看。
- 删除:两态 —— `deleted_at`(回收站,可恢复)与 `purged_at`(永久删除墓碑,客户端 pull 到即物理删,服务端超保留期惰性 GC)。

> 同步引擎与同步 API 的权威细节(触发策略、删除两态、purge 墓碑、task_tag 同步、pull/push 契约)见 [`dev_docs/sync.md`](sync.md)。

### 7.2 提醒可靠性(Phase 2)

- 双通道:**本地调度**(主)+ **服务端推送**(兜底)。
- Android 12+ 精确闹钟权限引导。
- Windows 仅在应用运行或托盘常驻时生效,需在设置页提示「需保留托盘以接收离线提醒」。

### 7.3 成就评估(Phase 3)

- 后端事件溯源:任务完成、专注结束等动作发布事件 → 评估器查 criteria → 写入 `user_achievements`。
- 前端镜像评估器(供离线触发解锁动画),后续与服务端对账以服务端为准。

### 7.4 主题与动效

- `ThemeData` 用 Material 3 ColorScheme.fromSeed,设置页可改种子色,实现「动态主题切换」。
- 全局动画时长/曲线常量集中在 `shared/animations/motion_tokens.dart`,避免散落。

### 7.5 国际化与本地化

- Phase 4 启用 `flutter_intl`,支持 zh-CN / en;日期格式遵循区域(`intl` 包)。

---

## 8. 验证方案(端到端)

每个 Phase 完成后执行:

1. **后端**:`pytest -q` 全部通过;`uvicorn app.main:app` 启动后,`/docs` 可见,通过 `httpx` 脚本走完认证 + CRUD + sync。
2. **前端**:`flutter analyze` 无 error;`flutter test` 关键单测通过。
3. **跨端联调**:
   - Windows 桌面端 + Android 真机/模拟器同账号登录。
   - 在 Windows 新建任务 → Android 在 ≤2s 内可见。
   - Android 断网 → 修改任务 → 联网 → Windows 看到更新且 `version` 递增,无重复。
   - 设定提醒 → 关闭 App → 到点收到本地通知;联网后通过定时 pull 同步最新状态。
4. **离线场景**:断网启动 App,所有读操作正常;新建/编辑落入 outbox;联网恢复后队列清空。
5. **打包验证**:Windows 双击 MSIX 安装可运行;Android Release APK 安装后冷启动 < 2s。

---

## 9. 关键文件(开始实施时优先创建)

- `backend/app/main.py` — FastAPI 入口,挂载 v1 路由、CORS、异常处理。
- `backend/app/core/config.py` — 配置(pydantic-settings,读 .env)。
- `backend/app/db/session.py` — 异步引擎 + AsyncSession 工厂。
- `backend/app/models/base.py` — Declarative Base + 通用字段 mixin(UUID、时间戳、软删、version)。
- `backend/app/api/v1/__init__.py` — 路由聚合。
- `backend/alembic/env.py` — 异步迁移。
- `frontend/lib/main.dart`、`frontend/lib/app/app.dart` — Root + ProviderScope + MaterialApp.router。
- `frontend/lib/app/router.dart` — go_router 配置。
- `frontend/lib/app/theme.dart` — Material 3 主题。
- `frontend/lib/data/local/database.dart` — Drift 数据库定义。
- `frontend/lib/data/remote/api_client.dart` — dio + retrofit 入口。
- `frontend/lib/data/sync/sync_engine.dart` — 同步引擎(Phase 2)。

---

## 10. 未尽事项(实施期间需进一步确认)

下列项不阻塞起步,但实施到对应阶段前需要明确,届时再行决策:

1. **账号启用时机**:当业务需要多设备/多用户时,启用预留的 JWT + Argon2 实现;启用前所有数据归属 `local-user`,启用后需做一次数据迁移到真实账号。
2. **OSS 切换时机与供应商**:阿里云 OSS / 腾讯云 COS / S3 兼容?触发条件可定为「附件总量 > 5GB」或「需要 CDN 加速」。
3. **AI 能力**:PRD 未明确,默认不引入。
4. **统计「年度统计」与「时间段分析」**的具体维度需在 Phase 3 设计期细化。

