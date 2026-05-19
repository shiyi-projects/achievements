"""TaskList ORM model.

清单。`is_system = True` 表示内置清单(Today / Important / Inbox 等),由
启动期 lifespan 的 ``ensure_system_lists`` 幂等种入,不可删除。
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base import SyncableMixin


class TaskList(Base, SyncableMixin):
    __tablename__ = "task_lists"

    folder_id: Mapped[UUID | None] = mapped_column(
        Uuid(),
        ForeignKey("folders.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    color: Mapped[str | None] = mapped_column(String(32), nullable=True)
    icon: Mapped[str | None] = mapped_column(String(32), nullable=True)
    sort_order: Mapped[int] = mapped_column(nullable=False, default=0, server_default="0")
    is_system: Mapped[bool] = mapped_column(nullable=False, default=False, server_default="0")
    system_kind: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
