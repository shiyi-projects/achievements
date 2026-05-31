"""user scoped system list ids

Revision ID: d2b7c8e9f101
Revises: c1a2b3d4e5f6
Create Date: 2026-05-29 00:10:00.000000

"""

from collections.abc import Sequence
from uuid import UUID, uuid5

import sqlalchemy as sa

from alembic import op

revision: str = "d2b7c8e9f101"
down_revision: str | Sequence[str] | None = "c1a2b3d4e5f6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_NAMESPACE = UUID("4c57f2ec-6db5-5c34-a7b0-6f6c2a8c5d2f")
_KINDS = ("inbox", "today", "important", "planned", "all", "completed", "trash")
_LEGACY_IDS = {
    "inbox": UUID("01900000-0000-7000-8000-000000000001"),
    "today": UUID("01900000-0000-7000-8000-000000000002"),
    "important": UUID("01900000-0000-7000-8000-000000000003"),
    "planned": UUID("01900000-0000-7000-8000-000000000004"),
    "all": UUID("01900000-0000-7000-8000-000000000005"),
    "completed": UUID("01900000-0000-7000-8000-000000000006"),
    "trash": UUID("01900000-0000-7000-8000-000000000007"),
}


def _desired(user_id: UUID, kind: str) -> UUID:
    return uuid5(_NAMESPACE, f"{user_id}:{kind}")


def upgrade() -> None:
    bind = op.get_bind()
    rows = (
        bind.execute(
            sa.text(
                "SELECT id, user_id, system_kind, deleted_at "
                "FROM task_lists WHERE system_kind IS NOT NULL"
            )
        )
        .mappings()
        .all()
    )
    for row in rows:
        kind = row["system_kind"]
        if kind not in _KINDS:
            continue
        old_id = row["id"]
        user_id = row["user_id"]
        was_active = row["deleted_at"] is None
        desired_id = _desired(UUID(str(user_id)), kind)
        if UUID(str(old_id)) == desired_id:
            continue
        existing = bind.execute(
            sa.text("SELECT id FROM task_lists WHERE id = :id"), {"id": desired_id}
        ).first()
        inserted = existing is None
        if inserted:
            # 关键:目标行先以"软删占位"(deleted_at=now())插入。
            # uq_task_lists_user_system_kind_active 是仅约束 active 行的部分唯一索引,
            # 软删占位行不进入索引,因此能与仍是 active 的旧行并存而不冲突。
            # (旧实现直接以 active 插入,会与未删除的旧行撞唯一约束 → 升级失败。)
            bind.execute(
                sa.text(
                    """
                    INSERT INTO task_lists (
                        id, folder_id, name, color, icon, sort_order, is_system,
                        system_kind, user_id, created_at, updated_at, deleted_at, version
                    )
                    SELECT :new_id, folder_id, name, color, icon, sort_order, true,
                           system_kind, user_id, created_at, updated_at, now(), version
                      FROM task_lists
                     WHERE id = :old_id
                    """
                ),
                {"new_id": desired_id, "old_id": old_id},
            )
        # 目标行已存在,可被外键引用 → 把任务迁过去。
        bind.execute(
            sa.text("UPDATE tasks SET list_id = :new_id WHERE list_id = :old_id"),
            {"new_id": desired_id, "old_id": old_id},
        )
        # 任务已迁走,删除旧行(ON DELETE CASCADE 不会误删任务),释放 active 槽位。
        bind.execute(sa.text("DELETE FROM task_lists WHERE id = :old_id"), {"old_id": old_id})
        # 旧行原本是 active 且本次新建了占位行 → 旧行已删、槽位空出,恢复目标行为 active。
        if was_active and inserted:
            bind.execute(
                sa.text("UPDATE task_lists SET deleted_at = NULL WHERE id = :new_id"),
                {"new_id": desired_id},
            )


def downgrade() -> None:
    bind = op.get_bind()
    rows = (
        bind.execute(
            sa.text("SELECT id, user_id, system_kind FROM task_lists WHERE system_kind IS NOT NULL")
        )
        .mappings()
        .all()
    )
    for row in rows:
        kind = row["system_kind"]
        if kind not in _LEGACY_IDS:
            continue
        old_id = row["id"]
        legacy_id = _LEGACY_IDS[kind]
        existing = bind.execute(
            sa.text("SELECT id FROM task_lists WHERE id = :id"), {"id": legacy_id}
        ).first()
        bind.execute(
            sa.text("UPDATE tasks SET list_id = :new_id WHERE list_id = :old_id"),
            {"new_id": legacy_id, "old_id": old_id},
        )
        if existing is None:
            bind.execute(
                sa.text("UPDATE task_lists SET id = :new_id WHERE id = :old_id"),
                {"new_id": legacy_id, "old_id": old_id},
            )
        else:
            bind.execute(sa.text("DELETE FROM task_lists WHERE id = :old_id"), {"old_id": old_id})
