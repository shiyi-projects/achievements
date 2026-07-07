"""Smoke tests for health and auth endpoints."""

from __future__ import annotations

from httpx import AsyncClient


async def test_root_returns_metadata(client: AsyncClient) -> None:
    response = await client.get("/")
    assert response.status_code == 200
    payload = response.json()
    assert payload["name"] == "Achievements API"
    assert payload["docs"] == "/docs"


async def test_healthz_ok(client: AsyncClient) -> None:
    response = await client.get("/api/v1/healthz")
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert "timestamp" in payload
    assert payload["version"]
