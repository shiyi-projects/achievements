# Achievements Backend

FastAPI 服务,用 [uv](https://docs.astral.sh/uv/) 管理依赖与虚拟环境。

## 本地运行(uv)

```powershell
uv sync                                   # 创建 .venv 并安装依赖
Copy-Item .env.example .env
uv run uvicorn app.main:app --reload
```

## Docker 一键起开发环境

```powershell
Copy-Item .env.example .env
docker compose up --build
```

访问:
- API: http://localhost:8000
- OpenAPI 文档: http://localhost:8000/docs
- 健康检查: http://localhost:8000/healthz

## 代码质量

```powershell
uv run ruff check .            # lint
uv run ruff format .           # format
uv run mypy app                # 类型检查
uv run pytest                  # 单元测试
```

## 数据库迁移

```powershell
uv run alembic revision --autogenerate -m "describe change"
uv run alembic upgrade head
```
