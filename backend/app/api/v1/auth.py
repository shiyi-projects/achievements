"""Auth router backed by SCC WeChat MP QR login.

后端代理 SCC 公众号扫码登录:取二维码 → 轮询扫码状态。SCC 在 ``confirmed`` 时
返回 client token,后端离线验签并映射到内部用户,再把 token 透传给客户端;此后
所有业务请求带该 token,由 ``core.deps`` 离线验签识别身份。
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.scc_auth import decode_client_token
from app.db.session import get_session
from app.schemas.auth import (
    AuthStatusResponse,
    LogoutResponse,
    QrCodeResponse,
    RenewResponse,
    UserProfile,
)
from app.services.list_service import ensure_system_lists
from app.services.scc_client import SccClient
from app.services.user_service import upsert_scc_user

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]
SettingsDep = Annotated[Settings, Depends(get_settings)]

_security = HTTPBearer(auto_error=False)
CredentialsDep = Annotated[HTTPAuthorizationCredentials | None, Depends(_security)]


@router.get("/qrcode", response_model=QrCodeResponse)
async def qrcode(settings: SettingsDep) -> QrCodeResponse:
    data = await SccClient(settings).create_wechat_qr()
    return QrCodeResponse(
        qr_url=data["qrcode_url"],
        scene_id=data["scene_id"],
        expire_seconds=data["expire_seconds"],
    )


@router.get("/status", response_model=AuthStatusResponse)
async def auth_status(
    scene_id: str,
    settings: SettingsDep,
    session: SessionDep,
) -> AuthStatusResponse:
    data = await SccClient(settings).poll_wechat_qr(scene_id)
    if data.get("status") != "confirmed":
        return AuthStatusResponse(status="unauthorized")

    token = data.get("token")
    if not isinstance(token, str):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="SCC confirmed response missing token",
        )

    # 用共享密钥验签 SCC token,既取身份也顺带自检本地密钥与 SCC 一致
    claims = decode_client_token(token, settings)
    nickname = data.get("nickname")
    user = await upsert_scc_user(
        session,
        claims,
        nickname=nickname if isinstance(nickname, str) else None,
    )
    await ensure_system_lists(session, user.id)

    user_id_raw = data.get("user_id")
    return AuthStatusResponse(
        status="authorized",
        token=token,
        app_user_id=user.id,
        profile=UserProfile(
            id=int(user_id_raw) if user_id_raw is not None else int(claims.sub),
            nickname=nickname if isinstance(nickname, str) else None,
            avatar_url=user.avatar_url,
            openid=claims.openid,
            unionid=claims.unionid,
            in_wecom=claims.in_wecom,
        ),
    )


@router.post("/renew", response_model=RenewResponse)
async def renew(
    credentials: CredentialsDep,
    settings: SettingsDep,
    session: SessionDep,
) -> RenewResponse:
    """滑动续期当前 client token,免去 8h 到期后重新扫码。

    公众号扫码登录无法静默重复,所以长期使用只能在 token 过期前换发新的。
    这里先本地验签(过期/伪造直接 401,不白跑一趟 SCC),再代理 SCC 换发,
    并用新 claims 回写本地身份映射(``unionid`` 补绑、``in_wecom`` 变更)。
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Bearer token required",
        )

    # 本地先验一遍:token 已过期时 SCC 也只会回 401,没必要往上游发请求。
    decode_client_token(credentials.credentials, settings)

    data = await SccClient(settings).renew_client_token(credentials.credentials)
    token = data.get("token")
    if not isinstance(token, str):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="SCC renew response missing token",
        )

    # 新 token 的 claims 是重算的,回写一次让本地 unionid / 昵称跟上 SCC。
    claims = decode_client_token(token, settings)
    await upsert_scc_user(session, claims)

    expires_in = data.get("expires_in")
    return RenewResponse(
        token=token,
        expires_in=expires_in if isinstance(expires_in, int) else 0,
    )


@router.post("/logout", response_model=LogoutResponse)
async def logout() -> LogoutResponse:
    # SCC client token 无服务端吊销端点;客户端清本地会话即可,token 到期自然失效。
    return LogoutResponse()
