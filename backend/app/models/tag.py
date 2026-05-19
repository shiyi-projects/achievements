"""Tag ORM model."""

from __future__ import annotations

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base import SyncableMixin


class Tag(Base, SyncableMixin):
    __tablename__ = "tags"

    name: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    color: Mapped[str | None] = mapped_column(String(32), nullable=True)
