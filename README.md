# Achievements

跨端 Todo 应用 — Flutter(Windows + Android)+ FastAPI(Python 3.13)+ PostgreSQL,Local-first + 增量云同步架构。

> 产品需求见 [`dev_docs/prd.md`](dev_docs/prd.md);技术规划与分阶段路线图见 [`dev_docs/plan.md`](dev_docs/plan.md)。

## 目录结构

```
.
├── backend/                  FastAPI 服务(uv 管理依赖)
├── frontend/                 Flutter 应用(Windows / Android)
├── dev_docs/                 PRD 与规划文档
├── .github/workflows/        CI(GitHub Actions)
└── .pre-commit-config.yaml   本地钩子(ruff / mypy / dart format / flutter analyze)
```

## 快速开始

### 后端(Docker,默认走宿主机 PG/Redis)

```powershell
cd backend
Copy-Item .env.example .env       # 编辑 DATABASE_URL 等
docker compose up --build         # 仅起 api,连本地已有 PG:5432 / Redis:6379
```

如机器上没有本地 PG/Redis,改用完整形态:

```powershell
docker compose --profile full up --build
```

启动后:
- API: http://localhost:8000
- OpenAPI: http://localhost:8000/docs
- 健康检查: http://localhost:8000/api/v1/healthz

### 后端(本地 uv,无 Docker)

```powershell
cd backend
uv sync
Copy-Item .env.example .env
uv run uvicorn app.main:app --reload
```

数据库迁移:

```powershell
uv run alembic revision --autogenerate -m "describe change"
uv run alembic upgrade head
```

### 前端

```powershell
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 生成 *.g.dart
flutter run -d windows                                     # 桌面端
flutter run -d <device>                                    # Android(flutter devices 查看)
```

## 开发规范

- **分支命名**:`feat/<topic>`、`fix/<topic>`、`chore/<topic>`、`refactor/<topic>`、`docs/<topic>`、`test/<topic>`,禁止直接提交 main
- **提交信息**:Conventional Commits;首行英文 ≤72 字符,空行后正文中文,说明 *为什么* 改、*改了什么*、*影响范围*
- **PR**:走 Review 后合并;hotfix 可放宽但需事后补 review
- **质量门禁**:
  - 后端 `ruff check` + `ruff format --check` + `mypy --strict` + `pytest`
  - 前端 `dart format --set-exit-if-changed` + `flutter analyze` + `flutter test`
  - 本地通过 `pre-commit install` 启用钩子兜底,CI 在 GitHub Actions 中强制

## uv 全局配置(开发机一次性)

为避免 uv cache 与项目 venv 跨盘符无法 hardlink,把 cache 与 Python 安装目录都放到与项目同盘:

```powershell
[Environment]::SetEnvironmentVariable("UV_CACHE_DIR", "D:\Software\developments\environments\uv\cache", "User")
[Environment]::SetEnvironmentVariable("UV_PYTHON_INSTALL_DIR", "D:\Software\developments\environments\uv\python", "User")
```

之后新 PowerShell 进程生效,`uv sync` 创建的 `.venv` 文件会 hardlink 到 cache,物理占用近 0。
