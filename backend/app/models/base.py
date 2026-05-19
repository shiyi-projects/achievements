"""Common ORM mixins.

提供可同步实体所需的通用字段:
- ``UUIDPKMixin``: UUID 主键(客户端可生成,免协调)。
- ``TimestampMixin``: created_at / updated_at。
- ``SoftDeleteMixin``: deleted_at,软删用。
- ``VersionMixin``: version,LWW 冲突解决用,服务端每次写入自增。

所有可由客户端同步的表应组合 ``SyncableMixin``,它聚合了上述四个 mixin 并附带
``user_id`` 外键占位(Phase 0 暂不强约束 users 表)。
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column


class UUIDPKMixin:
    id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class SoftDeleteMixin:
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
    )


class VersionMixin:
    version: Mapped[int] = mapped_column(nullable=False, default=1, server_default="1")


class SyncableMixin(UUIDPKMixin, TimestampMixin, SoftDeleteMixin, VersionMixin):
    """Convenience aggregate mixin for any client-syncable entity."""

    user_id: Mapped[UUID] = mapped_column(
        PGUUID(as_uuid=True),
        nullable=False,
        index=True,
    )
