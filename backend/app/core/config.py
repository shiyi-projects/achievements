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
    app_port: int = 8084
    app_cors_origins: list[str] = Field(default_factory=list)

    # Database
    database_url: str = "postgresql+asyncpg://achievements:achievements@db:5432/achievements"
    # 走 Supabase Transaction Pooler(端口 6543)等不持有连接的 PgBouncer 兼容池时需开启,
    # 否则 asyncpg 的预编译语句缓存会与连接复用冲突。直连/Session Pooler 保持 false 性能更好。
    database_disable_statement_cache: bool = False

    # Redis
    redis_url: str = "redis://redis:6379/0"

    # Storage
    storage_backend: Literal["local", "oss"] = "local"
    storage_local_root: str = "./storage/attachments"

    # Auth
    auth_enabled: bool = False
    local_user_id: str = "00000000-0000-0000-0000-000000000001"
    jwt_secret: str = "change-me-in-production"  # noqa: S105 — placeholder default; override via env
    jwt_alg: str = "HS256"
    jwt_access_ttl_min: int = 30
    jwt_refresh_ttl_days: int = 14
    olib_base_url: str = "https://wxauth.11xy.cn"
    olib_timeout_seconds: float = 8.0
    auth_profile_cache_ttl_seconds: int = 60

    @field_validator("app_cors_origins", mode="before")
    @classmethod
    def _split_cors(cls, value: object) -> object:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
