"""Sync engine business logic.

Phase 2 step 1:增量 pull(此文件)+ push(下个 commit)。

策略:
- pull 接受 ``since`` cursor(server-side updated_at);为空时回全量
- 返回的 cursor 是服务端"拉取这一刻"的 utcnow,客户端下次回传
- 软删行(deleted_at != null)也返回,客户端据此本地软删
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Folder, Tag, Task, TaskList, TaskTag
from app.schemas.folder import FolderRead
from app.schemas.sync import SyncPullResponse, TaskTagRead
from app.schemas.tag import TagRead
from app.schemas.task import TaskRead
from app.schemas.task_list import TaskListRead


async def pull(
    session: AsyncSession,
    user_id: UUID,
    since: datetime | None,
) -> SyncPullResponse:
    """返回 [since, now) 区间内所有可同步实体的变更。"""
    cursor = datetime.now(UTC)

    folders = await _delta(session, Folder, user_id=user_id, since=since)
    lists = await _delta(session, TaskList, user_id=user_id, since=since)
    tasks = await _delta(session, Task, user_id=user_id, since=since)
    tags = await _delta(session, Tag, user_id=user_id, since=since)
    task_tags = await _task_tags_delta(session, user_id=user_id, since=since)

    return SyncPullResponse(
        cursor=cursor,
        folders=[FolderRead.model_validate(f) for f in folders],
        lists=[TaskListRead.model_validate(item) for item in lists],
        tasks=[TaskRead.model_validate(t) for t in tasks],
        tags=[TagRead.model_validate(t) for t in tags],
        task_tags=[TaskTagRead.model_validate(tt) for tt in task_tags],
    )


async def _delta[T](
    session: AsyncSession,
    model: type[T],
    *,
    user_id: UUID,
    since: datetime | None,
) -> list[T]:
    """通用增量查询:user_id 匹配 + (since 为空 OR updated_at > since)。"""
    query = select(model).where(model.user_id == user_id)  # type: ignore[attr-defined]
    if since is not None:
        query = query.where(model.updated_at > since)  # type: ignore[attr-defined]
    query = query.order_by(model.updated_at)  # type: ignore[attr-defined]
    result = await session.execute(query)
    return list(result.scalars().all())


async def _task_tags_delta(
    session: AsyncSession,
    *,
    user_id: UUID,
    since: datetime | None,
) -> list[TaskTag]:
    """TaskTag 没有独立 user_id / updated_at,通过 join 到 tasks 拿 user 归属;
    增量条件用 ``created_at > since``(关联表只增不改)。"""
    query = (
        select(TaskTag)
        .join(Task, Task.id == TaskTag.task_id)
        .where(
            Task.user_id == user_id,
        )
    )
    if since is not None:
        query = query.where(TaskTag.created_at > since)
    query = query.order_by(TaskTag.created_at)
    result = await session.execute(query)
    return list(result.scalars().all())
