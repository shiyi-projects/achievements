"""Shared FastAPI dependencies.

Phase 0:鉴权未启用,所有请求归属固定的 local-user。
后续启用 JWT 时,在此模块替换 `get_current_user_id` 的实现即可。
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import Depends

from app.core.config import Settings, get_settings


def get_current_user_id(
    settings: Annotated[Settings, Depends(get_settings)],
) -> UUID:
    """Return the active user id.

    Placeholder for Phase 0:始终返回 settings.local_user_id。
    """
    return UUID(settings.local_user_id)


CurrentUserId = Annotated[UUID, Depends(get_current_user_id)]
