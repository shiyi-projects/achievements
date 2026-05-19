"""Stats REST endpoints."""

from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUserId
from app.db.session import get_session
from app.services import stats_service

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get("/overview")
async def overview(session: SessionDep, user_id: CurrentUserId) -> dict[str, Any]:
    """总览:完成任务数、今日完成、连续天数、累计专注分钟。"""
    return await stats_service.get_overview(session, user_id)


@router.get("/heatmap")
async def heatmap(
    session: SessionDep,
    user_id: CurrentUserId,
    days: Annotated[int, Query(ge=7, le=365)] = 365,
) -> list[dict[str, Any]]:
    """日历热力图:最近 N 天每天完成任务数。"""
    return await stats_service.get_heatmap(session, user_id, days=days)


@router.get("/focus")
async def focus_stats(
    session: SessionDep,
    user_id: CurrentUserId,
    days: Annotated[int, Query(ge=7, le=90)] = 30,
) -> dict[str, Any]:
    """专注统计:每日时长柱状图 + 汇总。"""
    return await stats_service.get_focus_stats(session, user_id, days=days)


@router.get("/trends")
async def trends(
    session: SessionDep,
    user_id: CurrentUserId,
    days: Annotated[int, Query(ge=7, le=90)] = 30,
) -> list[dict[str, Any]]:
    """完成趋势:每日完成数与新建数折线图数据。"""
    return await stats_service.get_trends(session, user_id, days=days)
