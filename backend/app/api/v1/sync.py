"""Sync REST endpoints (pull + push)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.client_version import require_supported_client
from app.core.deps import CurrentUserId
from app.db.session import get_session
from app.schemas.sync import SyncPullResponse, SyncPushRequest, SyncPushResponse
from app.services import sync_service

# 两个端点都挡旧客户端:pull 下发的清单树旧端同样解释不了。
router = APIRouter(dependencies=[Depends(require_supported_client)])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.get("/pull", response_model=SyncPullResponse)
async def pull(
    session: SessionDep,
    user_id: CurrentUserId,
    since: Annotated[datetime | None, Query()] = None,
) -> SyncPullResponse:
    return await sync_service.pull(session, user_id, since)


@router.post("/push", response_model=SyncPushResponse)
async def push(
    payload: SyncPushRequest,
    session: SessionDep,
    user_id: CurrentUserId,
) -> SyncPushResponse:
    return await sync_service.push(session, user_id, payload)
