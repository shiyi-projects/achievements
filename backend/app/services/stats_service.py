"""统计聚合查询。

所有查询直接走 SQL,不做应用层聚合,以便后续迁移到 Postgres 物化视图。
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.focus_session import FocusSession
from app.models.task import Task

# ─────────────────────────────────────────────────────────────────────────────
# Overview
# ─────────────────────────────────────────────────────────────────────────────


async def get_overview(session: AsyncSession, user_id: UUID) -> dict[str, Any]:
    """总览:完成任务数、今日完成、连续天数、累计专注分钟。"""
    total_completed = (
        await session.scalar(
            select(func.count()).where(
                Task.user_id == user_id,
                Task.completed_at.is_not(None),
                Task.deleted_at.is_(None),
            )
        )
        or 0
    )

    today_start = _today_utc()
    today_completed = (
        await session.scalar(
            select(func.count()).where(
                Task.user_id == user_id,
                Task.completed_at >= today_start,
                Task.completed_at < today_start + timedelta(days=1),
                Task.deleted_at.is_(None),
            )
        )
        or 0
    )

    streak = await _streak_days(session, user_id)

    total_focus_minutes = (
        await session.scalar(
            select(func.coalesce(func.sum(FocusSession.duration_seconds), 0)).where(
                FocusSession.user_id == user_id,
                FocusSession.duration_seconds.is_not(None),
            )
        )
        or 0
    )

    return {
        "total_completed": total_completed,
        "today_completed": today_completed,
        "streak_days": streak,
        "total_focus_minutes": int(total_focus_minutes) // 60,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Heatmap (日历热力图)
# ─────────────────────────────────────────────────────────────────────────────


async def get_heatmap(
    session: AsyncSession,
    user_id: UUID,
    *,
    days: int = 365,
) -> list[dict[str, Any]]:
    """返回最近 N 天每天完成任务数,格式 [{date, count}]。"""
    since = _today_utc() - timedelta(days=days - 1)

    result = await session.execute(
        select(
            func.date(Task.completed_at).label("day"),
            func.count().label("count"),
        )
        .where(
            Task.user_id == user_id,
            Task.completed_at >= since,
            Task.completed_at.is_not(None),
            Task.deleted_at.is_(None),
        )
        .group_by(func.date(Task.completed_at))
        .order_by(func.date(Task.completed_at))
    )
    return [{"date": str(row.day), "count": row.count} for row in result.all()]


# ─────────────────────────────────────────────────────────────────────────────
# Focus stats
# ─────────────────────────────────────────────────────────────────────────────


async def get_focus_stats(
    session: AsyncSession,
    user_id: UUID,
    *,
    days: int = 30,
) -> dict[str, Any]:
    """返回最近 N 天专注统计:每日时长柱状图 + 汇总。"""
    since = _today_utc() - timedelta(days=days - 1)

    result = await session.execute(
        select(
            func.date(FocusSession.started_at).label("day"),
            func.count().label("sessions"),
            func.coalesce(func.sum(FocusSession.duration_seconds), 0).label("total_seconds"),
        )
        .where(
            FocusSession.user_id == user_id,
            FocusSession.started_at >= since,
            FocusSession.duration_seconds.is_not(None),
        )
        .group_by(func.date(FocusSession.started_at))
        .order_by(func.date(FocusSession.started_at))
    )
    daily = [
        {
            "date": str(row.day),
            "sessions": row.sessions,
            "minutes": int(row.total_seconds) // 60,
        }
        for row in result.all()
    ]

    total_sessions = sum(d["sessions"] for d in daily)
    total_minutes = sum(d["minutes"] for d in daily)
    avg_minutes = total_minutes // max(len(daily), 1)

    return {
        "daily": daily,
        "total_sessions": total_sessions,
        "total_minutes": total_minutes,
        "avg_minutes_per_day": avg_minutes,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Completion trends (折线图)
# ─────────────────────────────────────────────────────────────────────────────


async def get_trends(
    session: AsyncSession,
    user_id: UUID,
    *,
    days: int = 30,
) -> list[dict[str, Any]]:
    """返回最近 N 天每日完成任务数趋势,格式 [{date, completed, created}]。"""
    since = _today_utc() - timedelta(days=days - 1)

    completed_result = await session.execute(
        select(
            func.date(Task.completed_at).label("day"),
            func.count().label("count"),
        )
        .where(
            Task.user_id == user_id,
            Task.completed_at >= since,
            Task.completed_at.is_not(None),
            Task.deleted_at.is_(None),
        )
        .group_by(func.date(Task.completed_at))
    )
    completed_by_day = {str(row.day): row.count for row in completed_result.all()}

    created_result = await session.execute(
        select(
            func.date(Task.created_at).label("day"),
            func.count().label("count"),
        )
        .where(
            Task.user_id == user_id,
            Task.created_at >= since,
            Task.deleted_at.is_(None),
        )
        .group_by(func.date(Task.created_at))
    )
    created_by_day = {str(row.day): row.count for row in created_result.all()}

    # 填充每一天(包括无数据的天)
    trends = []
    for i in range(days):
        d = str((since + timedelta(days=i)).date())
        trends.append(
            {
                "date": d,
                "completed": completed_by_day.get(d, 0),
                "created": created_by_day.get(d, 0),
            }
        )
    return trends


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────


def _today_utc() -> datetime:
    today = date.today()
    return datetime(today.year, today.month, today.day, tzinfo=UTC)


async def _streak_days(session: AsyncSession, user_id: UUID) -> int:
    result = await session.execute(
        select(func.date(Task.completed_at))
        .where(
            Task.user_id == user_id,
            Task.completed_at.is_not(None),
            Task.deleted_at.is_(None),
        )
        .distinct()
        .order_by(func.date(Task.completed_at).desc())
    )
    dates = [row[0] for row in result.all()]
    if not dates:
        return 0

    today = date.today()
    streak = 0
    cursor = today
    for d in dates:
        if isinstance(d, str):
            d = date.fromisoformat(d)
        if d >= cursor - timedelta(days=1):
            streak += 1
            cursor = d
        else:
            break
    return streak
