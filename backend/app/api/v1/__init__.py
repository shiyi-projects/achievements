"""v1 API router aggregation."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import (
    achievements,
    auth,
    focus_sessions,
    health,
    stats,
    sync,
    tags,
    tasks,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
# 清单与文件夹没有 REST 端点:客户端 local-first,清单树的读写一律走 /sync。
api_router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
api_router.include_router(tags.router, prefix="/tags", tags=["tags"])
api_router.include_router(sync.router, prefix="/sync", tags=["sync"])
api_router.include_router(focus_sessions.router, prefix="/focus-sessions", tags=["focus-sessions"])
api_router.include_router(achievements.router, prefix="/achievements", tags=["achievements"])
api_router.include_router(stats.router, prefix="/stats", tags=["stats"])
