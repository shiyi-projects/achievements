"""unique system_kind per user on task_lists

Revision ID: d6579144a12c
Revises: 812c3a51638e
Create Date: 2026-05-19 15:48:24.991261

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d6579144a12c"
down_revision: str | Sequence[str] | None = "812c3a51638e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


INDEX_NAME = "uq_task_lists_user_system_kind_active"


def upgrade() -> None:
    """Upgrade schema."""
    # 同一 user 同一 system_kind 只能有一行(忽略软删行),防止 seed 重复落地。
    op.create_index(
        INDEX_NAME,
        "task_lists",
        ["user_id", "system_kind"],
        unique=True,
        postgresql_where=sa.text("deleted_at IS NULL AND system_kind IS NOT NULL"),
        sqlite_where=sa.text("deleted_at IS NULL AND system_kind IS NOT NULL"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(INDEX_NAME, table_name="task_lists")
