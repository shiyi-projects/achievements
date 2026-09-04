"""Sync engine endpoint tests."""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Task
from app.services.sync_service import SINCE_OVERLAP


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

    # since=first_cursor:新 task 必须在(防丢是硬约束);旧 list 落在
    # SINCE_OVERLAP 重叠窗口内允许重复下发(客户端落库幂等),不断言排除。
    second = await client.get("/api/v1/sync/pull", params={"since": first_cursor})
    assert second.status_code == 200
    body = second.json()
    assert [t["title"] for t in body["tasks"]] == ["After cursor"]

    # 把 since 推后一个重叠窗口:effective_since 回到 first_cursor,增量过滤
    # 仍生效——窗口外的旧 list 不回,新 task 仍在。
    shifted = (datetime.fromisoformat(first_cursor) + SINCE_OVERLAP).isoformat()
    third = await client.get("/api/v1/sync/pull", params={"since": shifted})
    assert third.status_code == 200
    body = third.json()
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


# ---- push -----------------------------------------------------------------


@pytest.mark.asyncio
async def test_push_creates_new_entities(client: AsyncClient) -> None:
    list_id = str(uuid4())
    task_id = str(uuid4())
    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": list_id,
                    "base_version": 0,
                    "payload": {"name": "Pushed list"},
                },
                {
                    "entity": "task",
                    "op": "upsert",
                    "id": task_id,
                    "base_version": 0,
                    "payload": {
                        "list_id": list_id,
                        "title": "Pushed task",
                        "priority": 2,
                    },
                },
            ]
        },
    )
    assert push.status_code == 200
    results = push.json()["results"]
    assert [r["status"] for r in results] == ["applied", "applied"]
    assert all(r["version"] == 1 for r in results)

    pull = (await client.get("/api/v1/sync/pull")).json()
    assert any(item["id"] == list_id for item in pull["lists"])
    assert any(t["id"] == task_id and t["priority"] == 2 for t in pull["tasks"])


@pytest.mark.asyncio
async def test_push_upsert_creates_soft_deleted_override(client: AsyncClient) -> None:
    """EXDATE 路径:重复系列「删某次」的 override 往往是「新建即软删」。

    客户端对这种行发 upsert 并携带完整字段 + deleted_at(不能用 delete + 空
    payload,那对不存在的实体是幂等 no-op),服务端必须创建出软删行并随 delta
    下发,否则跳过的发生点无法跨端传播。
    """
    list_id = await _create_list(client, "Recurring")
    template = (
        await client.post(
            "/api/v1/tasks",
            json={"list_id": str(list_id), "title": "每日站会", "repeat_rule": "FREQ=DAILY"},
        )
    ).json()
    override_id = str(uuid4())
    occurrence = datetime.now(UTC).isoformat()

    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task",
                    "op": "upsert",
                    "id": override_id,
                    "base_version": 0,
                    "payload": {
                        "list_id": str(list_id),
                        "title": "每日站会",
                        "recurrence_parent_id": template["id"],
                        "occurrence_date": occurrence,
                        "deleted_at": occurrence,
                    },
                }
            ]
        },
    )
    assert push.json()["results"][0]["status"] == "applied"

    pull = (await client.get("/api/v1/sync/pull")).json()
    row = next(t for t in pull["tasks"] if t["id"] == override_id)
    assert row["deleted_at"] is not None
    assert row["recurrence_parent_id"] == template["id"]
    assert row["occurrence_date"] is not None


@pytest.mark.asyncio
async def test_push_update_with_matching_version_bumps(
    client: AsyncClient,
) -> None:
    list_id = (await client.post("/api/v1/lists", json={"name": "Foo"})).json()["id"]
    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": list_id,
                    "base_version": 1,
                    "payload": {"name": "Foo (renamed)"},
                }
            ]
        },
    )
    body = push.json()
    assert body["results"][0]["status"] == "applied"
    assert body["results"][0]["version"] == 2


@pytest.mark.asyncio
async def test_push_stale_base_version_yields_conflict(
    client: AsyncClient,
) -> None:
    list_id = (await client.post("/api/v1/lists", json={"name": "Local"})).json()["id"]
    # 服务端 version=1。客户端送 base_version=0 → 冲突
    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": list_id,
                    "base_version": 0,
                    "payload": {"name": "Loser"},
                }
            ]
        },
    )
    result = push.json()["results"][0]
    assert result["status"] == "conflict"
    assert result["version"] == 1
    assert result["server_value"]["name"] == "Local"


@pytest.mark.asyncio
async def test_push_delete_soft_deletes(client: AsyncClient) -> None:
    list_id = (await client.post("/api/v1/lists", json={"name": "L"})).json()["id"]
    task_id = (
        await client.post("/api/v1/tasks", json={"list_id": list_id, "title": "doomed"})
    ).json()["id"]

    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task",
                    "op": "delete",
                    "id": task_id,
                    "base_version": 1,
                    "payload": {},
                }
            ]
        },
    )
    assert push.json()["results"][0]["status"] == "applied"
    fetched = await client.get(f"/api/v1/tasks/{task_id}")
    assert fetched.json()["deleted_at"] is not None


# ---- 批内因果链 -----------------------------------------------------------


@pytest.mark.asyncio
async def test_push_batch_upsert_then_delete_both_apply(client: AsyncClient) -> None:
    """离线期间「改标题 → 删除」:两条 mutation 带着相同的陈旧 base_version。

    客户端本地 version 只在收到 applied 后才回写,所以第 2 条起必然陈旧。
    服务端须按序接续而不是判 conflict —— 否则客户端 LWW 会拿「本地入队时刻」
    比「服务端刚应用第 1 条的时刻」,后者恒晚,删除被静默吞掉。
    """
    list_id = (await client.post("/api/v1/lists", json={"name": "L"})).json()["id"]
    task_id = (
        await client.post("/api/v1/tasks", json={"list_id": list_id, "title": "交年报"})
    ).json()["id"]

    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task",
                    "op": "upsert",
                    "id": task_id,
                    "base_version": 1,
                    "payload": {"title": "交年报(终版)"},
                },
                {
                    "entity": "task",
                    "op": "delete",
                    "id": task_id,
                    "base_version": 1,  # 陈旧:第 1 条已把服务端推到 2
                    "payload": {},
                },
            ]
        },
    )
    results = push.json()["results"]
    assert [r["status"] for r in results] == ["applied", "applied"]
    assert [r["version"] for r in results] == [2, 3]

    fetched = (await client.get(f"/api/v1/tasks/{task_id}")).json()
    assert fetched["title"] == "交年报(终版)"
    assert fetched["deleted_at"] is not None


@pytest.mark.asyncio
async def test_push_batch_repeated_upserts_chain(client: AsyncClient) -> None:
    """同一实体在一批里连改三次,全部按序生效,version 逐条递增。"""
    list_id = (await client.post("/api/v1/lists", json={"name": "L"})).json()["id"]

    def mutation(name: str) -> dict[str, object]:
        return {
            "entity": "list",
            "op": "upsert",
            "id": list_id,
            "base_version": 1,
            "payload": {"name": name},
        }

    push = await client.post(
        "/api/v1/sync/push",
        json={"mutations": [mutation("A"), mutation("B"), mutation("C")]},
    )
    results = push.json()["results"]
    assert [r["status"] for r in results] == ["applied"] * 3
    assert [r["version"] for r in results] == [2, 3, 4]

    pull = (await client.get("/api/v1/sync/pull")).json()
    assert next(item for item in pull["lists"] if item["id"] == list_id)["name"] == "C"


@pytest.mark.asyncio
async def test_push_batch_purge_after_upsert_applies(client: AsyncClient) -> None:
    """「编辑 → 永久删除」同批也须接续,墓碑必须落地。"""
    list_id = (await client.post("/api/v1/lists", json={"name": "L"})).json()["id"]
    task_id = (
        await client.post("/api/v1/tasks", json={"list_id": list_id, "title": "gone"})
    ).json()["id"]

    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task",
                    "op": "upsert",
                    "id": task_id,
                    "base_version": 1,
                    "payload": {"title": "gone (edited)"},
                },
                {
                    "entity": "task",
                    "op": "purge",
                    "id": task_id,
                    "base_version": 1,
                    "payload": {},
                },
            ]
        },
    )
    assert [r["status"] for r in push.json()["results"]] == ["applied", "applied"]

    pull = (await client.get("/api/v1/sync/pull")).json()
    assert next(t for t in pull["tasks"] if t["id"] == task_id)["purged_at"] is not None


@pytest.mark.asyncio
async def test_push_cross_batch_stale_version_still_conflicts(
    client: AsyncClient,
) -> None:
    """批内接续不能放过真正的并发:另一批推上去的写仍须判 conflict。"""
    list_id = (await client.post("/api/v1/lists", json={"name": "Local"})).json()["id"]

    # 第一批:模拟另一台设备把 version 推到 2
    first = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": list_id,
                    "base_version": 1,
                    "payload": {"name": "Device B"},
                }
            ]
        },
    )
    assert first.json()["results"][0]["status"] == "applied"

    # 第二批:本设备仍以为是 version 1 → 必须冲突,不能被当成因果后继
    second = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": list_id,
                    "base_version": 1,
                    "payload": {"name": "Device A"},
                }
            ]
        },
    )
    result = second.json()["results"][0]
    assert result["status"] == "conflict"
    assert result["version"] == 2
    assert result["server_value"]["name"] == "Device B"


@pytest.mark.asyncio
async def test_push_batch_conflict_does_not_leak_to_other_entity(
    client: AsyncClient,
) -> None:
    """接续集合按实体隔离:A 实体在批内接续,不能让 B 实体的陈旧 base 蒙混过关。"""
    a_id = (await client.post("/api/v1/lists", json={"name": "A"})).json()["id"]
    b_id = (await client.post("/api/v1/lists", json={"name": "B"})).json()["id"]

    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": a_id,
                    "base_version": 1,
                    "payload": {"name": "A1"},
                },
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": a_id,
                    "base_version": 1,
                    "payload": {"name": "A2"},
                },
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": b_id,
                    "base_version": 99,  # 与任何真实 version 都对不上
                    "payload": {"name": "B1"},
                },
            ]
        },
    )
    assert [r["status"] for r in push.json()["results"]] == [
        "applied",
        "applied",
        "conflict",
    ]


@pytest.mark.asyncio
async def test_push_recurrence_fields_round_trip(client: AsyncClient) -> None:
    """重复模板与 override 字段经 sync push → pull 往返保真。"""
    list_id = (await client.post("/api/v1/lists", json={"name": "L"})).json()["id"]
    template_id = str(uuid4())
    override_id = str(uuid4())

    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task",
                    "op": "upsert",
                    "id": template_id,
                    "base_version": 0,
                    "payload": {
                        "list_id": list_id,
                        "title": "Standup",
                        "repeat_rule": "FREQ=WEEKLY;BYDAY=MO",
                        "due_at": "2026-06-08T01:00:00Z",
                    },
                },
                {
                    "entity": "task",
                    "op": "upsert",
                    "id": override_id,
                    "base_version": 0,
                    "payload": {
                        "list_id": list_id,
                        "title": "Standup",
                        "recurrence_parent_id": template_id,
                        "occurrence_date": "2026-06-15T01:00:00Z",
                    },
                },
            ]
        },
    )
    assert [r["status"] for r in push.json()["results"]] == ["applied", "applied"]

    pull = (await client.get("/api/v1/sync/pull")).json()
    template = next(t for t in pull["tasks"] if t["id"] == template_id)
    override = next(t for t in pull["tasks"] if t["id"] == override_id)
    assert template["repeat_rule"] == "FREQ=WEEKLY;BYDAY=MO"
    assert template["recurrence_parent_id"] is None
    assert override["recurrence_parent_id"] == template_id
    assert override["occurrence_date"] is not None


# ---- purge (永久删除墓碑) --------------------------------------------------


@pytest.mark.asyncio
async def test_push_purge_writes_tombstone(client: AsyncClient) -> None:
    """purge 写 purged_at 墓碑;pull 仍下发(保留期内),供各端物理删除本地行。"""
    list_id = (await client.post("/api/v1/lists", json={"name": "L"})).json()["id"]
    task_id = (
        await client.post("/api/v1/tasks", json={"list_id": list_id, "title": "gone"})
    ).json()["id"]

    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task",
                    "op": "purge",
                    "id": task_id,
                    "base_version": 1,
                    "payload": {},
                }
            ]
        },
    )
    assert push.json()["results"][0]["status"] == "applied"

    pull = (await client.get("/api/v1/sync/pull")).json()
    purged = next(t for t in pull["tasks"] if t["id"] == task_id)
    assert purged["purged_at"] is not None


@pytest.mark.asyncio
async def test_push_purge_nonexistent_is_idempotent(client: AsyncClient) -> None:
    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task",
                    "op": "purge",
                    "id": str(uuid4()),
                    "base_version": 1,
                    "payload": {},
                }
            ]
        },
    )
    result = push.json()["results"][0]
    assert result["status"] == "applied"
    assert result["version"] == 1


@pytest.mark.asyncio
async def test_pull_gc_removes_purged_beyond_retention(
    client: AsyncClient, session: AsyncSession
) -> None:
    """purged_at 超过保留期的行,在 pull 时被惰性 GC 物理清除,不再下发。"""
    list_id = (await client.post("/api/v1/lists", json={"name": "L"})).json()["id"]
    task_id = (
        await client.post("/api/v1/tasks", json={"list_id": list_id, "title": "ancient"})
    ).json()["id"]

    # 直接把墓碑时间改到保留期之外
    task = await session.get(Task, UUID(task_id))
    assert task is not None
    task.purged_at = datetime.now(UTC) - timedelta(days=40)
    await session.commit()

    pull = (await client.get("/api/v1/sync/pull")).json()
    assert all(t["id"] != task_id for t in pull["tasks"])


# ---- task_tag 同步 --------------------------------------------------------


async def _create_tag(client: AsyncClient, name: str = "urgent") -> str:
    resp = await client.post("/api/v1/tags", json={"name": name})
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_task_tag_upsert_then_delete_sync(client: AsyncClient) -> None:
    list_id = (await client.post("/api/v1/lists", json={"name": "L"})).json()["id"]
    task_id = (await client.post("/api/v1/tasks", json={"list_id": list_id, "title": "t"})).json()[
        "id"
    ]
    tag_id = await _create_tag(client)

    payload = {"task_id": task_id, "tag_id": tag_id}

    # upsert 建立关联
    up = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task_tag",
                    "op": "upsert",
                    "id": task_id,
                    "base_version": 0,
                    "payload": payload,
                }
            ]
        },
    )
    assert up.json()["results"][0]["status"] == "applied"

    pull = (await client.get("/api/v1/sync/pull")).json()
    tt = next(x for x in pull["task_tags"] if x["task_id"] == task_id and x["tag_id"] == tag_id)
    assert tt["deleted_at"] is None

    # delete 置墓碑
    rm = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task_tag",
                    "op": "delete",
                    "id": task_id,
                    "base_version": 0,
                    "payload": payload,
                }
            ]
        },
    )
    assert rm.json()["results"][0]["status"] == "applied"

    pull2 = (await client.get("/api/v1/sync/pull")).json()
    tt2 = next(x for x in pull2["task_tags"] if x["task_id"] == task_id and x["tag_id"] == tag_id)
    assert tt2["deleted_at"] is not None


@pytest.mark.asyncio
async def test_task_tag_rejected_when_not_owned(client: AsyncClient) -> None:
    """task / tag 不属于当前用户(此处用根本不存在的 id)→ rejected。"""
    push = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "task_tag",
                    "op": "upsert",
                    "id": str(uuid4()),
                    "base_version": 0,
                    "payload": {"task_id": str(uuid4()), "tag_id": str(uuid4())},
                }
            ]
        },
    )
    assert push.json()["results"][0]["status"] == "rejected"
