"""Task DTOs."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TaskCreate(BaseModel):
    list_id: UUID
    parent_id: UUID | None = None
    title: str = Field(min_length=1, max_length=500)
    notes: str | None = None
    priority: int = Field(default=0, ge=0, le=3)
    due_at: datetime | None = None
    remind_at: datetime | None = None
    repeat_rule: str | None = Field(default=None, max_length=255)
    recurrence_parent_id: UUID | None = None
    occurrence_date: datetime | None = None
    color: str | None = None
    starred: bool = False


class TaskUpdate(BaseModel):
    list_id: UUID | None = None
    parent_id: UUID | None = None
    title: str | None = Field(default=None, min_length=1, max_length=500)
    notes: str | None = None
    priority: int | None = Field(default=None, ge=0, le=3)
    due_at: datetime | None = None
    remind_at: datetime | None = None
    repeat_rule: str | None = Field(default=None, max_length=255)
    recurrence_parent_id: UUID | None = None
    occurrence_date: datetime | None = None
    color: str | None = None
    starred: bool | None = None


class TaskCompleteRequest(BaseModel):
    completed: bool


class TaskRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    list_id: UUID
    parent_id: UUID | None
    title: str
    notes: str | None
    priority: int
    due_at: datetime | None
    remind_at: datetime | None
    repeat_rule: str | None
    recurrence_parent_id: UUID | None
    occurrence_date: datetime | None
    color: str | None
    sort_order: int
    completed_at: datetime | None
    archived_at: datetime | None
    starred: bool
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None
    purged_at: datetime | None
    version: int
