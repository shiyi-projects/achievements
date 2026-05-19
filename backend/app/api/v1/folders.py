"""Folders REST endpoints."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUserId
from app.db.session import get_session
from app.schemas.folder import FolderCreate, FolderRead, FolderUpdate
from app.services import folder_service

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get("", response_model=list[FolderRead])
async def list_folders(session: SessionDep, user_id: CurrentUserId) -> list[FolderRead]:
    folders = await folder_service.list_folders(session, user_id)
    return [FolderRead.model_validate(f) for f in folders]


@router.post("", response_model=FolderRead, status_code=status.HTTP_201_CREATED)
async def create_folder(
    payload: FolderCreate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> FolderRead:
    folder = await folder_service.create_folder(session, user_id, payload)
    return FolderRead.model_validate(folder)


@router.get("/{folder_id}", response_model=FolderRead)
async def get_folder(
    folder_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> FolderRead:
    folder = await folder_service.get_folder(session, user_id, folder_id)
    if folder is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Folder not found")
    return FolderRead.model_validate(folder)


@router.patch("/{folder_id}", response_model=FolderRead)
async def update_folder(
    folder_id: UUID,
    payload: FolderUpdate,
    session: SessionDep,
    user_id: CurrentUserId,
) -> FolderRead:
    folder = await folder_service.get_folder(session, user_id, folder_id)
    if folder is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Folder not found")
    folder = await folder_service.update_folder(session, folder, payload)
    return FolderRead.model_validate(folder)


@router.delete("/{folder_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_folder(
    folder_id: UUID,
    session: SessionDep,
    user_id: CurrentUserId,
) -> None:
    folder = await folder_service.get_folder(session, user_id, folder_id)
    if folder is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Folder not found")
    await folder_service.soft_delete_folder(session, folder)
