"""OLib API client used by Achievements auth proxy."""

from __future__ import annotations

from typing import Any

import httpx
from fastapi import HTTPException, status

from app.core.config import Settings
from app.schemas.auth import (
    AuthRegisterRequest,
    AuthRegisterResponse,
    QrCodeResponse,
    UserProfile,
)


class OlibClient:
    def __init__(self, settings: Settings) -> None:
        self._base_url = settings.olib_base_url.rstrip("/")
        self._timeout = settings.olib_timeout_seconds

    async def register(self, payload: AuthRegisterRequest) -> AuthRegisterResponse:
        data = await self._request(
            "POST",
            "/auth/register",
            json=payload.model_dump(),
            auth_token=None,
        )
        return AuthRegisterResponse(
            anon_token=str(data["token"]),
            expires_in=int(data["expires_in"]),
        )

    async def qrcode(self, anon_token: str) -> QrCodeResponse:
        data = await self._request("GET", "/auth/qrcode", auth_token=anon_token)
        return QrCodeResponse.model_validate(data)

    async def status(self, anon_token: str) -> dict[str, Any]:
        return await self._request("GET", "/auth/status", auth_token=anon_token)

    async def profile(self, olib_token: str) -> UserProfile:
        data = await self._request("GET", "/user/profile", auth_token=olib_token)
        return UserProfile.model_validate(data)

    async def _request(
        self,
        method: str,
        path: str,
        *,
        auth_token: str | None,
        json: dict[str, object] | None = None,
    ) -> Any:
        headers = {"Authorization": f"Bearer {auth_token}"} if auth_token else None
        try:
            async with httpx.AsyncClient(base_url=self._base_url, timeout=self._timeout) as client:
                response = await client.request(method, path, json=json, headers=headers)
        except httpx.TimeoutException as exc:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="OLib auth service timed out",
            ) from exc
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="OLib auth service unavailable",
            ) from exc

        if response.status_code == status.HTTP_401_UNAUTHORIZED:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="OLib token invalid"
            )
        if response.status_code == status.HTTP_403_FORBIDDEN:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="OLib user forbidden")
        if response.status_code >= 500:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="OLib auth service error",
            )
        if response.status_code >= 400:
            raise HTTPException(status_code=response.status_code, detail=response.text)

        try:
            envelope = response.json()
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Invalid OLib JSON response",
            ) from exc

        if not isinstance(envelope, dict) or envelope.get("success") is not True:
            detail = (
                envelope.get("detail") or envelope.get("message")
                if isinstance(envelope, dict)
                else None
            )
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=detail or "OLib business response failed",
            )
        return envelope.get("data")
