"""Achievement business logic + evaluator.

评估器设计:
- 每次相关事件发生(任务完成 / 专注会话创建)后调用 ``evaluate(db, user_id)``。
- 遍历所有未解锁成就,按 criteria.type 分派到对应计数函数,满足 threshold 则写入
  user_achievements。
- 幂等:重复调用安全,已解锁的成就不再重复写入。
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.achievement import Achievement, UserAchievement
from app.models.focus_session import FocusSession
from app.models.task import Task

# ─────────────────────────────────────────────────────────────────────────────
# Read helpers
# ─────────────────────────────────────────────────────────────────────────────


async def list_achievements(session: AsyncSession) -> list[Achievement]:
    result = await session.execute(select(Achievement).order_by(Achievement.created_at))
    return list(result.scalars().all())


async def list_user_achievements(
    session: AsyncSession, user_id: UUID
) -> list[tuple[Achievement, UserAchievement]]:
    """返回该用户已解锁的 (Achievement, UserAchievement) 对。"""
    result = await session.execute(
        select(Achievement, UserAchievement)
        .join(UserAchievement, Achievement.id == UserAchievement.achievement_id)
        .where(UserAchievement.user_id == user_id)
        .order_by(UserAchievement.unlocked_at.desc())
    )
    return [(row[0], row[1]) for row in result.all()]


# ─────────────────────────────────────────────────────────────────────────────
# Evaluator
# ─────────────────────────────────────────────────────────────────────────────


async def evaluate(session: AsyncSession, user_id: UUID) -> list[Achievement]:
    """评估并解锁所有满足条件但尚未解锁的成就。返回本次新解锁的列表。"""
    # 已解锁的 achievement_id 集合
    unlocked_ids_result = await session.execute(
        select(UserAchievement.achievement_id).where(
            UserAchievement.user_id == user_id
        )
    )
    unlocked_ids = {row[0] for row in unlocked_ids_result.all()}

    all_achievements = await list_achievements(session)
    newly_unlocked: list[Achievement] = []

    for ach in all_achievements:
        if ach.id in unlocked_ids:
            continue

        criteria = json.loads(ach.criteria)
        unlocked = await _check(session, user_id, criteria)
        if unlocked:
            session.add(
                UserAchievement(
                    user_id=user_id,
                    achievement_id=ach.id,
                    unlocked_at=datetime.now(UTC),
                )
            )
            newly_unlocked.append(ach)

    if newly_unlocked:
        await session.flush()

    return newly_unlocked


async def _check(
    session: AsyncSession, user_id: UUID, criteria: dict[str, Any]
) -> bool:
    ctype = criteria.get("type")
    threshold: int = int(criteria.get("threshold", 1))

    if ctype == "tasks_completed":
        count = await _count_completed_tasks(session, user_id)
        return count >= threshold

    if ctype == "streak_days":
        streak = await _calc_streak(session, user_id)
        return streak >= threshold

    if ctype == "focus_sessions":
        count = await _count_focus_sessions(session, user_id)
        return count >= threshold

    if ctype == "daily_focus_minutes":
        minutes = await _today_focus_minutes(session, user_id)
        return minutes >= threshold

    return False


# ─────────────────────────────────────────────────────────────────────────────
# Metric queries
# ─────────────────────────────────────────────────────────────────────────────


async def _count_completed_tasks(session: AsyncSession, user_id: UUID) -> int:
    result = await session.execute(
        select(func.count()).where(
            Task.user_id == user_id,
            Task.completed_at.is_not(None),
            Task.deleted_at.is_(None),
        )
    )
    return result.scalar_one()


async def _calc_streak(session: AsyncSession, user_id: UUID) -> int:
    """连续完成任务的天数(UTC 日期)。"""
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

    from datetime import date, timedelta

    today = date.today()
    streak = 0
    cursor = today
    for d in dates:
        if isinstance(d, str):
            d = date.fromisoformat(d)
        if d == cursor or d == cursor - timedelta(days=1):
            if d < cursor:
                cursor = d
            streak += 1
        else:
            break
    return streak


async def _count_focus_sessions(session: AsyncSession, user_id: UUID) -> int:
    result = await session.execute(
        select(func.count()).where(
            FocusSession.user_id == user_id,
            FocusSession.completed == True,  # noqa: E712
        )
    )
    return result.scalar_one()


async def _today_focus_minutes(session: AsyncSession, user_id: UUID) -> int:
    from datetime import date, timedelta

    today_start = datetime.combine(date.today(), datetime.min.time()).replace(
        tzinfo=UTC
    )
    today_end = today_start + timedelta(days=1)

    result = await session.execute(
        select(func.coalesce(func.sum(FocusSession.duration_seconds), 0)).where(
            FocusSession.user_id == user_id,
            FocusSession.started_at >= today_start,
            FocusSession.started_at < today_end,
            FocusSession.duration_seconds.is_not(None),
        )
    )
    total_seconds = result.scalar_one()
    return int(total_seconds or 0) // 60
