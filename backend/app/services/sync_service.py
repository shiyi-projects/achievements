"""Sync engine business logic.

Phase 2 step 1:增量 pull + push(LWW 冲突解决)。

策略:
- pull 接受 ``since`` cursor(server-side updated_at);为空时回全量
- 返回的 cursor 是服务端"拉取这一刻"的 utcnow,客户端下次回传
- 软删行(deleted_at != null)也返回,客户端据此本地软删
- push:
  * upsert:不存在 → 创建(version=1);存在 → 比 base_version,匹配则 apply
    并 bump version;不匹配 → conflict + server_value
  * delete:软删(写 deleted_at + bump version)
  * 异常(FK 违例 / payload 校验失败)→ rejected
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Folder, Tag, Task, TaskList, TaskTag
from app.schemas.folder import FolderRead
from app.schemas.sync import (
    Mutation,
    MutationEntity,
    MutationResult,
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
    TaskTagRead,
)
from app.schemas.sync_payload import (
    FolderPayload,
    TagPayload,
    TaskListPayload,
    TaskPayload,
)
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


# ---- push -----------------------------------------------------------------

_ENTITY_MODEL: dict[MutationEntity, type[Any]] = {
    "folder": Folder,
    "list": TaskList,
    "task": Task,
    "tag": Tag,
}

_ENTITY_PAYLOAD_SCHEMA: dict[MutationEntity, type[Any]] = {
    "folder": FolderPayload,
    "list": TaskListPayload,
    "task": TaskPayload,
    "tag": TagPayload,
}

_ENTITY_READ_SCHEMA: dict[MutationEntity, type[Any]] = {
    "folder": FolderRead,
    "list": TaskListRead,
    "task": TaskRead,
    "tag": TagRead,
}


async def push(
    session: AsyncSession,
    user_id: UUID,
    request: SyncPushRequest,
) -> SyncPushResponse:
    """批量应用客户端 mutations。单条异常仅自身被 rejected,其他 commit。

    使用 savepoint 隔离每条 mutation,一条 FK 违例不会破坏整个 session。
    按 entity 依赖顺序排序:folder → list → task → tag → task_tag。
    """
    # 按依赖排序,父实体先于子实体
    _ORDER: dict[str, int] = {
        "folder": 0,
        "list": 1,
        "tag": 2,
        "task": 3,
        "task_tag": 4,
    }
    indexed = list(enumerate(request.mutations))
    indexed.sort(key=lambda pair: _ORDER.get(pair[1].entity, 99))

    # slot for results, preserve original order
    results: list[MutationResult | None] = [None] * len(request.mutations)
    for orig_idx, mut in indexed:
        results[orig_idx] = await _apply_one(session, user_id, mut)

    await session.commit()
    return SyncPushResponse(
        cursor=datetime.now(UTC),
        results=[r for r in results if r is not None],
    )


async def _apply_one(
    session: AsyncSession,
    user_id: UUID,
    mut: Mutation,
) -> MutationResult:
    if mut.entity == "task_tag":
        # Phase 2 step 1 暂不支持 task_tag 同步,后续单独 commit 接入
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected")

    model = _ENTITY_MODEL.get(mut.entity)
    if model is None:
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected")

    try:
        payload_schema = _ENTITY_PAYLOAD_SCHEMA[mut.entity]
        parsed = payload_schema.model_validate(mut.payload)
    except Exception as exc:
        import logging
        logging.getLogger(__name__).warning(
            "sync: mutation %s/%s rejected (payload validation): %s: %s",
            mut.entity, mut.id, type(exc).__name__, exc,
        )
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected")

    # 使用 savepoint 隔离,单条 IntegrityError 不会使整个 session 失效
    try:
        async with session.begin_nested():
            existing = await session.get(model, mut.id)

            if existing is None:
                if mut.op == "delete":
                    return MutationResult(entity=mut.entity, id=mut.id, status="applied", version=1)
                row = model(id=mut.id, user_id=user_id)
                _assign(row, parsed)
                session.add(row)
                await session.flush()
                return MutationResult(entity=mut.entity, id=mut.id, status="applied", version=row.version)

            if existing.user_id != user_id:
                return MutationResult(entity=mut.entity, id=mut.id, status="rejected")

            if existing.version != mut.base_version:
                return MutationResult(
                    entity=mut.entity,
                    id=mut.id,
                    status="conflict",
                    version=existing.version,
                    server_value=_ENTITY_READ_SCHEMA[mut.entity]
                    .model_validate(existing)
                    .model_dump(mode="json"),
                )

            if mut.op == "delete":
                existing.deleted_at = datetime.now(UTC)
            else:
                _assign(existing, parsed)
            existing.version += 1
            await session.flush()
            return MutationResult(entity=mut.entity, id=mut.id, status="applied", version=existing.version)
    except Exception as exc:
        # IntegrityError, FK violation, etc. — reject this mutation only
        import logging
        logging.getLogger(__name__).warning(
            "sync: mutation %s/%s rejected due to %s: %s",
            mut.entity, mut.id, type(exc).__name__, exc,
        )
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected")


def _assign(row: Any, parsed: Any) -> None:
    for key, value in parsed.model_dump(exclude_unset=True).items():
        setattr(row, key, value)

