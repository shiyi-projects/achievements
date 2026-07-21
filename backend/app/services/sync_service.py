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

from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy import delete, select
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
    TaskTagPayload,
)
from app.schemas.tag import TagRead
from app.schemas.task import TaskRead
from app.schemas.task_list import TaskListRead

# 永久删除墓碑的保留期。超过此时长的 purged_at / task_tag.deleted_at 行,
# 在 pull 时被惰性 GC 物理清除。需 ≥ 任意设备最长可能离线时长,否则离线设备
# 回来时拿不到墓碑(它仍持有本地副本,无害,只是不会被远端清掉)。
PURGE_RETENTION = timedelta(days=30)

# pull 增量查询的重叠窗口。push 里各行的 updated_at 在逐条 flush 时生成,而
# commit 在整批末尾;并发 pull 拿到的 cursor 可能晚于这些 updated_at,却因事务
# 隔离读不到未提交的行——若严格用 updated_at > since,这些变更会被永久漏掉。
# 查询时把 since 回退此窗口,宁可重复下发(客户端落库幂等)也不丢。
SINCE_OVERLAP = timedelta(seconds=60)


async def pull(
    session: AsyncSession,
    user_id: UUID,
    since: datetime | None,
) -> SyncPullResponse:
    """返回 [since, now) 区间内所有可同步实体的变更。

    返回前先做一次惰性 GC:物理清除超过保留期的永久删除墓碑,避免墓碑无限堆积。
    """
    cursor = datetime.now(UTC)

    await _gc_purged(session, user_id=user_id, now=cursor)

    # 回退重叠窗口防并发提交丢更新,见 SINCE_OVERLAP 注释。
    effective_since = None if since is None else since - SINCE_OVERLAP

    folders = await _delta(session, Folder, user_id=user_id, since=effective_since)
    lists = await _delta(session, TaskList, user_id=user_id, since=effective_since)
    tasks = await _delta(session, Task, user_id=user_id, since=effective_since)
    tags = await _delta(session, Tag, user_id=user_id, since=effective_since)
    task_tags = await _task_tags_delta(session, user_id=user_id, since=effective_since)

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
    """TaskTag 没有独立 user_id,通过 join 到 tasks 拿 user 归属;增量条件用
    ``updated_at > since`` —— 关联建立/删除(置 deleted_at)都会 bump updated_at,
    删除墓碑据此下发给各端。"""
    query = (
        select(TaskTag)
        .join(Task, Task.id == TaskTag.task_id)
        .where(
            Task.user_id == user_id,
        )
    )
    if since is not None:
        query = query.where(TaskTag.updated_at > since)
    query = query.order_by(TaskTag.updated_at)
    result = await session.execute(query)
    return list(result.scalars().all())


async def _gc_purged(
    session: AsyncSession,
    *,
    user_id: UUID,
    now: datetime,
) -> None:
    """物理清除超过保留期的删除墓碑(purged_at / task_tag.deleted_at)。

    保留期内的墓碑仍随 delta 下发,确保各端都能 pull 到并物理删本地行;到期后
    认为已传播完毕,物理删除以免无限堆积。FK 的 ON DELETE CASCADE 会带走子行。
    """
    threshold = now - PURGE_RETENTION

    for model in (Folder, TaskList, Task, Tag):
        await session.execute(
            delete(model).where(
                model.user_id == user_id,
                model.purged_at.is_not(None),
                model.purged_at < threshold,
            )
        )

    # task_tags 无 user_id,通过 task 归属过滤;删除墓碑用 deleted_at。
    await session.execute(
        delete(TaskTag).where(
            TaskTag.deleted_at.is_not(None),
            TaskTag.deleted_at < threshold,
            TaskTag.task_id.in_(select(Task.id).where(Task.user_id == user_id)),
        )
    )

    await session.commit()


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

# Fields that MUST be present (not None) when creating a *new* entity.
# Maps entity type → list of field names that are NOT NULL in the DB schema.
_ENTITY_REQUIRED_ON_CREATE: dict[MutationEntity, list[str]] = {
    "folder": ["name"],
    "list": ["name"],
    "task": ["list_id", "title"],
    "tag": ["name"],
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
    order: dict[str, int] = {
        "folder": 0,
        "list": 1,
        "tag": 2,
        "task": 3,
        "task_tag": 4,
    }
    indexed = list(enumerate(request.mutations))
    indexed.sort(key=lambda pair: order.get(pair[1].entity, 99))

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
        return await _apply_task_tag(session, user_id, mut)

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
            mut.entity,
            mut.id,
            type(exc).__name__,
            exc,
        )
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected")

    # 使用 savepoint 隔离,单条 IntegrityError 不会使整个 session 失效
    try:
        async with session.begin_nested():
            existing = await session.get(model, mut.id)

            if existing is None:
                if mut.op in ("delete", "purge"):
                    # 行已不存在 → 删除/永久删除幂等成功。
                    return MutationResult(entity=mut.entity, id=mut.id, status="applied", version=1)

                # Validate required fields before INSERT to avoid DB NOT-NULL violations
                required = _ENTITY_REQUIRED_ON_CREATE.get(mut.entity, [])
                payload_data = parsed.model_dump(exclude_unset=True)
                missing = [f for f in required if payload_data.get(f) is None]
                if missing:
                    import logging

                    logging.getLogger(__name__).warning(
                        "sync: mutation %s/%s rejected (missing required fields: %s)",
                        mut.entity,
                        mut.id,
                        ", ".join(missing),
                    )
                    return MutationResult(entity=mut.entity, id=mut.id, status="rejected")

                row = model(id=mut.id, user_id=user_id)
                _assign(row, parsed)
                session.add(row)
                await session.flush()
                return MutationResult(
                    entity=mut.entity, id=mut.id, status="applied", version=row.version
                )

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
            elif mut.op == "purge":
                # 永久删除:写墓碑。客户端 pull 到 purged_at 非空后物理删本地行,
                # 服务端保留至超过保留期再被 _gc_purged 物理清除。
                existing.purged_at = datetime.now(UTC)
            else:
                _assign(existing, parsed)
            existing.version += 1
            await session.flush()
            return MutationResult(
                entity=mut.entity, id=mut.id, status="applied", version=existing.version
            )
    except Exception as exc:
        # IntegrityError, FK violation, etc. — reject this mutation only
        import logging

        logging.getLogger(__name__).warning(
            "sync: mutation %s/%s rejected due to %s: %s",
            mut.entity,
            mut.id,
            type(exc).__name__,
            exc,
        )
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected")


async def _apply_task_tag(
    session: AsyncSession,
    user_id: UUID,
    mut: Mutation,
) -> MutationResult:
    """task_tag 关联同步:复合键 (task_id, tag_id) 取自 payload,不用 Mutation.id。

    - upsert:建立关联(已存在则恢复 deleted_at=None),幂等。
    - delete / purge:置 deleted_at 墓碑;不存在则幂等成功。

    归属校验:task 与 tag 都须属于当前 user,否则 rejected。关联表无 version,
    不参与乐观并发,version 字段回 1 占位。
    """
    try:
        payload = TaskTagPayload.model_validate(mut.payload)
    except Exception as exc:
        import logging

        logging.getLogger(__name__).warning(
            "sync: task_tag %s rejected (payload validation): %s: %s",
            mut.id,
            type(exc).__name__,
            exc,
        )
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected")

    try:
        async with session.begin_nested():
            task = await session.get(Task, payload.task_id)
            tag = await session.get(Tag, payload.tag_id)
            if task is None or task.user_id != user_id or tag is None or tag.user_id != user_id:
                return MutationResult(entity=mut.entity, id=mut.id, status="rejected")

            existing = await session.get(TaskTag, (payload.task_id, payload.tag_id))

            if mut.op in ("delete", "purge"):
                if existing is not None:
                    existing.deleted_at = datetime.now(UTC)
                    await session.flush()
                return MutationResult(entity=mut.entity, id=mut.id, status="applied", version=1)

            # upsert:建立或恢复关联(墓碑复活)
            if existing is None:
                session.add(TaskTag(task_id=payload.task_id, tag_id=payload.tag_id))
            else:
                existing.deleted_at = None
            await session.flush()
            return MutationResult(entity=mut.entity, id=mut.id, status="applied", version=1)
    except Exception as exc:
        import logging

        logging.getLogger(__name__).warning(
            "sync: task_tag %s rejected due to %s: %s",
            mut.id,
            type(exc).__name__,
            exc,
        )
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected")


def _assign(row: Any, parsed: Any) -> None:
    for key, value in parsed.model_dump(exclude_unset=True).items():
        setattr(row, key, value)
