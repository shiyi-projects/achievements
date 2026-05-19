"""Built-in system list kinds.

与 frontend ``lib/core/constants.dart`` 的 SystemListKind 保持一致;新增项
两边须同步,前后端通过 ``system_kind`` 字符串值耦合。

每个 kind 还绑定一个固定 UUID(``SYSTEM_LIST_IDS``),前后端 seed 时都使用
同一个 id,确保 sync pull 落库时通过主键命中既有行(insertOnConflictUpdate)
而非新增,从而避免 Sidebar 出现重复系统清单。
"""

from __future__ import annotations

from enum import StrEnum
from uuid import UUID


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

# 固定主键。UUIDv7 形状(版本位=7,变体位=8),末尾计数器对应 kind 索引。
# 前后端必须共用这张表,否则一端 seed 的 id 与另一端不同,pull 会重复落行。
SYSTEM_LIST_IDS: dict[SystemListKind, UUID] = {
    SystemListKind.INBOX: UUID("01900000-0000-7000-8000-000000000001"),
    SystemListKind.TODAY: UUID("01900000-0000-7000-8000-000000000002"),
    SystemListKind.IMPORTANT: UUID("01900000-0000-7000-8000-000000000003"),
    SystemListKind.PLANNED: UUID("01900000-0000-7000-8000-000000000004"),
    SystemListKind.ALL: UUID("01900000-0000-7000-8000-000000000005"),
    SystemListKind.COMPLETED: UUID("01900000-0000-7000-8000-000000000006"),
    SystemListKind.TRASH: UUID("01900000-0000-7000-8000-000000000007"),
}
