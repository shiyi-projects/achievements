#!/usr/bin/env bash
# 宝塔(BaoTa / aaPanel)VPS 一键启动后端 Docker 容器。
#
# 数据库:Supabase 托管 Postgres —— 连接串写在 .env.prod 的 DATABASE_URL,
#         容器不跑本地 db,直连 Supabase 外网(走 Transaction Pooler 6543 时
#         记得在 .env.prod 设 DATABASE_DISABLE_STATEMENT_CACHE=true)。
# 暴露:  容器只在 127.0.0.1:8084 暴露,由宝塔站点 Nginx 反向代理到你的域名。
#
# 准备:
#   1. 宝塔安装 Docker(软件商店 → Docker 管理器)。
#   2. cp .env.prod.example .env.prod,填入 Supabase DATABASE_URL、JWT_SECRET、
#      APP_CORS_ORIGINS 等真实值(.env.prod 已 gitignore,不会入库)。
#
# 用法:
#   bash start-baota.sh            # 默认 = up:构建镜像 + 数据库迁移 + 启动 + 健康检查
#   bash start-baota.sh up
#   bash start-baota.sh migrate    # 只执行数据库迁移(alembic upgrade head)
#   bash start-baota.sh restart    # 重启容器(不重建镜像)
#   bash start-baota.sh logs       # 跟踪容器日志
#   bash start-baota.sh down       # 停止并移除容器
set -euo pipefail
cd "$(dirname "$0")"

COMPOSE_FILE="docker-compose.baota.yml"
ENV_FILE=".env.prod"
SERVICE="api"
PORT="8084"

# 兼容 docker compose v2 插件与老版 docker-compose
if docker compose version >/dev/null 2>&1; then
  DC=(docker compose -f "$COMPOSE_FILE")
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose -f "$COMPOSE_FILE")
else
  echo "未找到 docker compose,请先在宝塔「Docker 管理器」安装 Docker。" >&2
  exit 1
fi

cmd="${1:-up}"

case "$cmd" in
  down)
    "${DC[@]}" down
    exit 0
    ;;
  logs)
    "${DC[@]}" logs -f --tail=200 "$SERVICE"
    exit 0
    ;;
  restart)
    "${DC[@]}" restart "$SERVICE"
    exit 0
    ;;
  up | migrate) ;;
  *)
    echo "未知命令: $cmd (可用: up | migrate | restart | logs | down)" >&2
    exit 2
    ;;
esac

# up / migrate 都需要 .env.prod
if [[ ! -f "$ENV_FILE" ]]; then
  echo "缺少 $ENV_FILE。" >&2
  echo "请先执行: cp .env.prod.example $ENV_FILE,并填入 Supabase DATABASE_URL / JWT_SECRET / APP_CORS_ORIGINS。" >&2
  exit 1
fi

echo "==> 构建镜像"
"${DC[@]}" build

# 用一次性容器跑迁移(覆盖 service 的 command 为 alembic),连的是 .env.prod 里的 Supabase
echo "==> 数据库迁移:alembic upgrade head → Supabase"
"${DC[@]}" run --rm --no-deps "$SERVICE" alembic upgrade head

if [[ "$cmd" == "migrate" ]]; then
  echo "==> 迁移完成(未启动服务)。"
  exit 0
fi

echo "==> 启动容器"
"${DC[@]}" up -d

# 健康检查(容器端口映射在 127.0.0.1:${PORT})
url="http://127.0.0.1:${PORT}/api/v1/healthz"
echo -n "==> 等待健康检查 ${url} "
for _ in $(seq 1 30); do
  if curl -fsS "$url" >/dev/null 2>&1; then
    echo
    echo "✅ 后端已就绪:${url}"
    echo "   下一步:在宝塔为你的域名配置反向代理 → http://127.0.0.1:${PORT}"
    echo "   查看日志:bash start-baota.sh logs"
    exit 0
  fi
  sleep 1
  echo -n "."
done

echo
echo "⚠️  健康检查超时,最近日志如下:" >&2
"${DC[@]}" logs --tail=80 "$SERVICE" >&2
exit 1
