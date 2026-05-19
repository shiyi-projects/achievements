"""Tag business logic + TaskTags association."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Tag, TaskTag
from app.schemas.tag import TagCreate, TagUpdate


async def list_tags(session: AsyncSession, user_id: UUID) -> list[Tag]:
    result = await session.execute(
        select(Tag).where(Tag.user_id == user_id, Tag.deleted_at.is_(None)).order_by(Tag.name)
    )
    return list(result.scalars().all())


async def get_tag(session: AsyncSession, user_id: UUID, tag_id: UUID) -> Tag | None:
    result = await session.execute(
        select(Tag).where(
            Tag.id == tag_id,
            Tag.user_id == user_id,
            Tag.deleted_at.is_(None),
        )
    )
    return result.scalar_one_or_none()


async def create_tag(
    session: AsyncSession,
    user_id: UUID,
    payload: TagCreate,
) -> Tag:
    """Create a tag,name 全局去重(同用户内同名活跃标签返回既有行)。"""
    existing = await session.execute(
        select(Tag).where(
            Tag.user_id == user_id,
            Tag.name == payload.name,
            Tag.deleted_at.is_(None),
        )
    )
    found = existing.scalar_one_or_none()
    if found is not None:
        return found

    tag = Tag(user_id=user_id, name=payload.name, color=payload.color)
    session.add(tag)
    await session.commit()
    await session.refresh(tag)
    return tag


async def update_tag(session: AsyncSession, tag: Tag, payload: TagUpdate) -> Tag:
    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(tag, key, value)
    await session.commit()
    await session.refresh(tag)
    return tag


async def soft_delete_tag(session: AsyncSession, tag: Tag) -> None:
    tag.deleted_at = datetime.now(UTC)
    await session.commit()


async def list_tags_for_task(
    session: AsyncSession,
    user_id: UUID,
    task_id: UUID,
) -> list[Tag]:
    result = await session.execute(
        select(Tag)
        .join(TaskTag, TaskTag.tag_id == Tag.id)
        .where(
            Tag.user_id == user_id,
            Tag.deleted_at.is_(None),
            TaskTag.task_id == task_id,
        )
        .order_by(Tag.name)
    )
    return list(result.scalars().all())


async def add_tag_to_task(
    session: AsyncSession,
    task_id: UUID,
    tag_id: UUID,
) -> None:
    """Idempotent insert into task_tags."""
    existing = await session.execute(
        select(TaskTag).where(
            TaskTag.task_id == task_id,
            TaskTag.tag_id == tag_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        return
    session.add(TaskTag(task_id=task_id, tag_id=tag_id))
    await session.commit()


async def remove_tag_from_task(
    session: AsyncSession,
    task_id: UUID,
    tag_id: UUID,
) -> None:
    result = await session.execute(
        select(TaskTag).where(
            TaskTag.task_id == task_id,
            TaskTag.tag_id == tag_id,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        return
    await session.delete(row)
    await session.commit()
