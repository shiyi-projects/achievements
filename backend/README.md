# Achievements Backend

FastAPI 服务,用 [uv](https://docs.astral.sh/uv/) 管理依赖与虚拟环境。

## 本地运行(uv)

```powershell
uv sync                                   # 创建 .venv 并安装依赖
Copy-Item .env.example .env
uv run uvicorn app.main:app --reload
```

## Docker 启动

复制环境变量模板并填入本地 Postgres / Redis 凭据(参考 `.env.example` 注释):

```powershell
Copy-Item .env.example .env
```

**默认形态**:只起后端 `api` 容器,通过 `host.docker.internal` 连宿主机已运行的 Postgres / Redis:

```powershell
docker compose up --build
```

**完整形态**(适合干净机器,内置 Postgres + Redis):

```powershell
# 同步把 .env 里的 DATABASE_URL / REDIS_URL 改回 db / redis
docker compose --profile full up --build
```

访问:
- API: http://localhost:8000
- OpenAPI 文档: http://localhost:8000/docs
- 健康检查: http://localhost:8000/api/v1/healthz

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
