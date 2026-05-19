"""Tag REST endpoints."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUserId
from app.db.session import get_session
from app.schemas.tag import TagCreate, TagRead, TagUpdate
from app.services import tag_service

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get("", response_model=list[TagRead])
async def list_tags(session: SessionDep, user_id: CurrentUserId) -> list[TagRead]:
    items = await tag_service.list_tags(session, user_id)
    return [TagRead.model_validate(t) for t in items]


@router.post("", response_model=TagRead, status_code=status.HTTP_201_CREATED)
async def create_tag(
    payload: TagCreate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TagRead:
    tag = await tag_service.create_tag(session, user_id, payload)
    return TagRead.model_validate(tag)


@router.get("/{tag_id}", response_model=TagRead)
async def get_tag(
    tag_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TagRead:
    tag = await tag_service.get_tag(session, user_id, tag_id)
    if tag is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tag not found")
    return TagRead.model_validate(tag)


@router.patch("/{tag_id}", response_model=TagRead)
async def update_tag(
    tag_id: UUID,
    payload: TagUpdate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> TagRead:
    tag = await tag_service.get_tag(session, user_id, tag_id)
    if tag is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tag not found")
    tag = await tag_service.update_tag(session, tag, payload)
    return TagRead.model_validate(tag)


@router.delete("/{tag_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_tag(
    tag_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> None:
    tag = await tag_service.get_tag(session, user_id, tag_id)
    if tag is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Tag not found")
    await tag_service.soft_delete_tag(session, tag)
