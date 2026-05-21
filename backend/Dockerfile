# ============ Builder ============
FROM python:3.13-slim AS builder

# 国内服务器 build 时通过 docker-compose args 传入:
#   PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
#   USE_CN_MIRROR=true
# 海外服务器默认走官方源，无需改动
ARG PIP_INDEX_URL=https://pypi.org/simple/

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 安装 uv（仅用于从 uv.lock 导出 requirements.txt）
RUN pip install --no-cache-dir -i ${PIP_INDEX_URL} uv

WORKDIR /app

# 创建 venv 供 runtime 阶段复用
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 先复制锁文件（最大化 Docker 层缓存：依赖不变时跳过安装）
COPY pyproject.toml uv.lock ./

# 核心策略：
#   uv sync --frozen 会使用 uv.lock 中硬编码的 files.pythonhosted.org URL
#   国内服务器访问极慢，所以改为：
#   1. uv export 导出纯文本 requirements.txt（只有包名+版本，无 URL）
#   2. pip install -i 阿里云镜像 安装
RUN uv export --frozen --no-dev --no-emit-project -o requirements.txt \
    && pip install --no-cache-dir -i ${PIP_INDEX_URL} -r requirements.txt

# 复制项目源码（不需要 pip install . ，直接 COPY 即可）
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./

# ============ Runtime ============
FROM python:3.13-slim AS runtime

ARG USE_CN_MIRROR=false

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# 国内镜像：替换 Debian 源为阿里云加速 apt-get
RUN if [ "$USE_CN_MIRROR" = "true" ]; then \
      sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources; \
    fi

# 安装 curl 用于 healthcheck
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 1000 app \
    && useradd  --system --uid 1000 --gid app --create-home --shell /usr/sbin/nologin app

WORKDIR /app

# 从 builder 阶段复制 venv 和源码
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/app ./app
COPY --from=builder /app/alembic ./alembic
COPY --from=builder /app/alembic.ini ./

# storage 目录由 compose volume 挂载；此处创建空目录方便容器单独调试
RUN mkdir -p /app/storage/attachments && chown -R app:app /app

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsS http://localhost:8000/api/v1/healthz || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
