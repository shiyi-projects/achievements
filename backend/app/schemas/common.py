"""Shared Pydantic schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    app_env: str
    version: str
    timestamp: datetime
