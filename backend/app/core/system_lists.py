"""Built-in system list kinds.

与 frontend ``lib/core/constants.dart`` 的 SystemListKind 保持一致;新增项
两边须同步,前后端通过 ``system_kind`` 字符串值耦合。

系统清单 UUID 必须按用户确定性生成,否则多用户后端会在 ``task_lists.id``
主键上冲突。前后端共用同一个 UUIDv5 namespace 与 name 规则:
``{user_id}:{system_kind}``。
"""

from __future__ import annotations

from enum import StrEnum
from uuid import UUID, uuid5


class SystemListKind(StrEnum):
    INBOX = "inbox"
    TODAY = "today"
    IMPORTANT = "important"
    PLANNED = "planned"
    ALL = "all"
    COMPLETED = "completed"
    TRASH = "trash"


SYSTEM_LIST_DISPLAY_NAMES: dict[SystemListKind, str] = {
    SystemListKind.INBOX: "Inbox",
    SystemListKind.TODAY: "Today",
    SystemListKind.IMPORTANT: "Important",
    SystemListKind.PLANNED: "Planned",
    SystemListKind.ALL: "All Tasks",
    SystemListKind.COMPLETED: "Completed",
    SystemListKind.TRASH: "Trash",
}

SYSTEM_LIST_NAMESPACE = UUID("4c57f2ec-6db5-5c34-a7b0-6f6c2a8c5d2f")

LEGACY_SYSTEM_LIST_IDS: dict[SystemListKind, UUID] = {
    SystemListKind.INBOX: UUID("01900000-0000-7000-8000-000000000001"),
    SystemListKind.TODAY: UUID("01900000-0000-7000-8000-000000000002"),
    SystemListKind.IMPORTANT: UUID("01900000-0000-7000-8000-000000000003"),
    SystemListKind.PLANNED: UUID("01900000-0000-7000-8000-000000000004"),
    SystemListKind.ALL: UUID("01900000-0000-7000-8000-000000000005"),
    SystemListKind.COMPLETED: UUID("01900000-0000-7000-8000-000000000006"),
    SystemListKind.TRASH: UUID("01900000-0000-7000-8000-000000000007"),
}


def system_list_id_for_user(user_id: UUID, kind: SystemListKind) -> UUID:
    return uuid5(SYSTEM_LIST_NAMESPACE, f"{user_id}:{kind.value}")
