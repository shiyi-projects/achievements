"""Per-entity payload schemas for `/sync/push` mutations.

每个实体都允许部分字段缺省(对应客户端只改了某几列的语义)。Pydantic 自动把
ISO 字符串解析成 datetime,把字符串 UUID 解析成 UUID,无需手动 coerce。
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class _Base(BaseModel):
    model_config = ConfigDict(extra="ignore")


class FolderPayload(_Base):
    name: str | None = None
    sort_order: int | None = None
    deleted_at: datetime | None = None


class TaskListPayload(_Base):
    folder_id: UUID | None = None
    name: str | None = None
    color: str | None = None
    icon: str | None = None
    sort_order: int | None = None
    is_system: bool | None = None
    system_kind: str | None = None
    deleted_at: datetime | None = None


class TaskPayload(_Base):
    list_id: UUID | None = None
    parent_id: UUID | None = None
    title: str | None = None
    notes: str | None = None
    priority: int | None = None
    due_at: datetime | None = None
    remind_at: datetime | None = None
    repeat_rule: str | None = None
    color: str | None = None
    sort_order: int | None = None
    completed_at: datetime | None = None
    archived_at: datetime | None = None
    starred: bool | None = None
    deleted_at: datetime | None = None


class TagPayload(_Base):
    name: str | None = None
    color: str | None = None
    deleted_at: datetime | None = None


class TaskTagPayload(_Base):
    """关联表用复合键 (task_id, tag_id) 定位,不走 Mutation.id。

    upsert:建立关联(幂等);delete:置 deleted_at 墓碑。两个键在 upsert/delete
    时都必填。
    """

    task_id: UUID
    tag_id: UUID
