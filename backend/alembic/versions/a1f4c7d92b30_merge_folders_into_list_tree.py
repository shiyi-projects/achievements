"""merge folders into the task list tree

废除 ``folders`` 表:清单改为自引用树(``task_lists.parent_id``),任何清单都
能直接装任务、也能装子清单。每个文件夹变成一个顶层清单(沿用原 id,保证各端
同步主键不错位),原先挂在它下面的清单成为它的子清单。

同时新增 ``trashed_with``(task_lists / tasks):删清单时被连带软删的后代清单与
任务记下发起删除的那个清单,回收站据此把「一个清单连同它的全部内容」整体还原,
而不会顺带复活用户先前单独删掉的任务。

Revision ID: a1f4c7d92b30
Revises: b8d4e7f2a915
Create Date: 2026-09-04 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "a1f4c7d92b30"
down_revision: str | Sequence[str] | None = "b8d4e7f2a915"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # ── 1. 新列 ────────────────────────────────────────────────────────
    op.add_column("task_lists", sa.Column("parent_id", sa.Uuid(), nullable=True))
    op.add_column("task_lists", sa.Column("trashed_with", sa.Uuid(), nullable=True))
    op.add_column("tasks", sa.Column("trashed_with", sa.Uuid(), nullable=True))

    # ── 2. folder_id → parent_id,folders 各行落成顶层清单 ─────────────
    op.execute("UPDATE task_lists SET parent_id = folder_id WHERE folder_id IS NOT NULL")
    # sort_order 先落到负数段,保证迁移后仍排在原根清单之前(与旧 UI「文件夹
    # 恒在上」的视觉一致),下一步再统一重编号。
    op.execute(
        """
        INSERT INTO task_lists
            (id, user_id, name, sort_order, is_system,
             created_at, updated_at, deleted_at, purged_at, version)
        SELECT id, user_id, name, sort_order - 1000000, false,
               created_at, updated_at, deleted_at, purged_at, version
          FROM folders
        ON CONFLICT (id) DO NOTHING
        """
    )
    # 顶层用户清单(文件夹迁移来的 + 原根清单)重编号为连续序号。
    op.execute(
        """
        UPDATE task_lists AS t
           SET sort_order = ranked.rn
          FROM (
                SELECT id,
                       ROW_NUMBER() OVER (
                           PARTITION BY user_id ORDER BY sort_order, id
                       ) - 1 AS rn
                  FROM task_lists
                 WHERE is_system = false AND parent_id IS NULL
               ) AS ranked
         WHERE t.id = ranked.id
        """
    )

    # ── 3. 拆掉 folder_id 与 folders 表 ───────────────────────────────
    op.drop_index(op.f("ix_task_lists_folder_id"), table_name="task_lists")
    op.drop_column("task_lists", "folder_id")
    op.drop_index(op.f("ix_folders_user_id"), table_name="folders")
    op.drop_table("folders")

    # ── 4. 新列的索引与外键 ───────────────────────────────────────────
    op.create_index("ix_task_lists_parent_id", "task_lists", ["parent_id"])
    op.create_index("ix_task_lists_trashed_with", "task_lists", ["trashed_with"])
    op.create_index("ix_tasks_trashed_with", "tasks", ["trashed_with"])
    op.create_foreign_key(
        "fk_task_lists_parent_id",
        "task_lists",
        "task_lists",
        ["parent_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_task_lists_trashed_with",
        "task_lists",
        "task_lists",
        ["trashed_with"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_foreign_key(
        "fk_tasks_trashed_with",
        "tasks",
        "task_lists",
        ["trashed_with"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    """回滚只还原结构,不试图把子清单再拆回文件夹。

    合并是有损的:迁移后用户可能已经建了三层清单、往「原文件夹」里直接放了
    任务,这些在旧模型里无处安放。回滚后所有清单一律成为根清单。
    """
    op.drop_constraint("fk_tasks_trashed_with", "tasks", type_="foreignkey")
    op.drop_constraint("fk_task_lists_trashed_with", "task_lists", type_="foreignkey")
    op.drop_constraint("fk_task_lists_parent_id", "task_lists", type_="foreignkey")
    op.drop_index("ix_tasks_trashed_with", table_name="tasks")
    op.drop_index("ix_task_lists_trashed_with", table_name="task_lists")
    op.drop_index("ix_task_lists_parent_id", table_name="task_lists")

    op.create_table(
        "folders",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("sort_order", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("purged_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_folders_user_id"), "folders", ["user_id"], unique=False)

    op.add_column("task_lists", sa.Column("folder_id", sa.Uuid(), nullable=True))
    op.create_index(op.f("ix_task_lists_folder_id"), "task_lists", ["folder_id"], unique=False)
    op.create_foreign_key(
        "task_lists_folder_id_fkey",
        "task_lists",
        "folders",
        ["folder_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.drop_column("tasks", "trashed_with")
    op.drop_column("task_lists", "trashed_with")
    op.drop_column("task_lists", "parent_id")
