"""Sync engine endpoint tests."""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime
from uuid import UUID

import pytest
from httpx import AsyncClient


async def _create_list(client: AsyncClient, name: str = "Inbox") -> UUID:
    resp = await client.post("/api/v1/lists", json={"name": name})
    assert resp.status_code == 201
    return UUID(resp.json()["id"])


@pytest.mark.asyncio
async def test_initial_pull_returns_full_state(client: AsyncClient) -> None:
    list_id = await _create_list(client, "Work")
    await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": "Task A"})

    pull = await client.get("/api/v1/sync/pull")
    assert pull.status_code == 200
    body = pull.json()

    assert body["cursor"]  # ISO timestamp
    assert {item["name"] for item in body["lists"]} == {"Work"}
    assert [t["title"] for t in body["tasks"]] == ["Task A"]
    assert body["folders"] == []
    assert body["tags"] == []
    assert body["task_tags"] == []


@pytest.mark.asyncio
async def test_incremental_pull_returns_only_delta(
    client: AsyncClient,
) -> None:
    list_id = await _create_list(client, "Work")

    first = await client.get("/api/v1/sync/pull")
    first_cursor = first.json()["cursor"]

    # 等一下确保 updated_at > first_cursor
    await asyncio.sleep(0.05)
    await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": "After cursor"})

    second = await client.get("/api/v1/sync/pull", params={"since": first_cursor})
    assert second.status_code == 200
    body = second.json()
    # 旧 list 不应再回(未被更新),仅新 task
    assert body["lists"] == []
    assert [t["title"] for t in body["tasks"]] == ["After cursor"]


@pytest.mark.asyncio
async def test_pull_includes_soft_deleted(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    created = (
        await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": "Trash me"})
    ).json()
    await client.delete(f"/api/v1/tasks/{created['id']}")  # soft delete

    pull = await client.get("/api/v1/sync/pull")
    deleted_task = next(t for t in pull.json()["tasks"] if t["id"] == created["id"])
    assert deleted_task["deleted_at"] is not None


@pytest.mark.asyncio
async def test_pull_future_since_returns_empty(client: AsyncClient) -> None:
    await _create_list(client)
    future = datetime.now(UTC).replace(year=2099).isoformat()
    pull = await client.get("/api/v1/sync/pull", params={"since": future})
    body = pull.json()
    assert body["lists"] == []
    assert body["tasks"] == []
