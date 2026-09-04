"""测试公用工具。

清单没有 REST 端点(客户端 local-first,读写一律走 /sync),测试里要拿一个
清单就走一次 sync push。
"""

from __future__ import annotations

from uuid import UUID, uuid4

from httpx import AsyncClient


async def create_list(
    client: AsyncClient,
    name: str = "Inbox",
    *,
    parent_id: UUID | None = None,
) -> UUID:
    """经 /sync/push 建一个用户清单,返回其 id。"""
    list_id = uuid4()
    payload: dict[str, object] = {"name": name}
    if parent_id is not None:
        payload["parent_id"] = str(parent_id)
    resp = await client.post(
        "/api/v1/sync/push",
        json={
            "mutations": [
                {
                    "entity": "list",
                    "op": "upsert",
                    "id": str(list_id),
                    "base_version": 0,
                    "payload": payload,
                }
            ]
        },
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["results"][0]["status"] == "applied", resp.text
    return list_id
