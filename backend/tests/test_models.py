"""Smoke tests:验证 ORM 模型可以创建并通过外键约束。"""

from __future__ import annotations

from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Tag, Task, TaskList, TaskTag

USER_ID = uuid4()


@pytest.mark.asyncio
async def test_nested_lists(session: AsyncSession) -> None:
    parent = TaskList(name="Work", user_id=USER_ID)
    session.add(parent)
    await session.commit()
    await session.refresh(parent)

    child = TaskList(name="Sprint", parent_id=parent.id, user_id=USER_ID)
    session.add(child)
    await session.commit()
    await session.refresh(child)

    assert child.parent_id == parent.id


@pytest.mark.asyncio
async def test_task_subtask_relation(session: AsyncSession) -> None:
    lst = TaskList(name="Inbox", user_id=USER_ID, is_system=True, system_kind="inbox")
    session.add(lst)
    await session.commit()
    await session.refresh(lst)

    parent = Task(title="Parent", list_id=lst.id, user_id=USER_ID)
    session.add(parent)
    await session.commit()
    await session.refresh(parent)

    child = Task(title="Child", list_id=lst.id, parent_id=parent.id, user_id=USER_ID)
    session.add(child)
    await session.commit()

    rows = (await session.execute(select(Task).where(Task.parent_id == parent.id))).scalars().all()
    assert len(rows) == 1
    assert rows[0].title == "Child"


@pytest.mark.asyncio
async def test_tag_many_to_many(session: AsyncSession) -> None:
    lst = TaskList(name="Inbox", user_id=USER_ID, is_system=True, system_kind="inbox")
    session.add(lst)
    await session.commit()
    await session.refresh(lst)

    task = Task(title="Read book", list_id=lst.id, user_id=USER_ID)
    tag = Tag(name="reading", user_id=USER_ID)
    session.add_all([task, tag])
    await session.commit()
    await session.refresh(task)
    await session.refresh(tag)

    session.add(TaskTag(task_id=task.id, tag_id=tag.id))
    await session.commit()

    assoc = (await session.execute(select(TaskTag))).scalars().all()
    assert len(assoc) == 1
    assert assoc[0].task_id == task.id
    assert assoc[0].tag_id == tag.id
