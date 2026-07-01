# ============================================================
# FarmEye Guard v1.0 — 多阶段 Dockerfile
# 目标 VPS: Ubuntu 25.04 / 1 vCPU / 1 GB RAM / 35 GB Disk
# ============================================================

# ============================================================
# Stage 1: Base — 共享基础层
# ============================================================
FROM ubuntu:25.04 AS base

LABEL maintainer="FarmEye Guard Team"
LABEL version="v1.0.0"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# 编译依赖：psycopg2 从源码编译，build-essential / python3-dev / libpq-dev 均为必需
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    python3-pip \
    curl \
    ca-certificates \
    build-essential \
    python3-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

# ============================================================
# Stage 2: Dev — 开发阶段（含热重载、测试工具、调试工具）
# ============================================================
FROM base AS dev

RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat-openbsd \
    vim-tiny \
    && rm -rf /var/lib/apt/lists/*

COPY requirements-dev.txt .
RUN pip install -r requirements-dev.txt

COPY . .

EXPOSE 8000

# 开发模式下使用热重载启动
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload", "--reload-dir", "/app"]
HEALTHCHECK --interval=15s --timeout=5s --retries=3 --start-period=10s \
    CMD curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"' || exit 1

# ============================================================
# Stage 3: Prod — 生产阶段（最小化镜像）
# ============================================================
FROM base AS prod

COPY . .

# 复制启动入口脚本，容器启动时自动执行数据库迁移
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8000

# 生产模式：通过 entrypoint.sh 自动执行数据库迁移后启动服务
# 1 vCPU 场景下使用 1 worker
ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--limit-max-requests", "10000"]
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s \
    CMD curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"' || exit 1
