"""FastAPI application entry point."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from uuid import UUID

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app import __version__
from app.api.v1 import api_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.db.session import SessionLocal
from app.services.list_service import ensure_system_lists


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    configure_logging(debug=settings.app_debug)
    # Local/dev mode keeps the placeholder user; production auth seeds per real user lazily.
    if not settings.auth_enabled:
        async with SessionLocal() as session:
            await ensure_system_lists(session, UUID(settings.local_user_id))
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Achievements API",
        version=__version__,
        debug=settings.app_debug,
        lifespan=lifespan,
    )

    if settings.app_cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.app_cors_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.include_router(api_router)

    @app.get("/", include_in_schema=False)
    async def root() -> dict[str, str]:
        return {
            "name": "Achievements API",
            "version": __version__,
            "docs": "/docs",
            "health": "/api/v1/healthz",
        }

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(_request: Request, exc: Exception) -> JSONResponse:
        # 生产环境应接入结构化日志/Sentry;此处先统一返回 500。
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error", "type": type(exc).__name__},
        )

    return app


app = create_app()
