"""清单树的结构约束。

清单是一棵自引用树(``task_lists.parent_id``)。客户端在写入前会自行校验,
这里是服务端兜底 —— 同步请求可能来自任何版本的客户端,树的形状必须由服务端
最终把关,否则一次错误的 ``parent_id`` 会在所有设备上留下成环或过深的结构。
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import TaskList

# 清单树最大层数(顶层记 1)。与前端 `kMaxListDepth` 必须一致。
MAX_LIST_DEPTH = 3


async def validate_parent(
    session: AsyncSession,
    *,
    user_id: UUID,
    list_id: UUID,
    parent_id: UUID | None,
) -> bool:
    """把 ``list_id`` 挂到 ``parent_id`` 之下是否合法。

    拒绝三种情况:父清单不存在 / 不属于该用户 / 是系统清单;父清单落在自己的
    子树里(成环);挂上去之后整棵子树超过 [MAX_LIST_DEPTH] 层。
    """
    if parent_id is None:
        return True
    if parent_id == list_id:
        return False

    rows = (
        await session.execute(
            select(TaskList.id, TaskList.parent_id, TaskList.is_system).where(
                TaskList.user_id == user_id
            )
        )
    ).all()
    parent_of: dict[UUID, UUID | None] = {row.id: row.parent_id for row in rows}
    is_system: dict[UUID, bool] = {row.id: row.is_system for row in rows}

    if parent_id not in parent_of or is_system.get(parent_id, False):
        return False

    children: dict[UUID | None, list[UUID]] = {}
    for child, parent in parent_of.items():
        children.setdefault(parent, []).append(child)

    if parent_id in _subtree(list_id, children):
        return False

    return _depth(parent_id, parent_of) + _height(list_id, children) <= MAX_LIST_DEPTH


def _subtree(root: UUID, children: dict[UUID | None, list[UUID]]) -> set[UUID]:
    seen = {root}
    frontier = [root]
    while frontier:
        nxt = [c for node in frontier for c in children.get(node, []) if c not in seen]
        seen.update(nxt)
        frontier = nxt
    return seen


def _depth(node: UUID, parent_of: dict[UUID, UUID | None]) -> int:
    """顶层记 1。数据异常成环时截断,让校验走向「拒绝」而不是死循环。"""
    depth = 1
    cursor = parent_of.get(node)
    while cursor is not None and depth <= MAX_LIST_DEPTH:
        depth += 1
        cursor = parent_of.get(cursor)
    return depth


def _height(
    node: UUID,
    children: dict[UUID | None, list[UUID]],
    seen: frozenset[UUID] = frozenset(),
) -> int:
    """子树高度:只有自身为 1,带一层子清单为 2,以此类推。

    ``seen`` 挡住已损坏数据里的环,避免无限递归。
    """
    if node in seen:
        return 1
    height = 1
    for child in children.get(node, []):
        height = max(height, 1 + _height(child, children, seen | {node}))
    return height
