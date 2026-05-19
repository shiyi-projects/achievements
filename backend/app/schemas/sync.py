"""Sync protocol DTOs.

Phase 2 step 1 同步引擎契约:客户端按 cursor(server-side updated_at)
做增量拉取与批量推送。
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.schemas.folder import FolderRead
from app.schemas.tag import TagRead
from app.schemas.task import TaskRead
from app.schemas.task_list import TaskListRead


class TaskTagRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    task_id: UUID
    tag_id: UUID
    created_at: datetime


class SyncPullResponse(BaseModel):
    """`since` 为空时为首次同步;非空只回 updated_at > since 的增量。

    所有返回行 **包含软删条目** (deleted_at != null),客户端据此本地软删。
    `cursor` 是服务端拉取这一瞬的 ``now``,客户端下一次 pull 时回传。
    """

    cursor: datetime
    folders: list[FolderRead]
    lists: list[TaskListRead]
    tasks: list[TaskRead]
    tags: list[TagRead]
    task_tags: list[TaskTagRead]


# ---- Push mutations(下个 commit 实装服务端;此处先定义契约,前后端可同时演进) ----


MutationEntity = Literal["folder", "list", "task", "tag", "task_tag"]
MutationOp = Literal["upsert", "delete"]


class Mutation(BaseModel):
    entity: MutationEntity
    op: MutationOp
    id: UUID
    base_version: int = 0
    payload: dict[str, object] = {}


class SyncPushRequest(BaseModel):
    device_id: UUID | None = None
    mutations: list[Mutation]


class MutationResult(BaseModel):
    entity: MutationEntity
    id: UUID
    status: Literal["applied", "conflict", "rejected"]
    version: int = 0
    # 冲突时回填服务端最新行(reuse 实体 Read schema 的 dict 形式)
    server_value: dict[str, object] | None = None


class SyncPushResponse(BaseModel):
    cursor: datetime
    results: list[MutationResult]
