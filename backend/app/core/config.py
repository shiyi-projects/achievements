"""Application settings loaded from environment variables."""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    app_env: Literal["development", "test", "production"] = "development"
    app_debug: bool = True
    app_host: str = "0.0.0.0"  # noqa: S104 — container/dev only; reverse proxy fronts prod
    app_port: int = 8000
    app_cors_origins: list[str] = Field(default_factory=list)

    # Database
    database_url: str = "postgresql+asyncpg://achievements:achievements@db:5432/achievements"

    # Redis
    redis_url: str = "redis://redis:6379/0"

    # Storage
    storage_backend: Literal["local", "oss"] = "local"
    storage_local_root: str = "./storage/attachments"

    # Auth (placeholder for Phase 0)
    auth_enabled: bool = False
    local_user_id: str = "00000000-0000-0000-0000-000000000001"
    jwt_secret: str = "change-me-in-production"  # noqa: S105 — placeholder default; override via env
    jwt_alg: str = "HS256"
    jwt_access_ttl_min: int = 30
    jwt_refresh_ttl_days: int = 14

    @field_validator("app_cors_origins", mode="before")
    @classmethod
    def _split_cors(cls, value: object) -> object:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
