"""add unionid column to users

身份收口到 SCC 后,存储跨端统一身份锚点 unionid(可空,建索引)。
provider 默认值由 olib 改为 scc 仅在 ORM 层(Python default),不涉及 DDL。
详见 dev_docs/refs/software_control_center.md。

Revision ID: f1e2d3c4b5a6
Revises: a7c3e9d12f84
Create Date: 2026-07-07 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "f1e2d3c4b5a6"
down_revision: str | Sequence[str] | None = "a7c3e9d12f84"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("unionid", sa.String(length=128), nullable=True),
    )
    op.create_index("ix_users_unionid", "users", ["unionid"])


def downgrade() -> None:
    op.drop_index("ix_users_unionid", table_name="users")
    op.drop_column("users", "unionid")
