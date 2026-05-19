"""Shared pytest fixtures.

策略:
- 每个测试拿到一个全新的 in-memory sqlite + 全表 ``create_all``,无需跑 Alembic
- 通过 ``StaticPool`` 保证同一 :memory: 库在所有协程间共享
- ``app.db.session.get_session`` 依赖在 ``client`` fixture 中被覆盖,指向测试库
"""

from __future__ import annotations

from collections.abc import AsyncIterator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool

# 必须先导入 app.models,触发所有 ORM 模型注册到 Base.metadata,
# 之后 Base.metadata.create_all 才能建出表。
import app.models  # noqa: F401  (side effect: register models)
from app.db.base import Base
from app.db.session import get_session
from app.main import app as fastapi_app


@pytest.fixture(scope="session")
def anyio_backend() -> str:
    return "asyncio"


@pytest_asyncio.fixture
async def engine() -> AsyncIterator[AsyncEngine]:
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    try:
        yield engine
    finally:
        await engine.dispose()


@pytest_asyncio.fixture
async def session(engine: AsyncEngine) -> AsyncIterator[AsyncSession]:
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with factory() as session:
        yield session


@pytest_asyncio.fixture
async def client(engine: AsyncEngine) -> AsyncIterator[AsyncClient]:
    factory = async_sessionmaker(engine, expire_on_commit=False)

    async def override_get_session() -> AsyncIterator[AsyncSession]:
        async with factory() as s:
            yield s

    fastapi_app.dependency_overrides[get_session] = override_get_session
    transport = ASGITransport(app=fastapi_app)
    try:
        async with AsyncClient(transport=transport, base_url="http://test") as ac:
            yield ac
    finally:
        fastapi_app.dependency_overrides.clear()
