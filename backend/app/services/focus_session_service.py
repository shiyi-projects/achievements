"""FocusSession business logic."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.focus_session import FocusSession
from app.schemas.focus_session import FocusSessionCreate, FocusSessionUpdate


async def list_sessions(
    session: AsyncSession,
    user_id: UUID,
    *,
    since: datetime | None = None,
    until: datetime | None = None,
    limit: int = 50,
) -> list[FocusSession]:
    """列出会话,按 started_at 倒序。支持日期范围过滤(用于统计聚合)。"""
    query = (
        select(FocusSession)
        .where(FocusSession.user_id == user_id)
        .order_by(FocusSession.started_at.desc())
        .limit(limit)
    )
    if since is not None:
        query = query.where(FocusSession.started_at >= since)
    if until is not None:
        query = query.where(FocusSession.started_at < until)
    result = await session.execute(query)
    return list(result.scalars().all())


async def get_session(
    session: AsyncSession,
    user_id: UUID,
    session_id: UUID,
) -> FocusSession | None:
    result = await session.execute(
        select(FocusSession).where(
            FocusSession.id == session_id,
            FocusSession.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def create_session(
    db: AsyncSession,
    user_id: UUID,
    data: FocusSessionCreate,
) -> FocusSession:
    obj = FocusSession(
        id=data.id or uuid4(),
        user_id=user_id,
        task_id=data.task_id,
        started_at=data.started_at,
        ended_at=data.ended_at,
        duration_seconds=data.duration_seconds,
        mode=data.mode,
        completed=data.completed,
    )
    db.add(obj)
    await db.flush()
    await db.refresh(obj)
    return obj


async def update_session(
    db: AsyncSession,
    user_id: UUID,
    session_id: UUID,
    data: FocusSessionUpdate,
) -> FocusSession | None:
    obj = await get_session(db, user_id, session_id)
    if obj is None:
        return None
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(obj, field, value)
    obj.updated_at = datetime.now(UTC)
    await db.flush()
    await db.refresh(obj)
    return obj


async def delete_session(
    db: AsyncSession,
    user_id: UUID,
    session_id: UUID,
) -> bool:
    """硬删。返回 True 表示删除成功,False 表示未找到。"""
    obj = await get_session(db, user_id, session_id)
    if obj is None:
        return False
    await db.delete(obj)
    await db.flush()
    return True
