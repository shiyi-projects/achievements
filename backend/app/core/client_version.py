"""同步协议的客户端版本门槛。

清单树取代文件夹之后(alembic a1f4c7d92b30),``entity="folder"`` 的 mutation
在服务端已无处可落。与其让旧客户端把请求重试成死信、把用户的数据卡在本地,
不如在入口处明确拒绝并告诉它去升级。

判定方式:请求头 ``X-Client-Version``。低于 [MIN_CLIENT_VERSION] 或缺失
(旧版本根本不发这个头)一律 426 Upgrade Required。
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Header, HTTPException, status

# 支持清单树协议的最早客户端版本。
MIN_CLIENT_VERSION = (0, 4, 0)

UPGRADE_REQUIRED_CODE = "client_upgrade_required"


def _parse(version: str) -> tuple[int, int, int] | None:
    """解析 ``1.2.3``,忽略 ``+build`` / ``-pre`` 后缀,缺位补 0。"""
    core = version.strip().lstrip("v").split("+")[0].split("-")[0]
    parts = core.split(".")
    if not parts or not parts[0]:
        return None
    try:
        nums = [int(p) for p in parts[:3]]
    except ValueError:
        return None
    while len(nums) < 3:
        nums.append(0)
    return nums[0], nums[1], nums[2]


async def require_supported_client(
    x_client_version: Annotated[str | None, Header()] = None,
) -> None:
    """FastAPI 依赖:旧客户端直接挡在同步端点之外。"""
    parsed = None if x_client_version is None else _parse(x_client_version)
    if parsed is None or parsed < MIN_CLIENT_VERSION:
        raise HTTPException(
            status_code=status.HTTP_426_UPGRADE_REQUIRED,
            detail={
                "code": UPGRADE_REQUIRED_CODE,
                "message": (
                    "客户端版本过旧,无法与当前服务端同步。请升级到 "
                    f"{'.'.join(str(p) for p in MIN_CLIENT_VERSION)} 或更新版本。"
                ),
            },
        )
