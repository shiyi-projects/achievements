"""Storage backend abstract interface.

Phase 0 仅声明接口,实现见 ``local.py``。
后续切 OSS 时新增 ``oss.py`` 实现同一接口,通过 ``STORAGE_BACKEND`` 环境变量选择。
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import AsyncIterator


class StorageBackend(ABC):
    @abstractmethod
    async def put(self, key: str, data: bytes, content_type: str | None = None) -> str:
        """Persist ``data`` under ``key``. Return the canonical URL/identifier."""

    @abstractmethod
    async def get(self, key: str) -> AsyncIterator[bytes]:
        """Stream the object content."""

    @abstractmethod
    async def delete(self, key: str) -> None:
        """Remove the object, idempotent."""

    @abstractmethod
    async def exists(self, key: str) -> bool: ...
