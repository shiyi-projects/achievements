"""TaskList ORM model.

清单。`is_system = True` 表示内置清单(Today / Important / Inbox 等),由
启动期 lifespan 的 ``ensure_system_lists`` 幂等种入,不可删除。

用户清单是一棵自引用树(``parent_id``):任何清单都能直接装任务,也能装
子清单,深度上限见 ``app.core.list_tree.MAX_LIST_DEPTH``。旧的 ``folders``
表已并入本表(迁移 a1f4c7d92b30),每个文件夹变成一个顶层清单。
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base import SyncableMixin


class TaskList(Base, SyncableMixin):
    __tablename__ = "task_lists"

    parent_id: Mapped[UUID | None] = mapped_column(
        Uuid(),
        ForeignKey("task_lists.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    # 级联删除的来源清单。删清单时,被连带软删的后代清单与任务都记下发起删除的
    # 那个清单;用户单独删除的行恒为 null。回收站据此整体还原。
    trashed_with: Mapped[UUID | None] = mapped_column(
        Uuid(),
        ForeignKey("task_lists.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    color: Mapped[str | None] = mapped_column(String(32), nullable=True)
    icon: Mapped[str | None] = mapped_column(String(32), nullable=True)
    sort_order: Mapped[int] = mapped_column(nullable=False, default=0, server_default="0")
    is_system: Mapped[bool] = mapped_column(nullable=False, default=False, server_default="0")
    system_kind: Mapped[str | None] = mapped_column(String(32), nullable=True, index=True)
