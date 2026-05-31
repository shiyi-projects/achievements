"""User identity mapping service."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User
from app.schemas.auth import UserProfile

_ALLOWED_ROLES = {"authorized", "community", "admin"}


def is_allowed_role(role: str) -> bool:
    return role in _ALLOWED_ROLES


async def get_user_by_id(session: AsyncSession, user_id: UUID) -> User | None:
    result = await session.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def upsert_olib_user(
    session: AsyncSession,
    profile: UserProfile,
    *,
    device_id: str | None = None,
    platform: str | None = None,
) -> User:
    """Create or update the internal Achievements user for an OLib profile."""
    provider_user_id = str(profile.id)
    result = await session.execute(
        select(User).where(
            User.provider == "olib",
            User.provider_user_id == provider_user_id,
        )
    )
    user = result.scalar_one_or_none()
    now = datetime.now(UTC)
    if user is None:
        user = User(
            provider="olib",
            provider_user_id=provider_user_id,
            created_at=now,
            updated_at=now,
        )
        session.add(user)

    user.openid = profile.openid
    user.device_id = profile.device_id or device_id
    user.nickname = profile.nickname
    user.avatar_url = profile.avatar_url
    user.platform = profile.platform or platform
    user.role = profile.role
    user.last_seen_at = now
    user.updated_at = now
    await session.flush()
    await session.refresh(user)
    return user
