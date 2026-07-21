"""db_keepalive 单元测试。"""

from __future__ import annotations

import asyncio

import pytest

from app.core.db_keepalive import start_db_keepalive


@pytest.mark.asyncio
async def test_disabled_when_interval_non_positive() -> None:
    assert start_db_keepalive(0) is None
    assert start_db_keepalive(-1) is None


@pytest.mark.asyncio
async def test_starts_and_cancels_cleanly() -> None:
    task = start_db_keepalive(1.0)
    assert task is not None
    assert not task.done()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task


@pytest.mark.asyncio
async def test_ping_executes_and_survives_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    """跑一轮真实 ping(测试库);再验证查询抛错时循环不退出。"""
    import app.core.db_keepalive as mod

    # interval 极小,让循环立刻进入 ping
    task = start_db_keepalive(0.01 / 3600)
    assert task is not None
    await asyncio.sleep(0.1)
    assert not task.done()  # ping 过至少一轮且循环仍在
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task

    # SessionLocal 抛错 → 循环记 warning 后继续,不崩
    class _Boom:
        def __call__(self) -> _Boom:
            raise RuntimeError("db down")

    monkeypatch.setattr(mod, "SessionLocal", _Boom())
    task = start_db_keepalive(0.01 / 3600)
    assert task is not None
    await asyncio.sleep(0.1)
    assert not task.done()
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
