# Achievements

跨端 Todo 应用 — Flutter(Windows + Android) + FastAPI(Python)+ PostgreSQL,采用 Local-first + 增量云同步架构。

> 详细产品需求见 [`dev_docs/prd.md`](dev_docs/prd.md);技术规划与分阶段路线图见 [`dev_docs/plan.md`](dev_docs/plan.md)。

## 目录结构

```
.
├── backend/        FastAPI 服务(Python 3.13 + uv 管理)
├── frontend/       Flutter 应用(Windows / Android)
├── dev_docs/       PRD 与规划文档
└── shared/         共享契约(OpenAPI 等,Phase 2 启用)
```

## 快速开始

### 后端开发(Docker)

```powershell
cd backend
Copy-Item .env.example .env
docker compose up --build
```

启动后访问:
- API: http://localhost:8000
- OpenAPI 文档: http://localhost:8000/docs
- 健康检查: http://localhost:8000/healthz

### 后端开发(本地 uv,无 Docker)

```powershell
cd backend
uv sync
uv run uvicorn app.main:app --reload
```

### 前端开发

```powershell
cd frontend
flutter pub get
flutter run -d windows    # 桌面端
flutter run -d <device>   # Android(需先用 flutter devices 查看设备)
```

## 开发规范

- **分支**: `feat/* | fix/* | chore/* | refactor/* | docs/* | test/*`,禁止直接提交主分支
- **提交**: Conventional Commits;首行英文 ≤72 字符,空行后正文中文
- **PR**: 必经 Code Review 后合并
- **质量门禁**: 后端 `ruff` + `mypy --strict` + `pytest`;前端 `dart format` + `flutter analyze` + `flutter test`;`pre-commit` 钩子本地兜底,CI 强制
