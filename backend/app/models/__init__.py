"""ORM model aggregator.

只 import 模型即可触发它们注册到 ``Base.metadata``,Alembic autogenerate 与
``Base.metadata.create_all`` 都依赖此聚合。
"""

from app.models.achievement import Achievement, UserAchievement
from app.models.focus_session import FocusSession
from app.models.folder import Folder
from app.models.tag import Tag
from app.models.task import Task
from app.models.task_list import TaskList
from app.models.task_tag import TaskTag

__all__ = [
    "Achievement",
    "FocusSession",
    "Folder",
    "Tag",
    "Task",
    "TaskList",
    "TaskTag",
    "UserAchievement",
]
