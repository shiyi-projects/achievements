"""TaskList business logic + system list seeding."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.system_lists import (
    SYSTEM_LIST_DISPLAY_NAMES,
    SYSTEM_LIST_IDS,
    SystemListKind,
)
from app.models import Task, TaskList
from app.schemas.task_list import TaskListCreate, TaskListUpdate


async def list_task_lists(session: AsyncSession, user_id: UUID) -> list[TaskList]:
    result = await session.execute(
        select(TaskList)
        .where(TaskList.user_id == user_id, TaskList.deleted_at.is_(None))
        .order_by(TaskList.sort_order, TaskList.name)
    )
    return list(result.scalars().all())


async def get_task_list(
    session: AsyncSession,
    user_id: UUID,
    list_id: UUID,
) -> TaskList | None:
    result = await session.execute(
        select(TaskList).where(
            TaskList.id == list_id,
            TaskList.user_id == user_id,
            TaskList.deleted_at.is_(None),
        )
    )
    return result.scalar_one_or_none()


async def create_task_list(
    session: AsyncSession,
    user_id: UUID,
    payload: TaskListCreate,
) -> TaskList:
    item = TaskList(
        user_id=user_id,
        name=payload.name,
        folder_id=payload.folder_id,
        color=payload.color,
        icon=payload.icon,
        sort_order=payload.sort_order,
        is_system=False,
    )
    session.add(item)
    await session.commit()
    await session.refresh(item)
    return item


async def update_task_list(
    session: AsyncSession,
    item: TaskList,
    payload: TaskListUpdate,
) -> TaskList:
    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(item, key, value)
    await session.commit()
    await session.refresh(item)
    return item


async def soft_delete_task_list(session: AsyncSession, item: TaskList) -> None:
    if item.is_system:
        raise ValueError("System lists cannot be deleted")
    item.deleted_at = datetime.now(UTC)
    await session.commit()


async def ensure_system_lists(session: AsyncSession, user_id: UUID) -> None:
    """Idempotent seed of the 7 built-in system lists for ``user_id``.

    若已存在 system_kind 匹配但 id 不是固定值的行(旧随机 UUID),
    把该行 id 以及所有 tasks.list_id 迁移到固定 UUID。
    SQLite FK 默认未启用,迁移安全;PostgreSQL 上因先更新 tasks 再更新
    task_lists,亦满足约束时序。
    """
    for index, kind in enumerate(SystemListKind):
        fixed_id = SYSTEM_LIST_IDS[kind]
        result = await session.execute(
            select(TaskList).where(
                TaskList.user_id == user_id,
                TaskList.system_kind == kind.value,
            )
        )
        row = result.scalar_one_or_none()
        if row is None:
            session.add(
                TaskList(
                    id=fixed_id,
                    user_id=user_id,
                    name=SYSTEM_LIST_DISPLAY_NAMES[kind],
                    is_system=True,
                    system_kind=kind.value,
                    sort_order=index,
                )
            )
        elif row.id != fixed_id:
            # 旧随机 UUID → 固定 UUID:先迁移 tasks 引用,再更新 task_lists.id
            await session.execute(
                sa_update(Task)
                .where(Task.list_id == row.id)
                .values(list_id=fixed_id)
            )
            await session.execute(
                sa_update(TaskList)
                .where(TaskList.id == row.id)
                .values(id=fixed_id)
            )
            session.expunge(row)
    await session.commit()
