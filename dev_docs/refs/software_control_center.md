# 对接:software_control_center（SCC · 统一身份中台）

> 被引用项目：`D:\SoftwareData\platform\software_control_center`（🏛️ 平台身份+支付底座）
> 用途：Achievements 的**登录身份与访问门禁收口到 SCC**（替换原 OLib/wxauth 方案）。
> 权威契约：SCC `dev_docs/client_integration_guide.md`、`dev_docs/jwt_contract.md`、`dev_docs/platform_overview.md`。
> 最后更新：2026-07-07

## 一、接入范围（本期）

- **只做身份门禁**：用 SCC 的**微信公众号扫码登录**签发 client token 作为全局唯一鉴权凭据；
  Achievements 后端**离线验签**该 token 识别用户，不再回调任何身份服务。
- **硬切 OLib**：`olib_client.py` 与 wxauth 方案已整体移除；旧 OLib 会话/云数据不迁移。
- **门禁口径**：任何 SCC 登录成功用户即放行（SCC 无 role 概念，去掉旧 `authorized/community/admin` 白名单）。
  token 里的 `in_wecom`（社群成员）仅作展示，未设为门槛。
- **暂不做**：开放平台网站应用扫码（wechat-web，原生需内嵌 WebView 拦截 redirect，另期）、
  授权码/订阅付费门槛（`licenses/*`、`pay/*`）、积分（`credits/*`）。

## 二、用到的 SCC 端点（前缀 `/api/v1/client`）

| 方法 | 路径 | 用途 | 谁调 |
|------|------|------|------|
| GET | `/auth/wechat-qr?app_id=` | 生成公众号登录二维码 → `{scene_id, qrcode_url, expire_seconds}` | Achievements 后端代理 |
| GET | `/auth/wechat-qr/status/{scene_id}` | 轮询扫码状态；`confirmed` 时返回 `{status, user_id, nickname, token, unionid?, in_wecom}` | Achievements 后端代理 |

- 登录经**后端代理**（`app/services/scc_client.py`），对 Flutter 屏蔽 SCC 地址与 `app_id`。
- Flutter 只调 Achievements 自己的 `/api/v1/auth/qrcode`、`/api/v1/auth/status?scene_id=`（形状不变，去掉了原 register/anon_token 环节）。

## 三、Token 契约（HS256 对称，离线验签）

- 算法 `HS256`，密钥 = SCC `.env` 的 `JWT_SECRET_KEY`，经**安全渠道**同步到 Achievements 后端 `SCC_JWT_SECRET`（**仅验签、不签发；不入库、不进日志**）。
- claim：`sub`（SCC AppUser.id，字符串）、`type:"client"`、`exp`；微信登录还带 `openid`、`unionid`（绑开放平台时）、`in_wecom`。
- 验签步骤（`app/core/scc_auth.py::decode_client_token`）：HS256 验签（留 60s 时钟容差）→ 校验 `exp` → 校验 `type=="client"` → 取 `sub`/`unionid`/`openid`/`in_wecom`；任一不合法一律 401。
- 身份映射（`upsert_scc_user`）：本地 `users` 表 `provider="scc"`、`provider_user_id=sub`（本 app 内稳定唯一，作主键）、存 `unionid`/`openid`/`nickname`。

## 四、配置项（`backend/.env`，见 `.env.example`）

```
AUTH_ENABLED=true            # 生产开启;dev 默认 false 走单用户占位
SCC_BASE_URL=<SCC 可达地址>
SCC_APP_ID=<SCC 后台注册 Achievements 得到>
SCC_JWT_SECRET=<= SCC 的 JWT_SECRET_KEY,安全渠道同步>
SCC_JWT_ALG=HS256
```

## 五、待 SCC 侧准备（provisioning，运营/管理员）

1. 在 SCC 后台注册 **Achievements** 应用 → 得 `app_id`，设 `bundle_id`（Windows/Android 平台）。
2. 确认 SCC 侧**公众号凭据已配置**（shiyi-tools/MindSet 已在用，通常就绪）。
3. 通过安全渠道把 `JWT_SECRET_KEY` 给 Achievements 后端填 `SCC_JWT_SECRET`。
4. 部署后回填 `SCC_BASE_URL`（后端能访问即可，Flutter 不直连 SCC）。

> 无需 SCC 改代码（两个扫码端点已存在），故未在 SCC 仓库建 `req_Achievements.md`；
> 若日后要付费门槛/积分再按需提需求。

## 六、降级与容灾（照 SCC 接入指南 §8）

- **已登录用户**：token 本地可验签，SCC 宕机不影响已持票用户的正常使用（直到 `exp`）。
- **登录**：依赖 SCC 在线（身份层本职）；SCC 不可用时扫码登录不可用。
- 本地已存 `unionid`（跨端锚点）+ token；不缓存任何计费/授权裁决（本期无此类能力）。

## 七、关键文件

| 层 | 文件 |
|----|------|
| 验签 | `backend/app/core/scc_auth.py` |
| 登录代理 | `backend/app/services/scc_client.py` |
| 身份收口 | `backend/app/core/deps.py`（`get_current_user_id`） |
| 身份映射 | `backend/app/services/user_service.py`（`upsert_scc_user`） |
| 路由 | `backend/app/api/v1/auth.py`（qrcode/status/logout） |
| 迁移 | `backend/alembic/versions/f1e2d3c4b5a6_add_unionid_to_users.py` |
| 前端 | `frontend/lib/features/auth/`（repository/session/qr_login_page） |
