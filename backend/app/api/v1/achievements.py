"""Achievement REST endpoints."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUserId
from app.db.session import get_session
from app.schemas.achievement import AchievementRead, UserAchievementRead
from app.services import achievement_service

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get("", response_model=list[AchievementRead])
async def list_achievements(session: SessionDep) -> list[AchievementRead]:
    """返回所有成就定义(不限用户)。"""
    rows = await achievement_service.list_achievements(session)
    return [AchievementRead.model_validate(r) for r in rows]


@router.get("/me", response_model=list[UserAchievementRead])
async def my_achievements(
    session: SessionDep,
    user_id: CurrentUserId,
) -> list[UserAchievementRead]:
    """返回当前用户已解锁的成就,按解锁时间倒序。"""
    pairs = await achievement_service.list_user_achievements(session, user_id)
    return [
        UserAchievementRead(
            id=ach.id,
            code=ach.code,
            name=ach.name,
            description=ach.description,
            icon=ach.icon,
            unlocked_at=ua.unlocked_at,
        )
        for ach, ua in pairs
    ]
