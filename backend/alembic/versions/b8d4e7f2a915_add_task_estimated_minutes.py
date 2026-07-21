"""add tasks.estimated_minutes

客户端一直在 sync push payload 里携带 estimated_minutes(预估工时,智能专注
规划用),但服务端无此列、payload schema 也无此字段,被静默丢弃——换设备后
预估工时丢失。补列使其全链路同步。

Revision ID: b8d4e7f2a915
Revises: f1e2d3c4b5a6
Create Date: 2026-07-21 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "b8d4e7f2a915"
down_revision: str | Sequence[str] | None = "f1e2d3c4b5a6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "tasks",
        sa.Column("estimated_minutes", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("tasks", "estimated_minutes")
