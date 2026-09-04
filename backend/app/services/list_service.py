"""System list seeding.

清单的读写一律走 ``/sync``(客户端 local-first),这里只留启动期 / 登录期的
系统清单幂等种入。
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select, text
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.system_lists import (
    LEGACY_SYSTEM_LIST_IDS,
    SYSTEM_LIST_DISPLAY_NAMES,
    SystemListKind,
    system_list_id_for_user,
)
from app.models import Task, TaskList


async def ensure_system_lists(session: AsyncSession, user_id: UUID) -> None:
    """Idempotent seed of the 7 built-in system lists for ``user_id``.

    多用户模式下系统清单主键按 ``user_id + system_kind`` 确定性生成。
    若发现旧固定 UUID 或更早的随机 UUID,先迁移 tasks 引用,再更新
    task_lists.id。
    """
    for index, kind in enumerate(SystemListKind):
        desired_id = system_list_id_for_user(user_id, kind)
        legacy_id = LEGACY_SYSTEM_LIST_IDS[kind]
        result = await session.execute(
            select(TaskList).where(
                TaskList.user_id == user_id,
                TaskList.system_kind == kind.value,
            )
        )
        rows = list(result.scalars().all())
        desired_row = next((item for item in rows if item.id == desired_id), None)
        if desired_row is None:
            legacy_row = await session.get(TaskList, legacy_id)
            source = rows[0] if rows else legacy_row
            if source is None or source.user_id != user_id:
                session.add(
                    TaskList(
                        id=desired_id,
                        user_id=user_id,
                        name=SYSTEM_LIST_DISPLAY_NAMES[kind],
                        is_system=True,
                        system_kind=kind.value,
                        sort_order=index,
                    )
                )
                continue
            await session.execute(
                text("UPDATE task_lists SET system_kind = NULL WHERE id = :id"),
                {"id": source.id},
            )
            source.system_kind = None
            session.add(
                TaskList(
                    id=desired_id,
                    user_id=user_id,
                    name=source.name,
                    parent_id=source.parent_id,
                    color=source.color,
                    icon=source.icon,
                    sort_order=source.sort_order,
                    is_system=True,
                    system_kind=kind.value,
                )
            )
            await session.flush()
            await session.execute(
                sa_update(Task).where(Task.list_id == source.id).values(list_id=desired_id)
            )
            await session.delete(source)
            desired_row = await session.get(TaskList, desired_id)
        for duplicate in rows:
            if desired_row is not None and duplicate.id != desired_row.id:
                await session.execute(
                    sa_update(Task)
                    .where(Task.list_id == duplicate.id)
                    .values(list_id=desired_row.id)
                )
                await session.delete(duplicate)
        legacy_row = await session.get(TaskList, legacy_id)
        if legacy_row is not None and legacy_row.user_id == user_id and legacy_row.id != desired_id:
            await session.execute(
                sa_update(Task).where(Task.list_id == legacy_row.id).values(list_id=desired_id)
            )
            await session.delete(legacy_row)
    await session.commit()
