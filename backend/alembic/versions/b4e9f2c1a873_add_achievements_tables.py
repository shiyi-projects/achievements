"""add achievements tables with seed data

Revision ID: b4e9f2c1a873
Revises: 3f8a1c2d9e47
Create Date: 2026-05-20 00:01:00.000000

"""

from collections.abc import Sequence
from datetime import datetime, timezone
from uuid import uuid4

import sqlalchemy as sa

from alembic import op

revision: str = "b4e9f2c1a873"
down_revision: str | Sequence[str] | None = "3f8a1c2d9e47"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_SEEDS = [
    {
        "code": "first_task",
        "name": "起步",
        "description": "完成第一个任务",
        "icon": "🎯",
        "criteria": '{"type":"tasks_completed","threshold":1}',
    },
    {
        "code": "tasks_10",
        "name": "渐入佳境",
        "description": "累计完成 10 个任务",
        "icon": "⭐",
        "criteria": '{"type":"tasks_completed","threshold":10}',
    },
    {
        "code": "tasks_100",
        "name": "百战之师",
        "description": "累计完成 100 个任务",
        "icon": "🏆",
        "criteria": '{"type":"tasks_completed","threshold":100}',
    },
    {
        "code": "streak_3",
        "name": "三日不辍",
        "description": "连续 3 天完成任务",
        "icon": "🔥",
        "criteria": '{"type":"streak_days","threshold":3}',
    },
    {
        "code": "streak_7",
        "name": "一周坚持",
        "description": "连续 7 天完成任务",
        "icon": "📅",
        "criteria": '{"type":"streak_days","threshold":7}',
    },
    {
        "code": "first_focus",
        "name": "专注时刻",
        "description": "完成第一个专注会话",
        "icon": "⏱️",
        "criteria": '{"type":"focus_sessions","threshold":1}',
    },
    {
        "code": "focus_10",
        "name": "专注达人",
        "description": "累计完成 10 个专注会话",
        "icon": "🎧",
        "criteria": '{"type":"focus_sessions","threshold":10}',
    },
    {
        "code": "focus_1h",
        "name": "深度专注",
        "description": "单日累计专注满 1 小时",
        "icon": "⚡",
        "criteria": '{"type":"daily_focus_minutes","threshold":60}',
    },
]


def upgrade() -> None:
    """创建 achievements / user_achievements 表并插入种子数据。"""
    op.create_table(
        "achievements",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(64), nullable=False),
        sa.Column("name", sa.String(128), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("icon", sa.String(64), nullable=False),
        sa.Column("criteria", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code", name="uq_achievements_code"),
    )

    op.create_table(
        "user_achievements",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("achievement_id", sa.Uuid(), nullable=False),
        sa.Column("unlocked_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["achievement_id"], ["achievements.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", "achievement_id"),
    )
    op.create_index("ix_user_achievements_user_id", "user_achievements", ["user_id"])

    # 种子数据
    achievements_table = sa.table(
        "achievements",
        sa.column("id", sa.Uuid()),
        sa.column("code", sa.String),
        sa.column("name", sa.String),
        sa.column("description", sa.Text),
        sa.column("icon", sa.String),
        sa.column("criteria", sa.Text),
        sa.column("created_at", sa.DateTime(timezone=True)),
        sa.column("updated_at", sa.DateTime(timezone=True)),
    )
    # asyncpg executemany 不会替换 sa.text("CURRENT_TIMESTAMP"),必须给具体 datetime
    now = datetime.now(timezone.utc)
    op.bulk_insert(
        achievements_table,
        [
            {
                "id": uuid4(),
                "code": s["code"],
                "name": s["name"],
                "description": s["description"],
                "icon": s["icon"],
                "criteria": s["criteria"],
                "created_at": now,
                "updated_at": now,
            }
            for s in _SEEDS
        ],
    )


def downgrade() -> None:
    op.drop_index("ix_user_achievements_user_id", table_name="user_achievements")
    op.drop_table("user_achievements")
    op.drop_table("achievements")
