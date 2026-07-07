"""Shared FastAPI dependencies."""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.scc_auth import decode_client_token
from app.db.session import get_session
from app.services.list_service import ensure_system_lists
from app.services.user_service import upsert_scc_user

_security = HTTPBearer(auto_error=False)


async def get_current_user_id(
    settings: Annotated[Settings, Depends(get_settings)],
    session: Annotated[AsyncSession, Depends(get_session)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_security)],
) -> UUID:
    """Return the active Achievements user id.

    Development/test mode keeps using ``settings.local_user_id``. When auth is
    enabled, identity comes from the SCC client token — verified offline with the
    shared secret (no per-request callback) and mapped to an internal UUID.
    """
    if not settings.auth_enabled:
        return UUID(settings.local_user_id)

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer token required",
        )

    claims = decode_client_token(credentials.credentials, settings)
    user = await upsert_scc_user(session, claims)
    await ensure_system_lists(session, user.id)
    return user.id


CurrentUserId = Annotated[UUID, Depends(get_current_user_id)]
