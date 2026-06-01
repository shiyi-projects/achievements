"""add purge tombstone (purged_at) and task_tag sync metadata

为可同步实体增加永久删除墓碑 purged_at(folders / task_lists / tasks / tags),
并给关联表 task_tags 补同步元数据 updated_at + deleted_at,以支持"取消打标签"
跨端同步与永久删除的墓碑传播 + 惰性 GC。

Revision ID: e3f1a2b4c5d6
Revises: d2b7c8e9f101
Create Date: 2026-06-01 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "e3f1a2b4c5d6"
down_revision: str | Sequence[str] | None = "d2b7c8e9f101"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_PURGE_TABLES = ("folders", "task_lists", "tasks", "tags")


def upgrade() -> None:
    # 1) 四张可同步表增加永久删除墓碑列
    for table in _PURGE_TABLES:
        op.add_column(
            table,
            sa.Column("purged_at", sa.DateTime(timezone=True), nullable=True),
        )

    # 2) task_tags 增加同步元数据:updated_at(增量游标)+ deleted_at(删除墓碑)
    op.add_column(
        "task_tags",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.add_column(
        "task_tags",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    # 既有关联行用 created_at 回填 updated_at,避免迁移后被误判为"刚改过"
    op.execute("UPDATE task_tags SET updated_at = created_at")


def downgrade() -> None:
    op.drop_column("task_tags", "deleted_at")
    op.drop_column("task_tags", "updated_at")
    for table in _PURGE_TABLES:
        op.drop_column(table, "purged_at")
