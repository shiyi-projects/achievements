"""清单树经 /sync 的结构约束与客户端版本门槛。"""

from __future__ import annotations

from uuid import uuid4

import pytest
from httpx import AsyncClient

from app.core.list_tree import MAX_LIST_DEPTH
from tests.helpers import create_list


async def _push_list(
    client: AsyncClient,
    list_id: str,
    *,
    name: str = "L",
    parent_id: str | None = None,
    base_version: int = 0,
) -> dict[str, object]:
    resp = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": list_id,
                    "base_version": base_version,
                    "payload": {"name": name, "parent_id": parent_id},
                }
            ]
        },
    )
    assert resp.status_code == 200, resp.text
    result: dict[str, object] = resp.json()["results"][0]
    return result


@pytest.mark.asyncio
async def test_child_list_before_parent_still_applies(client: AsyncClient) -> None:
    """同一批里子清单排在父清单之前也要能落库(FK 依赖排序)。"""
    parent_id = str(uuid4())
    child_id = str(uuid4())
    resp = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": child_id,
                    "base_version": 0,
                    "payload": {"name": "child", "parent_id": parent_id},
                },
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": parent_id,
                    "base_version": 0,
                    "payload": {"name": "parent"},
                },
            ]
        },
    )
    assert [r["status"] for r in resp.json()["results"]] == ["applied", "applied"]

    pull = (await client.get("/api/v1/sync/pull")).json()
    child = next(item for item in pull["lists"] if item["id"] == child_id)
    assert child["parent_id"] == parent_id


@pytest.mark.asyncio
async def test_self_parent_rejected(client: AsyncClient) -> None:
    list_id = str(await create_list(client, "A"))
    result = await _push_list(client, list_id, parent_id=list_id, base_version=1)
    assert result["status"] == "rejected"
    assert result["reason"] == "validation"


@pytest.mark.asyncio
async def test_cycle_rejected(client: AsyncClient) -> None:
    """把父清单挂到自己的子清单下会成环,服务端必须拒绝。"""
    parent = str(await create_list(client, "parent"))
    child = str(await create_list(client, "child"))
    assert (await _push_list(client, child, name="child", parent_id=parent, base_version=1))[
        "status"
    ] == "applied"

    result = await _push_list(client, parent, name="parent", parent_id=child, base_version=1)
    assert result["status"] == "rejected"


@pytest.mark.asyncio
async def test_depth_limit_enforced(client: AsyncClient) -> None:
    """第 MAX_LIST_DEPTH 层可以挂,再深一层被拒。"""
    previous = str(await create_list(client, "l1"))
    for level in range(2, MAX_LIST_DEPTH + 1):
        current = str(await create_list(client, f"l{level}"))
        result = await _push_list(
            client, current, name=f"l{level}", parent_id=previous, base_version=1
        )
        assert result["status"] == "applied", f"level {level} should fit"
        previous = current

    too_deep = str(await create_list(client, "too-deep"))
    result = await _push_list(client, too_deep, name="too-deep", parent_id=previous, base_version=1)
    assert result["status"] == "rejected"


@pytest.mark.asyncio
async def test_unknown_parent_rejected(client: AsyncClient) -> None:
    list_id = str(await create_list(client, "A"))
    result = await _push_list(client, list_id, parent_id=str(uuid4()), base_version=1)
    assert result["status"] == "rejected"


@pytest.mark.asyncio
async def test_trashed_with_round_trips(client: AsyncClient) -> None:
    """级联删除标记要能同步出去,否则其他端无法整体还原一个清单。"""
    root = str(await create_list(client, "root"))
    child = str(await create_list(client, "child"))
    resp = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": child,
                    "base_version": 1,
                    "payload": {
                        "deleted_at": "2026-09-04T00:00:00Z",
                        "trashed_with": root,
                    },
                }
            ]
        },
    )
    assert resp.json()["results"][0]["status"] == "applied"

    pull = (await client.get("/api/v1/sync/pull")).json()
    row = next(item for item in pull["lists"] if item["id"] == child)
    assert row["trashed_with"] == root
    assert row["deleted_at"] is not None


# ---- 客户端版本门槛 --------------------------------------------------------


@pytest.mark.asyncio
async def test_old_client_refused_with_upgrade_required(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/sync/pull", headers={"X-Client-Version": "0.3.2"})
    assert resp.status_code == 426
    assert resp.json()["detail"]["code"] == "client_upgrade_required"


@pytest.mark.asyncio
async def test_client_without_version_header_refused(client: AsyncClient) -> None:
    """旧版本根本不发这个头,同样挡在门外。"""
    resp = await client.post(
        "/api/v1/sync/push",
        json={"mutations": []},
        headers={"X-Client-Version": ""},
    )
    assert resp.status_code == 426
