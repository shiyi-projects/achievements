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


async def test_auth_register_validates_device_payload(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/register",
        json={"email": "a@b.com", "password": "x" * 8},
    )
    assert response.status_code == 422
