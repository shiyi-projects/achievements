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
    # 先消重再建索引,否则旧库里已有的重复行会让 CREATE UNIQUE INDEX 失败。
    # 策略:每个 (user_id, system_kind) 留 created_at 最早一条(keeper),把所有
    # 指向 duplicate 的 tasks.list_id 改写到 keeper,然后删 duplicate 行。
    # 直接 DELETE 会被 tasks.list_id ON DELETE CASCADE 级联干掉用户任务。
    op.execute(
        sa.text(
            """
            CREATE TEMPORARY TABLE _dup_system_lists AS
            SELECT tl.id AS dup_id,
                   (SELECT k.id FROM task_lists k
                     WHERE k.user_id = tl.user_id
                       AND k.system_kind = tl.system_kind
                       AND k.deleted_at IS NULL
                     ORDER BY k.created_at ASC LIMIT 1) AS keeper_id
            FROM task_lists tl
            WHERE tl.deleted_at IS NULL AND tl.system_kind IS NOT NULL
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE tasks
               SET list_id = (SELECT keeper_id FROM _dup_system_lists
                               WHERE dup_id = tasks.list_id)
             WHERE list_id IN (SELECT dup_id FROM _dup_system_lists
                                WHERE dup_id <> keeper_id)
            """
        )
    )
    op.execute(
        sa.text(
            """
            DELETE FROM task_lists
             WHERE id IN (SELECT dup_id FROM _dup_system_lists
                           WHERE dup_id <> keeper_id)
            """
        )
    )
    op.execute(sa.text("DROP TABLE _dup_system_lists"))

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
