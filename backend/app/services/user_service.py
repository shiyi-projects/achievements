"""User identity mapping service."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.scc_auth import SccClientClaims
from app.models import User


async def get_user_by_id(session: AsyncSession, user_id: UUID) -> User | None:
    result = await session.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def upsert_scc_user(
    session: AsyncSession,
    claims: SccClientClaims,
    *,
    nickname: str | None = None,
    avatar_url: str | None = None,
) -> User:
    """Create or update the internal Achievements user for a SCC identity.

    Keyed on the SCC subject (``AppUser.id``), stable and unique within this app.
    ``nickname``/``avatar_url`` come from the login response and are only present at
    login time; per-request calls pass ``None`` and must not overwrite stored values.
    """
    result = await session.execute(
        select(User).where(
            User.provider == "scc",
            User.provider_user_id == claims.sub,
        )
    )
    user = result.scalar_one_or_none()
    now = datetime.now(UTC)
    if user is None:
        user = User(
            provider="scc",
            provider_user_id=claims.sub,
            role="member",
            created_at=now,
            updated_at=now,
        )
        session.add(user)

    if claims.openid:
        user.openid = claims.openid
    if claims.unionid:
        user.unionid = claims.unionid
    if nickname is not None:
        user.nickname = nickname
    if avatar_url is not None:
        user.avatar_url = avatar_url
    user.last_seen_at = now
    user.updated_at = now
    await session.flush()
    await session.refresh(user)
    return user
