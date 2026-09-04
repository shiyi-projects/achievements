"""TaskList DTOs.

清单是一棵自引用树(``parent_id``)。没有 REST 端点,这些 DTO 供 ``/sync``
下发与冲突回包使用。
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class TaskListRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    parent_id: UUID | None
    name: str
    color: str | None
    icon: str | None
    sort_order: int
    is_system: bool
    system_kind: str | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    trashed_with: UUID | None
    purged_at: datetime | None
    version: int
