"""Built-in system list kinds.

与 frontend ``lib/core/constants.dart`` 的 SystemListKind 保持一致;新增项
两边须同步,前后端通过 ``system_kind`` 字符串值耦合。
"""

from __future__ import annotations

from enum import StrEnum


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
