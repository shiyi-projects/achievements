"""Async SQLAlchemy engine and session factory."""

from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import get_settings

_settings = get_settings()

_connect_args: dict[str, object] = {}
if _settings.database_disable_statement_cache:
    # asyncpg + PgBouncer Transaction Pooler:必须禁掉预编译语句缓存,否则报
    # `prepared statement "__asyncpg_stmt_..." does not exist`。
    _connect_args["statement_cache_size"] = 0
    _connect_args["prepared_statement_cache_size"] = 0

engine: AsyncEngine = create_async_engine(
    _settings.database_url,
    echo=_settings.app_debug and _settings.app_env == "development",
    pool_pre_ping=True,
    future=True,
    connect_args=_connect_args,
)

SessionLocal: async_sessionmaker[AsyncSession] = async_sessionmaker(
    bind=engine,
    expire_on_commit=False,
    autoflush=False,
)


async def get_session() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency that yields a transactional async session."""
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
