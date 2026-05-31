"""Auth router backed by OLib/WeChat QR login."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.db.session import get_session
from app.schemas.auth import (
    AuthRegisterRequest,
    AuthRegisterResponse,
    AuthStatusResponse,
    LogoutResponse,
    QrCodeResponse,
)
from app.services.list_service import ensure_system_lists
from app.services.olib_client import OlibClient
from app.services.user_service import is_allowed_role, upsert_olib_user

router = APIRouter()
_security = HTTPBearer(auto_error=False)

SessionDep = Annotated[AsyncSession, Depends(get_session)]
SettingsDep = Annotated[Settings, Depends(get_settings)]
BearerDep = Annotated[HTTPAuthorizationCredentials | None, Depends(_security)]


def _bearer_token(credentials: HTTPAuthorizationCredentials | None) -> str:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer token required",
        )
    return credentials.credentials


@router.post("/register", response_model=AuthRegisterResponse)
async def register(
    payload: AuthRegisterRequest,
    settings: SettingsDep,
) -> AuthRegisterResponse:
    return await OlibClient(settings).register(payload)


@router.get("/qrcode", response_model=QrCodeResponse)
async def qrcode(
    credentials: BearerDep,
    settings: SettingsDep,
) -> QrCodeResponse:
    anon_token = _bearer_token(credentials)
    return await OlibClient(settings).qrcode(anon_token)


@router.get("/status", response_model=AuthStatusResponse)
async def auth_status(
    credentials: BearerDep,
    settings: SettingsDep,
    session: SessionDep,
) -> AuthStatusResponse:
    anon_token = _bearer_token(credentials)
    client = OlibClient(settings)
    data = await client.status(anon_token)
    status_value = data.get("status")
    if status_value != "authorized":
        return AuthStatusResponse(status="unauthorized")

    token = data.get("token")
    olib_user_id = data.get("user_id")
    if not isinstance(token, str) or olib_user_id is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="OLib authorized response missing token/user_id",
        )

    profile = await client.profile(token)
    if not is_allowed_role(profile.role):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="OLib user role is not allowed",
        )

    user = await upsert_olib_user(session, profile)
    await ensure_system_lists(session, user.id)
    return AuthStatusResponse(
        status="authorized",
        token=token,
        olib_user_id=int(olib_user_id),
        app_user_id=user.id,
        profile=profile,
    )


@router.post("/logout", response_model=LogoutResponse)
async def logout() -> LogoutResponse:
    # OLib currently exposes no user-token revocation endpoint.
    # The client clears local session state.
    return LogoutResponse()
