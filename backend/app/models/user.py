"""Authenticated Achievements user identity mapping."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base import TimestampMixin, UUIDPKMixin


class User(Base, UUIDPKMixin, TimestampMixin):
    """Internal user mapped from an external identity provider.

    Domain tables keep using this row's UUID as ``user_id``. The current
    provider is SCC (软件控制中心), whose ``AppUser.id`` is stored in
    ``provider_user_id`` and cross-end anchor ``unionid`` in ``unionid``.
    """

    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("provider", "provider_user_id", name="uq_users_provider_user_id"),
    )

    provider: Mapped[str] = mapped_column(String(32), nullable=False, default="scc")
    provider_user_id: Mapped[str] = mapped_column(String(64), nullable=False)
    openid: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    unionid: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    device_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    nickname: Mapped[str | None] = mapped_column(String(128), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    platform: Mapped[str | None] = mapped_column(String(32), nullable=True)
    role: Mapped[str] = mapped_column(String(32), nullable=False, default="authorized")
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
