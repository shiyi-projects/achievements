"""add recurrence override columns to tasks

为重复任务「模板 + 虚拟展开」模型增加两列:
- recurrence_parent_id: override 实体指回其重复模板(自引用 FK,nullable,index)
- occurrence_date: override 对应系列里的哪个发生点(去重锚点)

repeat_rule 列在初始迁移已存在,本次不动。展开/提醒全在客户端,后端仅存储+同步。
详见 dev_docs/recurring-tasks.md。

Revision ID: a7c3e9d12f84
Revises: e3f1a2b4c5d6
Create Date: 2026-06-05 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "a7c3e9d12f84"
down_revision: str | Sequence[str] | None = "e3f1a2b4c5d6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column(
            "recurrence_parent_id",
            sa.Uuid(),
            sa.ForeignKey("tasks.id", ondelete="CASCADE"),
            nullable=True,
        ),
    )
    op.add_column(
        "tasks",
        sa.Column("occurrence_date", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_tasks_recurrence_parent_id",
        "tasks",
        ["recurrence_parent_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_tasks_recurrence_parent_id", table_name="tasks")
    op.drop_column("tasks", "occurrence_date")
    op.drop_column("tasks", "recurrence_parent_id")
