"""Task ORM model.

含自引用 parent_id 支持子任务无限嵌套。
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.base import SyncableMixin


class Task(Base, SyncableMixin):
    __tablename__ = "tasks"

    list_id: Mapped[UUID] = mapped_column(
        Uuid(),
        ForeignKey("task_lists.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    parent_id: Mapped[UUID | None] = mapped_column(
        Uuid(),
        ForeignKey("tasks.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )

    title: Mapped[str] = mapped_column(String(500), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # 0=none, 1=low, 2=medium, 3=high
    priority: Mapped[int] = mapped_column(nullable=False, default=0, server_default="0")

    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    remind_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # RFC5545 RRULE 主体(不含 DTSTART)。非空表示重复系列模板,DTSTART 由 due_at 提供。
    repeat_rule: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # override 实体指回其重复模板;模板自身与普通任务为 null。仅存储/同步,展开在客户端。
    recurrence_parent_id: Mapped[UUID | None] = mapped_column(
        Uuid(),
        ForeignKey("tasks.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    # override 对应系列里的哪个发生点(去重锚点)。
    occurrence_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    color: Mapped[str | None] = mapped_column(String(32), nullable=True)
    sort_order: Mapped[int] = mapped_column(nullable=False, default=0, server_default="0")
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    starred: Mapped[bool] = mapped_column(nullable=False, default=False, server_default="0")
    # 预估总工时(分钟),智能专注规划用。客户端一直随 upsert 推送,此前服务端
    # 无此列被静默丢弃,导致换设备后预估工时丢失。
    estimated_minutes: Mapped[int | None] = mapped_column(nullable=True)
    # 级联删除的来源清单。随清单一起进回收站的任务记下那个清单,用户单独删除的
    # 任务恒为 null;回收站据此把一个清单连同它的内容当作整体还原。
    trashed_with: Mapped[UUID | None] = mapped_column(
        Uuid(),
        ForeignKey("task_lists.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
