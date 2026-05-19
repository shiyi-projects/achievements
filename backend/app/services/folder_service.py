"""Folder business logic."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Folder
from app.schemas.folder import FolderCreate, FolderUpdate


async def list_folders(session: AsyncSession, user_id: UUID) -> list[Folder]:
    result = await session.execute(
        select(Folder)
        .where(Folder.user_id == user_id, Folder.deleted_at.is_(None))
        .order_by(Folder.sort_order, Folder.name)
    )
    return list(result.scalars().all())


async def create_folder(
    session: AsyncSession,
    user_id: UUID,
    payload: FolderCreate,
) -> Folder:
    folder = Folder(user_id=user_id, name=payload.name, sort_order=payload.sort_order)
    session.add(folder)
    await session.commit()
    await session.refresh(folder)
    return folder


async def get_folder(session: AsyncSession, user_id: UUID, folder_id: UUID) -> Folder | None:
    result = await session.execute(
        select(Folder).where(
            Folder.id == folder_id,
            Folder.user_id == user_id,
            Folder.deleted_at.is_(None),
        )
    )
    return result.scalar_one_or_none()


async def update_folder(
    session: AsyncSession,
    folder: Folder,
    payload: FolderUpdate,
) -> Folder:
    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(folder, key, value)
    await session.commit()
    await session.refresh(folder)
    return folder


async def soft_delete_folder(session: AsyncSession, folder: Folder) -> None:
    from datetime import UTC, datetime

    folder.deleted_at = datetime.now(UTC)
    await session.commit()
