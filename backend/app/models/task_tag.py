"""TaskTag association table.

任务 ↔ 标签多对多关联,无独立同步元数据,变更跟随 Task / Tag 自身。
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TaskTag(Base):
    __tablename__ = "task_tags"

    task_id: Mapped[UUID] = mapped_column(
        Uuid(),
        ForeignKey("tasks.id", ondelete="CASCADE"),
        primary_key=True,
    )
    tag_id: Mapped[UUID] = mapped_column(
        Uuid(),
        ForeignKey("tags.id", ondelete="CASCADE"),
        primary_key=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
