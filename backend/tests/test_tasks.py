"""End-to-end tests for the /api/v1/tasks endpoints."""

from __future__ import annotations

from uuid import UUID

import pytest
from httpx import AsyncClient


async def _create_list(client: AsyncClient, name: str = "Inbox") -> UUID:
    resp = await client.post("/api/v1/lists", json={"name": name})
    assert resp.status_code == 201
    return UUID(resp.json()["id"])


@pytest.mark.asyncio
async def test_create_and_fetch_task(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    create = await client.post(
        "/api/v1/tasks",
        json={"list_id": str(list_id), "title": "Read book", "priority": 2},
    )
    assert create.status_code == 201
    body = create.json()
    assert body["title"] == "Read book"
    assert body["priority"] == 2
    assert body["completed_at"] is None

    get_one = await client.get(f"/api/v1/tasks/{body['id']}")
    assert get_one.status_code == 200
    assert get_one.json()["id"] == body["id"]


@pytest.mark.asyncio
async def test_update_task(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    created = (
        await client.post(
            "/api/v1/tasks", json={"list_id": str(list_id), "title": "Draft"}
        )
    ).json()

    patch = await client.patch(
        f"/api/v1/tasks/{created['id']}",
        json={"title": "Final", "priority": 3, "starred": True},
    )
    assert patch.status_code == 200
    body = patch.json()
    assert body["title"] == "Final"
    assert body["priority"] == 3
    assert body["starred"] is True


@pytest.mark.asyncio
async def test_complete_toggle(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    created = (
        await client.post(
            "/api/v1/tasks", json={"list_id": str(list_id), "title": "Pay bill"}
        )
    ).json()

    done = await client.post(
        f"/api/v1/tasks/{created['id']}/complete", json={"completed": True}
    )
    assert done.status_code == 200
    assert done.json()["completed_at"] is not None

    undone = await client.post(
        f"/api/v1/tasks/{created['id']}/complete", json={"completed": False}
    )
    assert undone.status_code == 200
    assert undone.json()["completed_at"] is None


@pytest.mark.asyncio
async def test_soft_delete_and_restore(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    created = (
        await client.post(
            "/api/v1/tasks", json={"list_id": str(list_id), "title": "Temp"}
        )
    ).json()
    task_id = created["id"]

    soft = await client.delete(f"/api/v1/tasks/{task_id}")
    assert soft.status_code == 204

    # 默认列表(不含已删)看不到了
    default_list = await client.get("/api/v1/tasks")
    assert all(t["id"] != task_id for t in default_list.json())

    # include_deleted=true 可以看到
    with_deleted = await client.get("/api/v1/tasks", params={"include_deleted": True})
    assert any(t["id"] == task_id for t in with_deleted.json())

    # restore 后又可见
    restore = await client.post(f"/api/v1/tasks/{task_id}/restore")
    assert restore.status_code == 200
    assert restore.json()["deleted_at"] is None


@pytest.mark.asyncio
async def test_hard_delete(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    created = (
        await client.post(
            "/api/v1/tasks", json={"list_id": str(list_id), "title": "Gone"}
        )
    ).json()
    task_id = created["id"]

    hard = await client.delete(f"/api/v1/tasks/{task_id}/permanent")
    assert hard.status_code == 204

    miss = await client.get(f"/api/v1/tasks/{task_id}")
    assert miss.status_code == 404


@pytest.mark.asyncio
async def test_filter_by_list(client: AsyncClient) -> None:
    a = await _create_list(client, "A")
    b = await _create_list(client, "B")
    await client.post("/api/v1/tasks", json={"list_id": str(a), "title": "in-A"})
    await client.post("/api/v1/tasks", json={"list_id": str(b), "title": "in-B"})

    only_a = await client.get("/api/v1/tasks", params={"list_id": str(a)})
    titles = {t["title"] for t in only_a.json()}
    assert titles == {"in-A"}
