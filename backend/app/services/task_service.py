"""Task business logic."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Task
from app.schemas.task import TaskCreate, TaskUpdate


async def list_tasks(
    session: AsyncSession,
    user_id: UUID,
    *,
    list_id: UUID | None = None,
    include_deleted: bool = False,
) -> list[Task]:
    """List tasks belonging to ``user_id``;按 list_id 过滤可选。"""
    query = select(Task).where(Task.user_id == user_id)
    if list_id is not None:
        query = query.where(Task.list_id == list_id)
    if not include_deleted:
        query = query.where(Task.deleted_at.is_(None))
    query = query.order_by(Task.sort_order, Task.created_at)
    result = await session.execute(query)
    return list(result.scalars().all())


async def get_task(
    session: AsyncSession,
    user_id: UUID,
    task_id: UUID,
    *,
    include_deleted: bool = False,
) -> Task | None:
    query = select(Task).where(Task.id == task_id, Task.user_id == user_id)
    if not include_deleted:
        query = query.where(Task.deleted_at.is_(None))
    result = await session.execute(query)
    return result.scalar_one_or_none()


async def create_task(
    session: AsyncSession,
    user_id: UUID,
    payload: TaskCreate,
) -> Task:
    task = Task(
        user_id=user_id,
        list_id=payload.list_id,
        parent_id=payload.parent_id,
        title=payload.title,
        notes=payload.notes,
        priority=payload.priority,
        due_at=payload.due_at,
        remind_at=payload.remind_at,
        color=payload.color,
        starred=payload.starred,
    )
    session.add(task)
    await session.commit()
    await session.refresh(task)
    return task


async def update_task(
    session: AsyncSession,
    task: Task,
    payload: TaskUpdate,
) -> Task:
    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(task, key, value)
    await session.commit()
    await session.refresh(task)
    return task


async def set_completed(
    session: AsyncSession,
    task: Task,
    *,
    completed: bool,
) -> Task:
    task.completed_at = datetime.now(UTC) if completed else None
    await session.commit()
    await session.refresh(task)
    return task


async def soft_delete_task(session: AsyncSession, task: Task) -> None:
    task.deleted_at = datetime.now(UTC)
    await session.commit()


async def restore_task(session: AsyncSession, task: Task) -> Task:
    task.deleted_at = None
    await session.commit()
    await session.refresh(task)
    return task


async def hard_delete_task(session: AsyncSession, task: Task) -> None:
    await session.delete(task)
    await session.commit()
