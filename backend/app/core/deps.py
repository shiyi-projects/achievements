"""Shared FastAPI dependencies."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.db.session import get_session
from app.services.list_service import ensure_system_lists
from app.services.olib_client import OlibClient
from app.services.user_service import is_allowed_role, upsert_olib_user

_security = HTTPBearer(auto_error=False)


async def get_current_user_id(
    settings: Annotated[Settings, Depends(get_settings)],
    session: Annotated[AsyncSession, Depends(get_session)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_security)],
) -> UUID:
    """Return the active Achievements user id.

    Development/test mode can keep using ``settings.local_user_id``. When auth is
    enabled, identity is derived from the OLib token and mapped to an internal UUID.
    """
    if not settings.auth_enabled:
        return UUID(settings.local_user_id)

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer token required",
        )

    profile = await OlibClient(settings).profile(credentials.credentials)
    if not is_allowed_role(profile.role):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="OLib user role is not allowed",
        )
    user = await upsert_olib_user(session, profile)
    await ensure_system_lists(session, user.id)
    return user.id


CurrentUserId = Annotated[UUID, Depends(get_current_user_id)]
