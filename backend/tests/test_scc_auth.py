"""SCC client token 离线验签 + 身份门禁测试。"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
import pytest
from fastapi import HTTPException
from httpx import AsyncClient

from app.core.config import Settings, get_settings
from app.core.scc_auth import decode_client_token
from app.main import app as fastapi_app

SECRET = "test-shared-secret"


def _settings(**overrides: Any) -> Settings:
    base: dict[str, Any] = {
        "auth_enabled": True,
        "scc_jwt_secret": SECRET,
        "scc_jwt_alg": "HS256",
    }
    base.update(overrides)
    return Settings(**base)


def _auth_settings() -> Settings:
    """零参 get_settings 覆盖(FastAPI 依赖覆盖必须零参)。"""
    return _settings()


def _token(
    secret: str = SECRET,
    *,
    sub: str | None = "42",
    token_type: str | None = "client",
    exp_delta: timedelta = timedelta(hours=1),
    **extra: Any,
) -> str:
    payload: dict[str, Any] = {"exp": datetime.now(UTC) + exp_delta, **extra}
    if sub is not None:
        payload["sub"] = sub
    if token_type is not None:
        payload["type"] = token_type
    return jwt.encode(payload, secret, algorithm="HS256")


# ── 单元:decode_client_token ──


def test_decode_valid_returns_claims() -> None:
    token = _token(unionid="oUnion_x", openid="oOpen_x", in_wecom=True)
    claims = decode_client_token(token, _settings())
    assert claims.sub == "42"
    assert claims.unionid == "oUnion_x"
    assert claims.openid == "oOpen_x"
    assert claims.in_wecom is True


def test_decode_unionid_optional() -> None:
    claims = decode_client_token(_token(), _settings())
    assert claims.sub == "42"
    assert claims.unionid is None
    assert claims.in_wecom is False


def test_decode_expired_rejected() -> None:
    token = _token(exp_delta=timedelta(minutes=-5))
    with pytest.raises(HTTPException) as exc:
        decode_client_token(token, _settings())
    assert exc.value.status_code == 401


def test_decode_wrong_signature_rejected() -> None:
    token = _token(secret="a-different-secret")
    with pytest.raises(HTTPException) as exc:
        decode_client_token(token, _settings())
    assert exc.value.status_code == 401


def test_decode_wrong_type_rejected() -> None:
    token = _token(token_type="admin")
    with pytest.raises(HTTPException) as exc:
        decode_client_token(token, _settings())
    assert exc.value.status_code == 401


def test_decode_missing_sub_rejected() -> None:
    token = _token(sub=None)
    with pytest.raises(HTTPException) as exc:
        decode_client_token(token, _settings())
    assert exc.value.status_code == 401


# ── 集成:受保护端点门禁(经真实依赖注入) ──


@pytest.mark.asyncio
async def test_protected_route_requires_token(client: AsyncClient) -> None:
    fastapi_app.dependency_overrides[get_settings] = _auth_settings
    resp = await client.get("/api/v1/tasks")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_protected_route_accepts_valid_scc_token(client: AsyncClient) -> None:
    fastapi_app.dependency_overrides[get_settings] = _auth_settings
    resp = await client.get(
        "/api/v1/tasks",
        headers={"Authorization": f"Bearer {_token()}"},
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
