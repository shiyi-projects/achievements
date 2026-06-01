"""TaskList DTOs."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TaskListCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    folder_id: UUID | None = None
    color: str | None = None
    icon: str | None = None
    sort_order: int = 0


class TaskListUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    folder_id: UUID | None = None
    color: str | None = None
    icon: str | None = None
    sort_order: int | None = None


class TaskListRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    folder_id: UUID | None
    name: str
    color: str | None
    icon: str | None
    sort_order: int
    is_system: bool
    system_kind: str | None
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    purged_at: datetime | None
    version: int
