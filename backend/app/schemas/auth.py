"""Authentication DTOs for OLib/WeChat QR login."""

from __future__ import annotations

from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, HttpUrl

AllowedOlibRole = Literal["authorized", "community", "admin"]
OlibRole = Literal["unauthorized", "authorized", "community", "admin", "banned"]


class AuthRegisterRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=64)
    platform: Literal["android", "windows", "ios", "other"] = "other"


class AuthRegisterResponse(BaseModel):
    anon_token: str
    expires_in: int


class QrCodeResponse(BaseModel):
    qr_url: HttpUrl
    expire_seconds: int


class AuthStatusResponse(BaseModel):
    status: Literal["unauthorized", "authorized"]
    token: str | None = None
    olib_user_id: int | None = None
    app_user_id: UUID | None = None
    profile: UserProfile | None = None


class UserProfile(BaseModel):
    id: int
    device_id: str | None = None
    openid: str | None = None
    nickname: str | None = None
    avatar_url: str | None = None
    platform: str | None = None
    role: OlibRole


class LogoutResponse(BaseModel):
    success: bool = True
