"""Achievement ORM models."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base import TimestampMixin, UUIDPKMixin


class Achievement(Base, UUIDPKMixin, TimestampMixin):
    """成就定义(种子数据,不可由用户修改)。"""

    __tablename__ = "achievements"

    # 稳定的字符串标识,用于业务逻辑判断(e.g. 'first_task')
    code: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    icon: Mapped[str] = mapped_column(String(64), nullable=False, default="🏆")
    # JSON: {"type": "tasks_completed", "threshold": 10}
    criteria: Mapped[str] = mapped_column(Text, nullable=False)


class UserAchievement(Base):
    """用户成就解锁记录。"""

    __tablename__ = "user_achievements"

    user_id: Mapped[UUID] = mapped_column(Uuid(), nullable=False, primary_key=True)
    achievement_id: Mapped[UUID] = mapped_column(
        Uuid(),
        ForeignKey("achievements.id", ondelete="CASCADE"),
        nullable=False,
        primary_key=True,
    )
    unlocked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
