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
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Folder, Tag, Task, TaskList, TaskTag
from app.schemas.folder import FolderRead
from app.schemas.sync import (
    Mutation,
    MutationEntity,
    MutationResult,
    RejectionReason,
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

    **批内因果链**:客户端本地行的 version 只在 push 收到 ``applied`` 后才回写,
    所以同一实体在一批里的第 2 条起必然带着陈旧的 base_version(如离线期间
    「改标题 → 删除」)。这不是并发冲突,是同一客户端同一批请求内的因果顺序;
    若照常判 conflict,客户端 LWW 会拿「本地入队时刻」比「服务端刚应用前一条的
    时刻」,后者恒晚 → 服务端恒胜 → 用户的删除被静默吞掉。这里记住本批已成功
    应用过的实体,对其后继 mutation 跳过 base_version 检查、直接按序接续。
    跨批次的真并发(另一台设备的写)不在此集合中,仍照常判 conflict。
    """
    # 按依赖排序,父实体先于子实体。sort 是稳定的,同一实体内部保持客户端
    # 入队顺序 —— 批内因果链接续依赖这一点。
    order: dict[str, int] = {
        "folder": 0,
        "list": 1,
        "tag": 2,
        "task": 3,
        "task_tag": 4,
    }
    indexed = list(enumerate(request.mutations))
    indexed.sort(key=lambda pair: order.get(pair[1].entity, 99))
    # task 之间还有批内父子依赖(parent_id / recurrence_parent_id),再排一次。
    indexed = _sort_tasks_by_dependency(indexed)

    # 本批已成功应用过的实体。task_tag 不参与:它无 version、不做乐观并发,
    # 且 Mutation.id 只是占位(真正主键在 payload)。
    applied_in_batch: set[tuple[str, str]] = set()

    # slot for results, preserve original order
    results: list[MutationResult | None] = [None] * len(request.mutations)
    for orig_idx, mut in indexed:
        result = await _apply_one(session, user_id, mut, applied_in_batch)
        if result.status == "applied" and mut.entity != "task_tag":
            applied_in_batch.add((mut.entity, str(mut.id)))
        results[orig_idx] = result

    await session.commit()
    return SyncPushResponse(
        cursor=datetime.now(UTC),
        results=[r for r in results if r is not None],
    )


def _sort_tasks_by_dependency(
    indexed: list[tuple[int, Mutation]],
) -> list[tuple[int, Mutation]]:
    """把 task 分片内「引用了本批另一条 task」的 mutation 排到被引用者之后。

    tasks 之间有 ``parent_id``(子任务)与 ``recurrence_parent_id``(重复 override)
    两条自引用外键。客户端按 outbox ``createdAt`` 发送,父任务通常先建,但离线
    积累、分组合并、冲突重发都可能打乱顺序;顺序错了会 FK 违例被 rejected,重试
    耗尽即成死信,那条任务(及其整棵子树)就再也上不了云。

    同一实体的多条 mutation 的**相对顺序保持不变** —— 批内因果链接续依赖这一点。
    """
    tasks = [(pos, pair) for pos, pair in enumerate(indexed) if pair[1].entity == "task"]
    if len(tasks) < 2:
        return indexed

    ids = {str(pair[1].id) for _, pair in tasks}
    # 一个 id 可能有多条 mutation;依赖只需指向最早那条(创建行的那条)。
    first_at: dict[str, int] = {}
    for local_idx, (_, pair) in enumerate(tasks):
        first_at.setdefault(str(pair[1].id), local_idx)

    def refs_of(mut: Mutation) -> list[str]:
        if mut.op != "upsert":
            return []  # delete / purge 只写时间戳,不引入外键依赖
        out = []
        for field in ("parent_id", "recurrence_parent_id"):
            value = mut.payload.get(field)
            if isinstance(value, str) and value in ids and value != str(mut.id):
                out.append(value)
        return out

    ordered: list[int] = []
    done: set[int] = set()

    def visit(local_idx: int, path: frozenset[int]) -> None:
        if local_idx in done or local_idx in path:
            return  # 已排过,或撞上环(数据异常),按原序落位即可
        for ref in refs_of(tasks[local_idx][1][1]):
            visit(first_at[ref], path | {local_idx})
        if local_idx not in done:
            done.add(local_idx)
            ordered.append(local_idx)

    for local_idx in range(len(tasks)):
        visit(local_idx, frozenset())

    result = list(indexed)
    slots = [pos for pos, _ in tasks]
    for slot, local_idx in zip(slots, ordered, strict=True):
        result[slot] = tasks[local_idx][1]
    return result


async def _apply_one(
    session: AsyncSession,
    user_id: UUID,
    mut: Mutation,
    applied_in_batch: set[tuple[str, str]] | None = None,
) -> MutationResult:
    if mut.entity == "task_tag":
        return await _apply_task_tag(session, user_id, mut)

    model = _ENTITY_MODEL.get(mut.entity)
    if model is None:
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected", reason="unknown")

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
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected", reason="validation")

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
                    return MutationResult(
                        entity=mut.entity, id=mut.id, status="rejected", reason="validation"
                    )

                row = model(id=mut.id, user_id=user_id)
                _assign(row, parsed)
                session.add(row)
                await session.flush()
                return MutationResult(
                    entity=mut.entity, id=mut.id, status="applied", version=row.version
                )

            if existing.user_id != user_id:
                return MutationResult(
                    entity=mut.entity, id=mut.id, status="rejected", reason="ownership"
                )

            # 墓碑是终态,不可复活。upsert 打在已 purge 的行上会把编辑写进墓碑,
            # 而墓碑随 delta 下发时各端(含发起端)都会物理删本地行 —— 用户刚编辑
            # 过的任务凭空消失。回 rejected + server_value,让客户端物理删本地行
            # 并清掉该实体残留的 outbox。delete / purge 打在墓碑上是幂等的,放行。
            if existing.purged_at is not None and mut.op == "upsert":
                return MutationResult(
                    entity=mut.entity,
                    id=mut.id,
                    status="rejected",
                    reason="purged",
                    version=existing.version,
                    server_value=_ENTITY_READ_SCHEMA[mut.entity]
                    .model_validate(existing)
                    .model_dump(mode="json"),
                )

            # 本批已应用过这一实体 → 当前这条是它的因果后继,base_version 必然
            # 陈旧,按序接续而不判冲突(见 push 的 docstring)。
            in_batch = (
                applied_in_batch is not None and (mut.entity, str(mut.id)) in applied_in_batch
            )
            if existing.version != mut.base_version and not in_batch:
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
        return MutationResult(
            entity=mut.entity, id=mut.id, status="rejected", reason=_reason_for(exc)
        )


def _reason_for(exc: BaseException) -> RejectionReason:
    """区分「父实体还没推上去」与真正的永久错误。

    FK 违例是暂时的:父任务下一轮推上去后同一条 mutation 就能成功。批内顺序
    问题已由 _sort_tasks_by_dependency 根治,剩下的多是跨批次依赖。
    """
    return "dependency" if isinstance(exc, IntegrityError) else "validation"


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
        return MutationResult(entity=mut.entity, id=mut.id, status="rejected", reason="validation")

    try:
        async with session.begin_nested():
            task = await session.get(Task, payload.task_id)
            tag = await session.get(Tag, payload.tag_id)
            if task is None or tag is None:
                # 关联的两端还没推上去 —— 暂时错误,下一轮可能就好了。
                return MutationResult(
                    entity=mut.entity, id=mut.id, status="rejected", reason="dependency"
                )
            if task.user_id != user_id or tag.user_id != user_id:
                return MutationResult(
                    entity=mut.entity, id=mut.id, status="rejected", reason="ownership"
                )

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
        return MutationResult(
            entity=mut.entity, id=mut.id, status="rejected", reason=_reason_for(exc)
        )


def _assign(row: Any, parsed: Any) -> None:
    for key, value in parsed.model_dump(exclude_unset=True).items():
        setattr(row, key, value)
