"""Task REST endpoints."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUserId
from app.db.session import get_session
from app.schemas.tag import TagRead
from app.schemas.task import (
    TaskCompleteRequest,
    TaskCreate,
    TaskRead,
    TaskUpdate,
)
from app.services import tag_service, task_service

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get("", response_model=list[TaskRead])
async def list_tasks(
    session: SessionDep,
    user_id: CurrentUserId,
    list_id: Annotated[UUID | None, Query()] = None,
    parent_id: Annotated[UUID | None, Query()] = None,
    root_only: Annotated[bool, Query()] = False,
    include_deleted: Annotated[bool, Query()] = False,
) -> list[TaskRead]:
    tasks = await task_service.list_tasks(
        session,
        user_id,
        list_id=list_id,
        parent_id=parent_id,
        root_only=root_only,
        include_deleted=include_deleted,
    )
    return [TaskRead.model_validate(t) for t in tasks]


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def create_task(
    payload: TaskCreate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TaskRead:
    task = await task_service.create_task(session, user_id, payload)
    return TaskRead.model_validate(task)


@router.get("/{task_id}", response_model=TaskRead)
async def get_task(
    task_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TaskRead:
    task = await task_service.get_task(session, user_id, task_id, include_deleted=True)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    return TaskRead.model_validate(task)


@router.patch("/{task_id}", response_model=TaskRead)
async def update_task(
    task_id: UUID,
    payload: TaskUpdate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TaskRead:
    task = await task_service.get_task(session, user_id, task_id)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    task = await task_service.update_task(session, task, payload)
    return TaskRead.model_validate(task)


@router.post("/{task_id}/complete", response_model=TaskRead)
async def complete_task(
    task_id: UUID,
    payload: TaskCompleteRequest,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TaskRead:
    task = await task_service.get_task(session, user_id, task_id)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    task = await task_service.set_completed(session, task, completed=payload.completed)
    return TaskRead.model_validate(task)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def soft_delete_task(
    task_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> None:
    task = await task_service.get_task(session, user_id, task_id)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    await task_service.soft_delete_task(session, task)


@router.post("/{task_id}/restore", response_model=TaskRead)
async def restore_task(
    task_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TaskRead:
    task = await task_service.get_task(session, user_id, task_id, include_deleted=True)
    if task is None or task.deleted_at is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not in trash")
    task = await task_service.restore_task(session, task)
    return TaskRead.model_validate(task)


@router.delete("/{task_id}/permanent", status_code=status.HTTP_204_NO_CONTENT)
async def hard_delete_task(
    task_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> None:
    task = await task_service.get_task(session, user_id, task_id, include_deleted=True)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    await task_service.hard_delete_task(session, task)


# ----- Task <-> Tag association -----


@router.get("/{task_id}/tags", response_model=list[TagRead])
async def list_task_tags(
    task_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> list[TagRead]:
    task = await task_service.get_task(session, user_id, task_id, include_deleted=True)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    tags = await tag_service.list_tags_for_task(session, user_id, task_id)
    return [TagRead.model_validate(t) for t in tags]


@router.put("/{task_id}/tags/{tag_id}", status_code=status.HTTP_204_NO_CONTENT)
async def add_tag_to_task(
    task_id: UUID,
    tag_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> None:
    task = await task_service.get_task(session, user_id, task_id, include_deleted=True)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    tag = await tag_service.get_tag(session, user_id, tag_id)
    if tag is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tag not found")
    await tag_service.add_tag_to_task(session, task_id, tag_id)


@router.delete("/{task_id}/tags/{tag_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_tag_from_task(
    task_id: UUID,
    tag_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> None:
    task = await task_service.get_task(session, user_id, task_id, include_deleted=True)
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task not found")
    await tag_service.remove_tag_from_task(session, task_id, tag_id)
