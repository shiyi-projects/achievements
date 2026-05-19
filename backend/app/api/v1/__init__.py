"""v1 API router aggregation."""

from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import auth, folders, health, lists, tags, tasks

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(folders.router, prefix="/folders", tags=["folders"])
api_router.include_router(lists.router, prefix="/lists", tags=["lists"])
api_router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
api_router.include_router(tags.router, prefix="/tags", tags=["tags"])
