"""FocusSession ORM model."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import Boolean, DateTime, Integer, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base import TimestampMixin, UUIDPKMixin


class FocusSession(Base, UUIDPKMixin, TimestampMixin):
    """专注会话记录。

    Phase 3 本地优先:前端 Drift 表已就绪,此端点负责云端持久化与统计聚合。
    刻意不加 version/soft_delete:会话是追加式日志,删除即硬删。
    """

    __tablename__ = "focus_sessions"

    user_id: Mapped[UUID] = mapped_column(Uuid(), nullable=False, index=True)

    # 关联任务(可选)
    task_id: Mapped[UUID | None] = mapped_column(Uuid(), nullable=True, index=True)

    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # 实际专注时长(秒),结束时写入
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # 'pomodoro' | 'free'
    mode: Mapped[str] = mapped_column(
        String(16), nullable=False, default="pomodoro", server_default="pomodoro"
    )

    # 是否完整完成(非中途放弃)
    completed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="0"
    )
