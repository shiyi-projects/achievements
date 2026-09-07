"""Authentication DTOs for SCC WeChat MP QR login."""

from __future__ import annotations

from typing import Literal
from uuid import UUID

from pydantic import BaseModel, HttpUrl


class QrCodeResponse(BaseModel):
    """公众号扫码登录二维码(后端代理 SCC 生成)。"""

    qr_url: HttpUrl
    scene_id: str
    expire_seconds: int


class UserProfile(BaseModel):
    """登录成功后回给客户端的用户资料(来自 SCC)。"""

    id: int  # SCC user_id
    nickname: str | None = None
    avatar_url: str | None = None
    openid: str | None = None
    unionid: str | None = None
    in_wecom: bool = False


class AuthStatusResponse(BaseModel):
    status: Literal["unauthorized", "authorized"]
    token: str | None = None  # SCC client token(全局唯一鉴权凭据)
    app_user_id: UUID | None = None  # Achievements 内部用户 UUID
    profile: UserProfile | None = None


class RenewResponse(BaseModel):
    """滑动续期结果:新 client token 与其有效期(秒)。"""

    token: str
    expires_in: int


class LogoutResponse(BaseModel):
    success: bool = True
