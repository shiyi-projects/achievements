"""FocusSession REST endpoints."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUserId
from app.db.session import get_session
from app.schemas.focus_session import (
    FocusSessionCreate,
    FocusSessionRead,
    FocusSessionUpdate,
)
from app.services import focus_session_service

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get("", response_model=list[FocusSessionRead])
async def list_focus_sessions(
    session: SessionDep,
    user_id: CurrentUserId,
    since: Annotated[datetime | None, Query(description="ISO-8601,过滤 started_at ≥ since")] = None,
    until: Annotated[datetime | None, Query(description="ISO-8601,过滤 started_at < until")] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 50,
) -> list[FocusSessionRead]:
    rows = await focus_session_service.list_sessions(
        session, user_id, since=since, until=until, limit=limit
    )
    return [FocusSessionRead.model_validate(r) for r in rows]


@router.post("", response_model=FocusSessionRead, status_code=status.HTTP_201_CREATED)
async def create_focus_session(
    payload: FocusSessionCreate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> FocusSessionRead:
    obj = await focus_session_service.create_session(session, user_id, payload)
    await session.commit()
    return FocusSessionRead.model_validate(obj)


@router.get("/{session_id}", response_model=FocusSessionRead)
async def get_focus_session(
    session_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> FocusSessionRead:
    obj = await focus_session_service.get_session(session, user_id, session_id)
    if obj is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return FocusSessionRead.model_validate(obj)


@router.patch("/{session_id}", response_model=FocusSessionRead)
async def update_focus_session(
    session_id: UUID,
    payload: FocusSessionUpdate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> FocusSessionRead:
    obj = await focus_session_service.update_session(session, user_id, session_id, payload)
    if obj is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    await session.commit()
    return FocusSessionRead.model_validate(obj)


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_focus_session(
    session_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> None:
    deleted = await focus_session_service.delete_session(session, user_id, session_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    await session.commit()
