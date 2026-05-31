"""add users table

Revision ID: c1a2b3d4e5f6
Revises: b4e9f2c1a873
Create Date: 2026-05-29 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "c1a2b3d4e5f6"
down_revision: str | Sequence[str] | None = "b4e9f2c1a873"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("provider_user_id", sa.String(length=64), nullable=False),
        sa.Column("openid", sa.String(length=128), nullable=True),
        sa.Column("device_id", sa.String(length=64), nullable=True),
        sa.Column("nickname", sa.String(length=128), nullable=True),
        sa.Column("avatar_url", sa.String(length=500), nullable=True),
        sa.Column("platform", sa.String(length=32), nullable=True),
        sa.Column("role", sa.String(length=32), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("provider", "provider_user_id", name="uq_users_provider_user_id"),
    )
    op.create_index(op.f("ix_users_openid"), "users", ["openid"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_users_openid"), table_name="users")
    op.drop_table("users")
