"""Folder ORM model."""

from __future__ import annotations

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base import SyncableMixin


class Folder(Base, SyncableMixin):
    __tablename__ = "folders"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    sort_order: Mapped[int] = mapped_column(nullable=False, default=0, server_default="0")
