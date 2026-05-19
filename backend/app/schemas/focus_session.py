"""FocusSession DTOs."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class FocusSessionCreate(BaseModel):
    id: UUID | None = None  # 客户端可预生成 UUIDv7
    task_id: UUID | None = None
    started_at: datetime
    ended_at: datetime | None = None
    duration_seconds: int | None = Field(default=None, ge=0)
    mode: str = Field(default="pomodoro", pattern="^(pomodoro|free)$")
    completed: bool = False


class FocusSessionUpdate(BaseModel):
    """结束会话时补全 ended_at / duration_seconds / completed。"""

    task_id: UUID | None = None
    ended_at: datetime | None = None
    duration_seconds: int | None = Field(default=None, ge=0)
    completed: bool | None = None


class FocusSessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    task_id: UUID | None
    started_at: datetime
    ended_at: datetime | None
    duration_seconds: int | None
    mode: str
    completed: bool
    created_at: datetime
    updated_at: datetime
