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
    # 数据库保活间隔(小时)。Supabase free tier 闲置约 7 天自动暂停,周期性
    # SELECT 1 维持活跃;<= 0 禁用(自托管库无需保活时可关)。
    db_keepalive_interval_hours: float = 6.0

    # Redis
    redis_url: str = "redis://redis:6379/0"

    # Storage
    storage_backend: Literal["local", "oss"] = "local"
    storage_local_root: str = "./storage/attachments"

    # Auth — 身份收口到 SCC(软件控制中心)统一身份中台
    auth_enabled: bool = False
    local_user_id: str = "00000000-0000-0000-0000-000000000001"
    # SCC 客户端接入:后端代理公众号扫码登录,并用共享密钥离线验签 client JWT。
    # 部署时把下面三项在 .env 回填(scc_jwt_secret 走安全渠道,不入库)。
    scc_base_url: str = "https://scc.example.com"
    scc_app_id: int = 0
    scc_jwt_secret: str = "change-me-shared-with-scc"  # noqa: S105 — 占位;SCC 的 JWT_SECRET_KEY,仅验签
    scc_jwt_alg: str = "HS256"
    scc_timeout_seconds: float = 8.0

    @field_validator("app_cors_origins", mode="before")
    @classmethod
    def _split_cors(cls, value: object) -> object:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
