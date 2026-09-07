"""SCC 客户端接口代理:公众号扫码登录取二维码 / 轮询状态。

登录用后端代理转发到 SCC,对 Flutter 屏蔽 SCC 地址与 app_id;登录态(client
token)则由客户端持有、后端离线验签(见 ``app.core.scc_auth``)。
"""

from __future__ import annotations

from typing import Any

import httpx
from fastapi import HTTPException, status

from app.core.config import Settings


class SccClient:
    def __init__(self, settings: Settings) -> None:
        self._base_url = settings.scc_base_url.rstrip("/")
        self._app_id = settings.scc_app_id
        self._timeout = settings.scc_timeout_seconds

    async def create_wechat_qr(self) -> dict[str, Any]:
        """生成公众号登录二维码 → {scene_id, qrcode_url, expire_seconds}。"""
        return await self._request(
            "GET",
            "/api/v1/client/auth/wechat-qr",
            params={"app_id": self._app_id},
        )

    async def poll_wechat_qr(self, scene_id: str) -> dict[str, Any]:
        """轮询扫码状态 → {status, user_id?, nickname?, token?, unionid?, in_wecom?}。"""
        return await self._request(
            "GET",
            f"/api/v1/client/auth/wechat-qr/status/{scene_id}",
        )

    async def renew_client_token(self, token: str) -> dict[str, Any]:
        """滑动续期:拿未过期的 client token 换发新 token → {token, expires_in}。

        公众号扫码无法静默重复,长期使用只能靠本端点续期(SCC
        ``client_integration_guide.md`` §3.3.2)。SCC 侧会重算 claims
        (``in_wecom`` 实时重查、``unionid`` 取当前值),故新 token 可能与旧的不等价。
        旧 token 已过期时 SCC 回 401,原样透传给客户端让其重新扫码。
        """
        return await self._request(
            "POST",
            "/api/v1/client/auth/renew",
            headers={"Authorization": f"Bearer {token}"},
        )

    async def _request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        try:
            async with httpx.AsyncClient(base_url=self._base_url, timeout=self._timeout) as client:
                response = await client.request(method, path, params=params, headers=headers)
        except httpx.TimeoutException as exc:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="SCC auth service timed out",
            ) from exc
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="SCC auth service unavailable",
            ) from exc

        if response.status_code >= status.HTTP_500_INTERNAL_SERVER_ERROR:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="SCC auth service error",
            )
        if response.status_code >= status.HTTP_400_BAD_REQUEST:
            raise HTTPException(status_code=response.status_code, detail=response.text)

        try:
            data = response.json()
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Invalid SCC JSON response",
            ) from exc
        if not isinstance(data, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unexpected SCC response shape",
            )
        return data
