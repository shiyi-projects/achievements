"""SCC client JWT 离线验签。

SCC(软件控制中心)是本项目的统一身份中台,登录后签发 HS256 client token。
下游持同一 ``JWT_SECRET_KEY`` 本地验签即可取用户身份,**无需每请求回调 SCC**。
契约见 SCC ``dev_docs/jwt_contract.md`` 与 ``client_integration_guide.md``。
"""

from __future__ import annotations

from dataclasses import dataclass

import jwt
from fastapi import HTTPException, status
from jwt import InvalidTokenError

from app.core.config import Settings

# exp 校验留 60s 时钟容差,防机器时间微差导致误判(见 SCC platform_overview §7.3)。
_CLOCK_SKEW_SECONDS = 60


@dataclass(frozen=True)
class SccClientClaims:
    """从 SCC client token 解出的用户身份。"""

    sub: str  # SCC AppUser.id(字符串);本域内稳定唯一,作本地用户主键
    unionid: str | None  # 跨端统一身份锚点;仅微信登录且已绑开放平台时存在
    openid: str | None
    in_wecom: bool  # 是否企业微信客户群成员(社群权益软门槛)


def decode_client_token(token: str, settings: Settings) -> SccClientClaims:
    """验签 SCC client token 并取身份;任何不合法一律抛 401。"""
    try:
        payload = jwt.decode(
            token,
            settings.scc_jwt_secret,
            algorithms=[settings.scc_jwt_alg],
            leeway=_CLOCK_SKEW_SECONDS,
        )
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="SCC token invalid or expired",
        ) from exc

    if payload.get("type") != "client":
        # 拒绝管理端 token / 其他类型,只认客户端登录态
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not a SCC client token",
        )

    sub = payload.get("sub")
    if not isinstance(sub, str) or not sub:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="SCC token missing subject",
        )

    unionid = payload.get("unionid")
    openid = payload.get("openid")
    return SccClientClaims(
        sub=sub,
        unionid=unionid if isinstance(unionid, str) else None,
        openid=openid if isinstance(openid, str) else None,
        in_wecom=bool(payload.get("in_wecom", False)),
    )
