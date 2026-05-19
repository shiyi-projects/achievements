"""Local disk storage backend.

文件落到 ``settings.storage_local_root`` 下,在 Docker 中挂载为 volume 以持久化。
``put``/``get`` 通过 ``anyio.to_thread`` 避免阻塞事件循环。
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import Path

import anyio
import anyio.to_thread

from app.storage.base import StorageBackend

_CHUNK = 64 * 1024


class LocalDiskStorage(StorageBackend):
    def __init__(self, root: str | Path) -> None:
        self._root = Path(root).resolve()
        self._root.mkdir(parents=True, exist_ok=True)

    def _resolve(self, key: str) -> Path:
        # 防止 path traversal:解析后必须仍在根目录下。
        target = (self._root / key).resolve()
        if self._root not in target.parents and target != self._root:
            raise ValueError(f"Invalid storage key: {key}")
        return target

    async def put(self, key: str, data: bytes, content_type: str | None = None) -> str:
        _ = content_type  # 本地实现忽略,OSS 实现会用到
        path = self._resolve(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        await anyio.Path(path).write_bytes(data)
        return f"file://{path.as_posix()}"

    async def get(self, key: str) -> AsyncIterator[bytes]:
        path = self._resolve(key)

        async def _iter() -> AsyncIterator[bytes]:
            async with await anyio.open_file(path, "rb") as f:
                while chunk := await f.read(_CHUNK):
                    yield chunk

        return _iter()

    async def delete(self, key: str) -> None:
        path = self._resolve(key)

        def _unlink() -> None:
            path.unlink(missing_ok=True)

        await anyio.to_thread.run_sync(_unlink)

    async def exists(self, key: str) -> bool:
        path = self._resolve(key)
        return await anyio.Path(path).is_file()
