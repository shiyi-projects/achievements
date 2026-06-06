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
        await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": "Draft"})
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
        await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": "Pay bill"})
    ).json()

    done = await client.post(f"/api/v1/tasks/{created['id']}/complete", json={"completed": True})
    assert done.status_code == 200
    assert done.json()["completed_at"] is not None

    undone = await client.post(f"/api/v1/tasks/{created['id']}/complete", json={"completed": False})
    assert undone.status_code == 200
    assert undone.json()["completed_at"] is None


@pytest.mark.asyncio
async def test_soft_delete_and_restore(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    created = (
        await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": "Temp"})
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
        await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": "Gone"})
    ).json()
    task_id = created["id"]

    hard = await client.delete(f"/api/v1/tasks/{task_id}/permanent")
    assert hard.status_code == 204

    miss = await client.get(f"/api/v1/tasks/{task_id}")
    assert miss.status_code == 404


@pytest.mark.asyncio
async def test_recurrence_fields_round_trip(client: AsyncClient) -> None:
    """重复模板与 override 字段经 REST create/read/update 往返(修复历史断点)。"""
    list_id = await _create_list(client)

    # 创建一条重复「模板」:带 RRULE,recurrence_parent_id 为空
    template = (
        await client.post(
            "/api/v1/tasks",
            json={
                "list_id": str(list_id),
                "title": "Weekly standup",
                "repeat_rule": "FREQ=WEEKLY;BYDAY=MO",
                "due_at": "2026-06-08T01:00:00Z",
            },
        )
    ).json()
    assert template["repeat_rule"] == "FREQ=WEEKLY;BYDAY=MO"
    assert template["recurrence_parent_id"] is None
    assert template["occurrence_date"] is None

    # 读回保留 RRULE
    fetched = (await client.get(f"/api/v1/tasks/{template['id']}")).json()
    assert fetched["repeat_rule"] == "FREQ=WEEKLY;BYDAY=MO"

    # 创建一条 override 实体:指回模板 + 标记发生点
    override = (
        await client.post(
            "/api/v1/tasks",
            json={
                "list_id": str(list_id),
                "title": "Weekly standup",
                "recurrence_parent_id": template["id"],
                "occurrence_date": "2026-06-15T01:00:00Z",
            },
        )
    ).json()
    assert override["recurrence_parent_id"] == template["id"]
    assert override["occurrence_date"] is not None

    # update 也能改 repeat_rule(截断系列等场景)
    patched = (
        await client.patch(
            f"/api/v1/tasks/{template['id']}",
            json={"repeat_rule": "FREQ=WEEKLY;BYDAY=MO;UNTIL=20260701T000000Z"},
        )
    ).json()
    assert patched["repeat_rule"].endswith("UNTIL=20260701T000000Z")


@pytest.mark.asyncio
async def test_filter_by_list(client: AsyncClient) -> None:
    a = await _create_list(client, "A")
    b = await _create_list(client, "B")
    await client.post("/api/v1/tasks", json={"list_id": str(a), "title": "in-A"})
    await client.post("/api/v1/tasks", json={"list_id": str(b), "title": "in-B"})

    only_a = await client.get("/api/v1/tasks", params={"list_id": str(a)})
    titles = {t["title"] for t in only_a.json()}
    assert titles == {"in-A"}


@pytest.mark.asyncio
async def test_filter_by_parent_and_root_only(client: AsyncClient) -> None:
    list_id = await _create_list(client)
    parent = (
        await client.post("/api/v1/tasks", json={"list_id": str(list_id), "title": "parent"})
    ).json()
    await client.post(
        "/api/v1/tasks",
        json={
            "list_id": str(list_id),
            "parent_id": parent["id"],
            "title": "child-1",
        },
    )
    await client.post(
        "/api/v1/tasks",
        json={
            "list_id": str(list_id),
            "parent_id": parent["id"],
            "title": "child-2",
        },
    )

    # 默认无 filter → 3 条
    all_resp = await client.get("/api/v1/tasks")
    assert len(all_resp.json()) == 3

    # parent_id=<uuid> → 仅子任务
    children = await client.get("/api/v1/tasks", params={"parent_id": parent["id"]})
    assert {t["title"] for t in children.json()} == {"child-1", "child-2"}

    # root_only=true → 仅根任务
    roots = await client.get("/api/v1/tasks", params={"root_only": True})
    assert [t["title"] for t in roots.json()] == ["parent"]

    # root_only=true 优先于 parent_id(同时给)
    only_root = await client.get(
        "/api/v1/tasks",
        params={"parent_id": parent["id"], "root_only": True},
    )
    assert [t["title"] for t in only_root.json()] == ["parent"]
