"""Achievement DTOs."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class AchievementRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    code: str
    name: str
    description: str
    icon: str
    criteria: str  # raw JSON string


class UserAchievementRead(BaseModel):
    """成就 + 解锁时间,用于 /achievements/me 响应。"""

    id: UUID
    code: str
    name: str
    description: str
    icon: str
    unlocked_at: datetime
