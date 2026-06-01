"""Common ORM mixins.

提供可同步实体所需的通用字段:
- ``UUIDPKMixin``: UUID 主键(客户端可生成,免协调)。
- ``TimestampMixin``: created_at / updated_at。
- ``SoftDeleteMixin``: deleted_at(回收站,可恢复)+ purged_at(永久删除墓碑)。
- ``VersionMixin``: version,LWW 冲突解决用,服务端每次写入自增。

删除有两态:``deleted_at`` 表示"移入回收站"(可恢复,各端保留行并显示在回收站);
``purged_at`` 表示"永久删除"墓碑——增量 pull 仍下发,各端据此**物理删除本地行**,
服务端保留墓碑一段保留期供各端同步,到期由惰性 GC 物理清除(见 ``sync_service.pull``)。

所有可由客户端同步的表应组合 ``SyncableMixin``,它聚合了上述四个 mixin 并附带
``user_id`` 占位字段(Phase 0/1 暂不强约束 users 表)。

UUID 列用 ``sqlalchemy.Uuid`` 跨库:Postgres 用原生 UUID,SQLite 落 CHAR(32)。
"""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Uuid
from sqlalchemy.orm import Mapped, mapped_column


def _utcnow() -> datetime:
    """Microsecond-precision UTC now,跨库一致(避免 SQLite 的秒级 CURRENT_TIMESTAMP)。"""
    return datetime.now(UTC)


class UUIDPKMixin:
    id: Mapped[UUID] = mapped_column(
        Uuid(),
        primary_key=True,
        default=uuid4,
    )


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=_utcnow,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=_utcnow,
        onupdate=_utcnow,
    )


class SoftDeleteMixin:
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
    )
    # 永久删除墓碑。非空即不可恢复:客户端 pull 到后物理删本地行;
    # 服务端保留至超过保留期再被 GC 物理清除。
    purged_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
    )


class VersionMixin:
    version: Mapped[int] = mapped_column(nullable=False, default=1, server_default="1")


class SyncableMixin(UUIDPKMixin, TimestampMixin, SoftDeleteMixin, VersionMixin):
    """Convenience aggregate mixin for any client-syncable entity."""

    user_id: Mapped[UUID] = mapped_column(
        Uuid(),
        nullable=False,
        index=True,
    )
