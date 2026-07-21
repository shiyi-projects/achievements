"""Database keepalive loop.

Supabase free tier 项目闲置约 7 天会被自动暂停(pause),导致后端连库失败、
客户端同步全部报错。此模块在应用生命周期内周期性执行一次轻量查询
(``SELECT 1``),维持「有活跃查询」状态防止被判闲置。

自托管数据库场景该查询无任何副作用;``interval_hours <= 0`` 时禁用。
"""

from __future__ import annotations

import asyncio
import logging

from sqlalchemy import text

from app.db.session import SessionLocal

logger = logging.getLogger(__name__)


async def _keepalive_loop(interval_seconds: float) -> None:
    while True:
        await asyncio.sleep(interval_seconds)
        try:
            async with SessionLocal() as session:
                await session.execute(text("SELECT 1"))
            logger.debug("db keepalive ping ok")
        except Exception:
            # 保活失败不致命(网络抖动 / 库暂停中等),记录后下一轮继续。
            logger.warning("db keepalive ping failed", exc_info=True)


def start_db_keepalive(interval_hours: float) -> asyncio.Task[None] | None:
    """按 ``interval_hours`` 间隔启动保活任务;``<= 0`` 返回 None(禁用)。

    返回的 task 由调用方(lifespan)在应用关闭时 cancel。
    """
    if interval_hours <= 0:
        return None
    logger.info("db keepalive enabled: ping every %.1fh", interval_hours)
    return asyncio.create_task(_keepalive_loop(interval_hours * 3600))
