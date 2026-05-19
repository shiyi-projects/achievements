"""Tag CRUD + task association endpoint tests."""

from __future__ import annotations

from uuid import UUID

import pytest
from httpx import AsyncClient


async def _create_list(client: AsyncClient, name: str = "Inbox") -> UUID:
    resp = await client.post("/api/v1/lists", json={"name": name})
    return UUID(resp.json()["id"])


async def _create_task(client: AsyncClient, list_id: UUID, title: str) -> UUID:
    resp = await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": title})
    return UUID(resp.json()["id"])


@pytest.mark.asyncio
async def test_create_tag_dedupes_same_name(client: AsyncClient) -> None:
    first = await client.post("/api/v1/tags", json={"name": "reading"})
    assert first.status_code == 201
    again = await client.post("/api/v1/tags", json={"name": "reading"})
    assert again.status_code == 201
    assert first.json()["id"] == again.json()["id"]


@pytest.mark.asyncio
async def test_update_and_delete_tag(client: AsyncClient) -> None:
    created = await client.post("/api/v1/tags", json={"name": "x"})
    tag_id = created.json()["id"]

    rename = await client.patch(f"/api/v1/tags/{tag_id}", json={"name": "renamed"})
    assert rename.status_code == 200
    assert rename.json()["name"] == "renamed"

    delete = await client.delete(f"/api/v1/tags/{tag_id}")
    assert delete.status_code == 204
    miss = await client.get(f"/api/v1/tags/{tag_id}")
    assert miss.status_code == 404


@pytest.mark.asyncio
async def test_assign_and_unassign_tag(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    task_id = await _create_task(client, list_id, "Read book")
    tag = (await client.post("/api/v1/tags", json={"name": "reading"})).json()

    add = await client.put(f"/api/v1/tasks/{task_id}/tags/{tag['id']}")
    assert add.status_code == 204

    # 第二次 add 仍然 204(幂等)
    add2 = await client.put(f"/api/v1/tasks/{task_id}/tags/{tag['id']}")
    assert add2.status_code == 204

    listing = await client.get(f"/api/v1/tasks/{task_id}/tags")
    assert listing.status_code == 200
    assert [t["name"] for t in listing.json()] == ["reading"]

    remove = await client.delete(f"/api/v1/tasks/{task_id}/tags/{tag['id']}")
    assert remove.status_code == 204
    after = await client.get(f"/api/v1/tasks/{task_id}/tags")
    assert after.json() == []


@pytest.mark.asyncio
async def test_assign_with_unknown_tag_returns_404(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    task_id = await _create_task(client, list_id, "x")
    fake_tag = "00000000-0000-0000-0000-000000000999"
    add = await client.put(f"/api/v1/tasks/{task_id}/tags/{fake_tag}")
    assert add.status_code == 404
