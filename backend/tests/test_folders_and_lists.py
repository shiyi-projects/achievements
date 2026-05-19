"""End-to-end tests for folder and task-list endpoints."""

from __future__ import annotations

from uuid import UUID

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.system_lists import SystemListKind
from app.services.list_service import ensure_system_lists


@pytest.fixture
def local_user_id() -> UUID:
    return UUID(get_settings().local_user_id)


@pytest.mark.asyncio
async def test_create_and_list_folder(client: AsyncClient) -> None:
    resp = await client.post("/api/v1/folders", json={"name": "Work"})
    assert resp.status_code == 201
    body = resp.json()
    assert body["name"] == "Work"
    assert body["sort_order"] == 0

    resp = await client.get("/api/v1/folders")
    assert resp.status_code == 200
    assert len(resp.json()) == 1


@pytest.mark.asyncio
async def test_create_list_and_rename(client: AsyncClient) -> None:
    resp = await client.post("/api/v1/lists", json={"name": "Sprint"})
    assert resp.status_code == 201
    list_id = resp.json()["id"]

    resp = await client.patch(f"/api/v1/lists/{list_id}", json={"name": "Q2 Sprint"})
    assert resp.status_code == 200
    assert resp.json()["name"] == "Q2 Sprint"


@pytest.mark.asyncio
async def test_delete_user_list(client: AsyncClient) -> None:
    create = await client.post("/api/v1/lists", json={"name": "Throwaway"})
    list_id = create.json()["id"]

    delete = await client.delete(f"/api/v1/lists/{list_id}")
    assert delete.status_code == 204

    # 软删后再 GET 应 404
    miss = await client.get(f"/api/v1/lists/{list_id}")
    assert miss.status_code == 404


@pytest.mark.asyncio
async def test_ensure_system_lists_seeds_seven(
    session: AsyncSession,
    local_user_id: UUID,
) -> None:
    await ensure_system_lists(session, local_user_id)
    # 再调一次,验证幂等
    await ensure_system_lists(session, local_user_id)

    from sqlalchemy import select

    from app.models import TaskList

    rows = (
        (
            await session.execute(
                select(TaskList).where(
                    TaskList.user_id == local_user_id, TaskList.is_system.is_(True)
                )
            )
        )
        .scalars()
        .all()
    )
    assert len(rows) == len(SystemListKind)
    kinds = {row.system_kind for row in rows}
    assert kinds == {kind.value for kind in SystemListKind}


@pytest.mark.asyncio
async def test_system_list_cannot_be_deleted(
    client: AsyncClient,
    session: AsyncSession,
    local_user_id: UUID,
) -> None:
    await ensure_system_lists(session, local_user_id)

    list_resp = await client.get("/api/v1/lists")
    system = next(item for item in list_resp.json() if item["is_system"])
    delete = await client.delete(f"/api/v1/lists/{system['id']}")
    assert delete.status_code == 409
