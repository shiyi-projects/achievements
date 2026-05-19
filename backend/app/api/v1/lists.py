"""TaskList REST endpoints."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUserId
from app.db.session import get_session
from app.schemas.task_list import TaskListCreate, TaskListRead, TaskListUpdate
from app.services import list_service

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get("", response_model=list[TaskListRead])
async def list_lists(session: SessionDep, user_id: CurrentUserId) -> list[TaskListRead]:
    items = await list_service.list_task_lists(session, user_id)
    return [TaskListRead.model_validate(i) for i in items]


@router.post("", response_model=TaskListRead, status_code=status.HTTP_201_CREATED)
async def create_list(
    payload: TaskListCreate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TaskListRead:
    item = await list_service.create_task_list(session, user_id, payload)
    return TaskListRead.model_validate(item)


@router.get("/{list_id}", response_model=TaskListRead)
async def get_list(
    list_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TaskListRead:
    item = await list_service.get_task_list(session, user_id, list_id)
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "List not found")
    return TaskListRead.model_validate(item)


@router.patch("/{list_id}", response_model=TaskListRead)
async def update_list(
    list_id: UUID,
    payload: TaskListUpdate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TaskListRead:
    item = await list_service.get_task_list(session, user_id, list_id)
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "List not found")
    item = await list_service.update_task_list(session, item, payload)
    return TaskListRead.model_validate(item)


@router.delete("/{list_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_list(
    list_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> None:
    item = await list_service.get_task_list(session, user_id, list_id)
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "List not found")
    try:
        await list_service.soft_delete_task_list(session, item)
    except ValueError as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc
