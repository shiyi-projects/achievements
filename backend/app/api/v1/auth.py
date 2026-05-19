"""Auth router — placeholder.

Phase 0 暂不启用真实鉴权,所有端点返回 501,前端不应调用。
启用时:
1. 实现 Argon2 密码哈希、JWT 签发/刷新;
2. 在 ``app.core.deps.get_current_user_id`` 中改为解析 JWT;
3. 把 ``settings.auth_enabled`` 切到 ``true``。
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr

router = APIRouter()


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    display_name: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"  # noqa: S105 — OAuth2 token_type literal, not a credential


def _not_implemented() -> None:
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Auth is disabled in Phase 0. All requests use the local-user placeholder.",
    )


@router.post("/register", response_model=TokenPair, status_code=status.HTTP_501_NOT_IMPLEMENTED)
async def register(payload: RegisterRequest) -> TokenPair:
    del payload
    _not_implemented()
    raise AssertionError("unreachable")  # for type-checker


@router.post("/login", response_model=TokenPair, status_code=status.HTTP_501_NOT_IMPLEMENTED)
async def login(payload: LoginRequest) -> TokenPair:
    del payload
    _not_implemented()
    raise AssertionError("unreachable")


@router.post("/refresh", response_model=TokenPair, status_code=status.HTTP_501_NOT_IMPLEMENTED)
async def refresh() -> TokenPair:
    _not_implemented()
    raise AssertionError("unreachable")


@router.post("/logout", status_code=status.HTTP_501_NOT_IMPLEMENTED)
async def logout() -> None:
    _not_implemented()
