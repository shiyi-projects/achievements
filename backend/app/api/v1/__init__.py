"""v1 API router aggregation."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import (
    achievements,
    auth,
    focus_sessions,
    folders,
    health,
    lists,
    stats,
    sync,
    tags,
    tasks,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(folders.router, prefix="/folders", tags=["folders"])
api_router.include_router(lists.router, prefix="/lists", tags=["lists"])
api_router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
api_router.include_router(tags.router, prefix="/tags", tags=["tags"])
api_router.include_router(sync.router, prefix="/sync", tags=["sync"])
api_router.include_router(
    focus_sessions.router, prefix="/focus-sessions", tags=["focus-sessions"]
)
api_router.include_router(
    achievements.router, prefix="/achievements", tags=["achievements"]
)
api_router.include_router(stats.router, prefix="/stats", tags=["stats"])
