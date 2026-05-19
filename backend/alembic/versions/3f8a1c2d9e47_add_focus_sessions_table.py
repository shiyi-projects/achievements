"""add focus_sessions table

Revision ID: 3f8a1c2d9e47
Revises: d6579144a12c
Create Date: 2026-05-20 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "3f8a1c2d9e47"
down_revision: str | Sequence[str] | None = "d6579144a12c"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """创建 focus_sessions 表。"""
    op.create_table(
        "focus_sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("task_id", sa.Uuid(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("mode", sa.String(16), nullable=False, server_default="pomodoro"),
        sa.Column("completed", sa.Boolean(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_focus_sessions_user_id", "focus_sessions", ["user_id"])
    op.create_index("ix_focus_sessions_task_id", "focus_sessions", ["task_id"])
    op.create_index(
        "ix_focus_sessions_user_started",
        "focus_sessions",
        ["user_id", "started_at"],
        comment="统计聚合按日期范围扫描用",
    )


def downgrade() -> None:
    """删除 focus_sessions 表。"""
    op.drop_index("ix_focus_sessions_user_started", table_name="focus_sessions")
    op.drop_index("ix_focus_sessions_task_id", table_name="focus_sessions")
    op.drop_index("ix_focus_sessions_user_id", table_name="focus_sessions")
    op.drop_table("focus_sessions")
