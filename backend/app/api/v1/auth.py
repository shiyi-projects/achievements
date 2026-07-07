"""Auth router backed by SCC WeChat MP QR login.

后端代理 SCC 公众号扫码登录:取二维码 → 轮询扫码状态。SCC 在 ``confirmed`` 时
返回 client token,后端离线验签并映射到内部用户,再把 token 透传给客户端;此后
所有业务请求带该 token,由 ``core.deps`` 离线验签识别身份。
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.scc_auth import decode_client_token
from app.db.session import get_session
from app.schemas.auth import (
    AuthStatusResponse,
    LogoutResponse,
    QrCodeResponse,
    UserProfile,
)
from app.services.list_service import ensure_system_lists
from app.services.scc_client import SccClient
from app.services.user_service import upsert_scc_user

router = APIRouter()

SessionDep = Annotated[AsyncSession, Depends(get_session)]
SettingsDep = Annotated[Settings, Depends(get_settings)]


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


@router.post("/logout", response_model=LogoutResponse)
async def logout() -> LogoutResponse:
    # SCC client token 无服务端吊销端点;客户端清本地会话即可,token 到期自然失效。
    return LogoutResponse()
