# VPS 后端开发与容器化详细设计和测试方案

## 目录

1. [Python API 后端 (FastAPI) 本地开发与容器化方案](#1-python-api-后端-fastapi-本地开发与容器化方案)
2. [金仓数据库 (KingbaseES) 适配与持久化方案](#2-金仓数据库-kingbasees-适配与持久化方案)
3. [VPS 部署方案](#3-vps-部署方案)
4. [测试方案](#4-测试方案)
5. [开发工作流](#5-开发工作流)
6. [附录：完整配置文件与脚本清单](#6-附录完整配置文件与脚本清单)

---

## 1. Python API 后端 (FastAPI) 本地开发与容器化方案

### 1.1 本地开发环境配置

#### 1.1.1 Python 版本与虚拟环境

```
Python 版本: 3.13.x（Ubuntu 25.04 默认 Python 版本；亦可额外安装 python3.12 使用）
虚拟环境工具: venv（标准库自带）
```

创建与激活虚拟环境：

```bash
# 在 server/ 目录下
python3 -m venv .venv

# Windows PowerShell
.venv\Scripts\Activate.ps1

# Linux / macOS
source .venv/bin/activate
```

#### 1.1.2 依赖管理

采用 `requirements.txt` + `requirements-dev.txt` 双层策略：

**`server/requirements.txt`**（生产依赖）：

```
fastapi==0.115.x
uvicorn[standard]==0.32.x
sqlalchemy==2.0.x
psycopg2-binary==2.9.x
alembic==1.14.x
pydantic==2.10.x
pydantic-settings==2.7.x
httpx==0.28.x
python-multipart==0.0.18
openpyxl==3.1.x
apscheduler==3.10.x
```

**`server/requirements-dev.txt`**（开发额外依赖）：

```
-r requirements.txt
pytest==8.3.x
pytest-asyncio==0.24.x
pytest-cov==6.0.x
httpx==0.28.x
sqlalchemy-utils==0.41.x
black==24.10.x
ruff==0.8.x
mypy==1.13.x
```

安装：

```bash
pip install -r requirements-dev.txt
```

#### 1.1.3 环境变量模板

**`server/.env.template`**（开发环境）：

```ini
# 应用配置
APP_NAME=FarmEye API
APP_VERSION=v1.0.0
APP_DEBUG=true
APP_ENV=development

# 数据库连接（开发环境使用 SQLite 或本地 KingbaseES）
# SQLite 模式（无需安装数据库，适合快速开发）
DATABASE_URL=sqlite:///./data/farmeye_dev.db
# KingbaseES 模式（Docker 运行本地 KingbaseES 时使用）
# DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db

# IoTDA 配置
IOTDA_ENDPOINT=https://iotda.cn-north-4.myhuaweicloud.com
IOTDA_PROJECT_ID=your_project_id_here

# API 安全
API_KEYS=dev_key_001,dev_key_002

# 业务配置
ADVISORY_WINDOW_MINUTES=60
IMAGE_STORAGE_PATH=./data/images
DATA_RETENTION_SENSOR_DAYS=30
DATA_RETENTION_CONTROL_DAYS=90

# CORS（开发环境允许所有来源）
CORS_ORIGINS=*

# 日志级别
LOG_LEVEL=DEBUG
```

**`server/.env.prod.template`**（生产环境）：

```ini
# 应用配置
APP_NAME=FarmEye API
APP_VERSION=v1.0.0
APP_DEBUG=false
APP_ENV=production

# 数据库连接（Docker 内网连接 KingbaseES）
DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@db:5432/farmeye_db

# IoTDA 配置
IOTDA_ENDPOINT=https://iotda.cn-north-4.myhuaweicloud.com
IOTDA_PROJECT_ID=your_project_id_here

# API 安全
API_KEYS=prod_key_001,prod_key_002

# 业务配置
ADVISORY_WINDOW_MINUTES=60
IMAGE_STORAGE_PATH=/app/images
DATA_RETENTION_SENSOR_DAYS=30
DATA_RETENTION_CONTROL_DAYS=90

# CORS（生产环境限制为具体来源）
CORS_ORIGINS=http://localhost:8000,http://your-vps-ip:8000

# 日志级别
LOG_LEVEL=INFO
```

`server/.env` 文件（本地开发用，从 `.env.template` 复制并修改）已加入 `.gitignore`。

#### 1.1.4 配置管理类

`server/app/config.py`：

```python
from pydantic_settings import BaseSettings
from typing import List
import os


class Settings(BaseSettings):
    # 应用
    app_name: str = "FarmEye API"
    app_version: str = "v1.0.0"
    app_debug: bool = False
    app_env: str = "development"

    # 数据库
    database_url: str = "sqlite:///./data/farmeye_dev.db"

    # IoTDA
    iotda_endpoint: str = "https://iotda.cn-north-4.myhuaweicloud.com"
    iotda_project_id: str = ""

    # API 安全
    api_keys: str = ""  # 逗号分隔

    # 业务
    advisory_window_minutes: int = 60
    image_storage_path: str = "./data/images"
    data_retention_sensor_days: int = 30
    data_retention_control_days: int = 90

    # CORS
    cors_origins: str = "*"

    # 日志
    log_level: str = "INFO"

    @property
    def api_key_list(self) -> List[str]:
        return [k.strip() for k in self.api_keys.split(",") if k.strip()]

    @property
    def cors_origin_list(self) -> List[str]:
        if self.cors_origins == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
```

#### 1.1.5 热重载开发启动

```bash
# 开发模式启动（自动重载）
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 --log-level debug

# 或通过 main.py 入口
python app/main.py  # 内部自动根据 APP_DEBUG 决定是否启用 reload
```

`server/app/main.py` 入口设计：

```python
import uvicorn
from fastapi import FastAPI
from app.config import settings

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    debug=settings.app_debug,
)

# 注册路由、中间件、事件处理器...

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.app_debug,
        log_level=settings.log_level.lower(),
    )
```

---

### 1.2 Dockerfile 设计

#### 1.2.1 多阶段构建策略

采用三阶段构建：`base`（依赖安装）→ `dev`（开发镜像）→ `prod`（生产镜像）。基于 Ubuntu 25.04 LTS 镜像，与 VPS 操作系统一致。

**`server/Dockerfile`**：

```dockerfile
# ============================================================
# Stage 1: base — 基础依赖安装
# ============================================================
FROM ubuntu:25.04 AS base

LABEL maintainer="FarmEye Guard Team"
LABEL description="FarmEye Guard Python API Backend"

# 避免交互式 apt 提示
ENV DEBIAN_FRONTEND=noninteractive

# 安装系统依赖（Ubuntu 25.04 默认 Python 为 3.13）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    python3-pip \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 创建虚拟环境（使用系统默认 Python 3.13）
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 复制依赖文件
COPY requirements.txt /tmp/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# ============================================================
# Stage 2: dev — 开发镜像（包含开发依赖和热重载）
# ============================================================
FROM base AS dev

# 复制开发依赖
COPY requirements-dev.txt /tmp/requirements-dev.txt
RUN pip install --no-cache-dir -r /tmp/requirements-dev.txt && \
    rm /tmp/requirements-dev.txt

# 设置工作目录
WORKDIR /app

# 复制源码
COPY . /app

# 确保数据目录存在
RUN mkdir -p /app/data/images

# 暴露端口
EXPOSE 8000

# 开发环境默认使用热重载启动
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload", "--log-level", "debug"]

# ============================================================
# Stage 3: prod — 生产镜像（最小化、安全）
# ============================================================
FROM base AS prod

# 设置工作目录
WORKDIR /app

# 复制源码（不包含测试和开发文件）
COPY app/ /app/app/
COPY alembic.ini /app/
COPY alembic/ /app/alembic/

# 创建非 root 用户运行
RUN useradd --no-create-home --shell /bin/false farmeye && \
    mkdir -p /app/data/images && \
    chown -R farmeye:farmeye /app/data

# 健康检查
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"' || exit 1

# 切换到非 root 用户
USER farmeye

# 暴露端口
EXPOSE 8000

# 生产环境启动（多 worker 在本方案中为 1）
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--log-level", "info"]
```

#### 1.2.2 `.dockerignore`

**`server/.dockerignore`**：

```
.git
.gitignore
__pycache__/
*.pyc
.venv/
.venv_old/
.env
.env.local
*.db
data/images/
tests/
.pytest_cache/
.mypy_cache/
.ruff_cache/
```

### 1.3 docker-compose.yml 设计

整合 API 和 KingbaseES 数据库。KingbaseES 镜像说明：当前 `kingbase/kb_v8` 镜像在 Docker Hub 上无公开版本，实际部署时需自行从人大金仓官网获取镜像或替换为第三方兼容镜像（说明见后续章节）。

**`server/docker-compose.yml`**（开发/生产通用版，通过 `.env` 区分）：

```yaml
version: "3.9"

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: ${DOCKER_TARGET:-prod}   # 默认生产，开发时设为 dev
    container_name: farmeye-api
    ports:
      - "8000:8000"
    environment:
      - APP_NAME=${APP_NAME:-FarmEye API}
      - APP_VERSION=${APP_VERSION:-v1.0.0}
      - APP_DEBUG=${APP_DEBUG:-false}
      - APP_ENV=${APP_ENV:-production}
      - DATABASE_URL=postgresql+psycopg2://${DB_USER:-farmeye}:${DB_PASSWORD:-farmeye_pwd}@db:5432/${DB_NAME:-farmeye_db}
      - IOTDA_ENDPOINT=${IOTDA_ENDPOINT:-https://iotda.cn-north-4.myhuaweicloud.com}
      - IOTDA_PROJECT_ID=${IOTDA_PROJECT_ID:-}
      - API_KEYS=${API_KEYS:-dev_key_001}
      - ADVISORY_WINDOW_MINUTES=${ADVISORY_WINDOW_MINUTES:-60}
      - IMAGE_STORAGE_PATH=/app/images
      - DATA_RETENTION_SENSOR_DAYS=${DATA_RETENTION_SENSOR_DAYS:-30}
      - DATA_RETENTION_CONTROL_DAYS=${DATA_RETENTION_CONTROL_DAYS:-90}
      - CORS_ORIGINS=${CORS_ORIGINS:-*}
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
    volumes:
      - images_data:/app/images
      # 开发模式挂载源码以实现热重载
      - ${SOURCE_MOUNT:-./app}:/app/app
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:8000/api/v1/health | grep -q '\"status\":\"healthy\"' || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    # 资源限制（适配 1GB RAM VPS）
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
    networks:
      - farmeye-net

  db:
    image: ${DB_IMAGE:-kingbase/kb_v8:V008R006C008B0020}
    container_name: farmeye-db
    ports:
      - "127.0.0.1:5432:5432"   # 仅本地回环
    environment:
      - DB_USER=${DB_USER:-farmeye}
      - DB_PASSWORD=${DB_PASSWORD:-farmeye_pwd}
      - DB_NAME=${DB_NAME:-farmeye_db}
      # KingbaseES 内存配置（适配 1GB RAM VPS）
      - KB_SHARED_BUFFERS=${KB_SHARED_BUFFERS:-128MB}
      - KB_EFFECTIVE_CACHE_SIZE=${KB_EFFECTIVE_CACHE_SIZE:-256MB}
      - KB_WORK_MEM=${KB_WORK_MEM:-16MB}
      - KB_MAINTENANCE_WORK_MEM=${KB_MAINTENANCE_WORK_MEM:-32MB}
    volumes:
      - db_data:/var/lib/kingbase/data
      - ./init-scripts:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-farmeye} -d ${DB_NAME:-farmeye_db} || (ksql -U ${DB_USER:-farmeye} -c 'SELECT 1' 2>/dev/null) || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 384M
        reservations:
          memory: 256M
    networks:
      - farmeye-net

volumes:
  db_data:
    driver: local
  images_data:
    driver: local

networks:
  farmeye-net:
    driver: bridge
```

### 1.4 生产/开发配置分离策略

| 维度 | 开发配置 | 生产配置 |
|------|---------|---------|
| Docker 目标阶段 | `DOCKER_TARGET=dev` | `DOCKER_TARGET=prod`（默认） |
| 热重载 | 启用（--reload） | 禁用 |
| 日志级别 | DEBUG | INFO |
| 数据库 | SQLite 或本地 Docker KingbaseES | Docker 内网 KingbaseES |
| CORS | `*` | 限定具体来源 |
| API Key 认证 | 可关闭或使用 dev_key | 强制启用 |
| 源码挂载 | 挂载本地目录到容器 | 镜像内固化 |
| 数据目录 | 本地 `./data/` | Volume 持久化 |
| Worker 数 | 1（reload 模式只支持 1） | 1（单 worker） |

通过 `.env` 文件（本地开发）和 docker-compose 的环境变量覆盖实现：

```bash
# 开发模式启动
cd server
DOCKER_TARGET=dev docker compose up

# 生产模式启动
docker compose up -d
```

### 1.5 健康检查配置

健康检查已在 Dockerfile 和 docker-compose.yml 中配置。关键参数：

```
test:       curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"'
interval:   15s
timeout:    5s
retries:    3
start_period: 30s
```

`GET /api/v1/health` 接口逻辑：

```python
# 响应示例
{
  "code": 0,
  "message": "success",
  "data": {
    "status": "healthy",       # healthy / degraded / unhealthy
    "uptime_seconds": 3600.5,
    "db_connected": true,
    "version": "v1.0.0"
  }
}
```

- `healthy`（HTTP 200）：数据库连接正常
- `degraded`（HTTP 503）：数据库连接失败但服务仍在运行
- `unhealthy`（HTTP 503）：服务内部严重错误

---

## 2. 金仓数据库 (KingbaseES) 适配与持久化方案

### 2.1 KingbaseES Docker 镜像适配方案

#### 2.1.1 镜像获取

KingbaseES V8（`kingbase/kb_v8:V008R006C008B0020`）为人大金仓商业数据库，官方未在 Docker Hub 公开发布。以下为可行的镜像获取和使用方案：

**方案 A（推荐）：自行构建兼容镜像**

金仓数据库提供 x86_64 Linux 的 RPM/DEB 安装包，可基于 Ubuntu 25.04 自行构建 Docker 镜像：

```dockerfile
# server/kingbase/Dockerfile
FROM ubuntu:25.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libnss3 \
    libnspr4 \
    libgcc-s1 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# 复制 KingbaseES V8 安装包并安装（需提前下载）
COPY KingbaseES_V008R006C008B0020_SingleServer_Install.tar.gz /tmp/
RUN tar -xzf /tmp/KingbaseES_V008R006C008B0020_SingleServer_Install.tar.gz -C /opt/ && \
    rm /tmp/KingbaseES_V008R006C008B0020_SingleServer_Install.tar.gz

# 配置 KingbaseES ...
```

**方案 B：使用 PostgreSQL 兼容镜像（开发调试阶段）**

由于 KingbaseES 兼容 PostgreSQL 协议，开发调试阶段可使用 `postgres:16` 镜像替代：

```yaml
# docker-compose 开发覆写
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: farmeye
      POSTGRES_PASSWORD: farmeye_pwd
      POSTGRES_DB: farmeye_db
```

SQLAlchemy 连接字符串完全兼容，只需切换 dialect。生产部署时切回 KingbaseES 镜像。

**方案 C（生产推荐）：使用官方 Docker 镜像**

联系人大金仓获取官方 Docker 镜像（或使用客户提供的私有仓库地址），直接将镜像 pull 到 VPS：

```bash
docker pull your-registry/kingbase/kb_v8:V008R006C008B0020
docker tag your-registry/kingbase/kb_v8:V008R006C008B0020 kingbase/kb_v8:V008R006C008B0020
```

#### 2.1.2 1GB RAM 内存配置优化

KingbaseES（基于 PostgreSQL 内核）的内存参数需根据 1GB VPS 资源谨慎配置。整机内存分配方案：

| 组件 | 分配内存 | 说明 |
|------|---------|------|
| KingbaseES | 384 MB | 数据库核心进程 |
| Python API | 256 MB | FastAPI + uvicorn 单 worker |
| OS + 其他 | 360 MB | Ubuntu 25.04 系统开销 |
| **总计** | **1000 MB** | 在 1GB 范围内 |

KingbaseES 内存参数优化（通过环境变量传递）：

```bash
# 关键内存参数
KB_SHARED_BUFFERS=128MB          # 共享缓冲区，设置为总内存的 1/3 左右
KB_EFFECTIVE_CACHE_SIZE=256MB    # 有效缓存大小，约为总内存的 2/3
KB_WORK_MEM=16MB                 # 排序/哈希操作内存，单连接
KB_MAINTENANCE_WORK_MEM=32MB     # 维护操作（VACUUM、索引创建）内存
KB_MAX_CONNECTIONS=20            # 最大连接数（小规模够用）
KB_RANDOM_PAGE_COST=1.1          # SSD 存储降低随机页成本
```

对应 KingbaseES 的 `kingbase.conf` 配置：

```
# kingbase.conf 关键配置
shared_buffers = 128MB
effective_cache_size = 256MB
work_mem = 16MB
maintenance_work_mem = 32MB
max_connections = 20
random_page_cost = 1.1           # SSD 优化
effective_io_concurrency = 200   # SSD 优化
wal_buffers = 4MB
checkpoint_completion_target = 0.9
```

#### 2.1.3 KingbaseES 镜像健康检查

KingbaseES 兼容 PostgreSQL 的工具链，`pg_isready` 可用作健康检查工具。如果 `pg_isready` 不可用，备用方案：

```bash
# 主方案：pg_isready（KingbaseES 自带）
pg_isready -U farmeye -d farmeye_db

# 备用方案：使用 ksql
ksql -U farmeye -c 'SELECT 1' 2>/dev/null

# 备用方案：TCP 端口探测
nc -z localhost 5432
```

### 2.2 数据库初始化脚本

#### 2.2.1 建表 DDL

**`server/init-scripts/001_create_tables.sql`**：

```sql
-- ============================================================
-- FarmEye Guard 数据库初始化脚本
-- 目标数据库：KingbaseES V8 (PostgreSQL 兼容模式)
-- ============================================================

-- 表 1：sensor_snapshot — 环境数据快照
CREATE TABLE IF NOT EXISTS sensor_snapshot (
    id          BIGSERIAL PRIMARY KEY,
    device_id   VARCHAR(64) NOT NULL,
    mac_addr    VARCHAR(17),
    timestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    temperature DECIMAL(4,1),
    humidity    DECIMAL(4,1),
    light       INT,
    co2         INT,
    soil_n      DECIMAL(5,1),
    soil_p      DECIMAL(5,1),
    soil_k      DECIMAL(5,1),
    distance    INT,
    rssi        SMALLINT,
    ip_addr     VARCHAR(16),
    alarm_flag  INT,

    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sensor_device_time
    ON sensor_snapshot (device_id, timestamp);

COMMENT ON TABLE sensor_snapshot IS '环境数据快照表，每次传感器上报的完整环境参数集合';
COMMENT ON COLUMN sensor_snapshot.distance IS '超声波测距；-1表示超时/无目标';
COMMENT ON COLUMN sensor_snapshot.alarm_flag IS '报警状态位掩码';

-- 表 2：disease_records — 病虫害识别记录
CREATE TABLE IF NOT EXISTS disease_records (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    crop_type       VARCHAR(32) NOT NULL,
    disease_type    VARCHAR(64) NOT NULL,
    confidence      DECIMAL(4,3),
    severity        VARCHAR(16) NOT NULL,
    severity_code   SMALLINT NOT NULL,  -- 1=Mild, 2=Moderate, 3=Severe

    linkage_risk_level  VARCHAR(16),    -- 联动风险等级: low / medium / high
    linkage_detail      VARCHAR(512),   -- 联动分析详情

    image_path      VARCHAR(512),
    action_taken    VARCHAR(128),

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_disease_device_time
    ON disease_records (device_id, timestamp, disease_type);

COMMENT ON TABLE disease_records IS '病虫害识别记录表';
COMMENT ON COLUMN disease_records.severity_code IS '1=Mild, 2=Moderate, 3=Severe';
COMMENT ON COLUMN disease_records.linkage_risk_level IS '联动风险等级: low / medium / high';

-- 表 3：control_logs — 设备控制日志
CREATE TABLE IF NOT EXISTS control_logs (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    command_id      VARCHAR(64),               -- IoTDA 命令 ID
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    command         VARCHAR(64) NOT NULL,
    source          VARCHAR(32) NOT NULL,   -- 'auto' / 'manual_app' / 'manual_pc'
    operator        VARCHAR(64),
    result_code     INT,
    result_msg      VARCHAR(255),

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_control_command_id
    ON control_logs (command_id) WHERE command_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_control_device_time
    ON control_logs (device_id, timestamp);

COMMENT ON TABLE control_logs IS '设备控制日志表';
COMMENT ON COLUMN control_logs.source IS '命令来源: auto / manual_app / manual_pc';

-- 表 4：devices — 设备注册信息
CREATE TABLE IF NOT EXISTS devices (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL UNIQUE,
    device_name     VARCHAR(128),
    mac_addr        VARCHAR(17),
    ip_addr         VARCHAR(16),
    registered_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen       TIMESTAMP,
    online          BOOLEAN DEFAULT FALSE,

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_devices_device_id
    ON devices (device_id);

COMMENT ON TABLE devices IS '设备注册信息表';

-- 表 5：sensor_daily_aggregation — 环境数据日聚合
CREATE TABLE IF NOT EXISTS sensor_daily_aggregation (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    agg_date        DATE NOT NULL,

    avg_temperature DECIMAL(4,1),
    max_temperature DECIMAL(4,1),
    min_temperature DECIMAL(4,1),
    avg_humidity    DECIMAL(4,1),
    max_humidity    DECIMAL(4,1),
    min_humidity    DECIMAL(4,1),
    avg_light       DECIMAL(5,1),
    max_light       INT,
    min_light       INT,
    avg_co2         DECIMAL(6,1),
    max_co2         INT,
    min_co2         INT,

    record_count    INT,              -- 当天原始快照条数

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (device_id, agg_date)
);

CREATE INDEX IF NOT EXISTS idx_agg_device_date
    ON sensor_daily_aggregation (device_id, agg_date);

COMMENT ON TABLE sensor_daily_aggregation IS '环境数据日聚合表，由定时任务每日凌晨生成';
```

#### 2.2.2 种子数据

**`server/init-scripts/002_seed_data.sql`**：

```sql
-- ============================================================
-- 种子数据：设备注册信息
-- ============================================================

INSERT INTO devices (device_id, device_name, mac_addr, ip_addr, registered_at, online)
VALUES
    ('farmeye_guard_ws63', 'FarmEye Guard WS63 #1', 'A1:B2:C3:D4:E5:F6', '192.168.1.100', CURRENT_TIMESTAMP, false)
ON CONFLICT (device_id) DO NOTHING;

-- ============================================================
-- 种子数据：示例传感器快照（过去 1 小时，每 5 分钟一条，共 12 条）
-- ============================================================
INSERT INTO sensor_snapshot (device_id, mac_addr, timestamp, temperature, humidity, light, co2, soil_n, soil_p, soil_k, distance, rssi, ip_addr, alarm_flag)
SELECT
    'farmeye_guard_ws63',
    'A1:B2:C3:D4:E5:F6',
    CURRENT_TIMESTAMP - (INTERVAL '5 minutes') * (11 - n),
    25.0 + (random() * 5 - 2)::DECIMAL(4,1),
    55.0 + (random() * 10 - 5)::DECIMAL(4,1),
    (70 + (random() * 30)::INT) % 101,
    400 + (random() * 100)::INT,
    45.0 + (25.5 + (random() * 3 - 1.5)) * 0.2,
    18.0 + (58.0 + (random() * 5 - 2.5)) * 0.1,
    50.0 + (75.0 + (random() * 10 - 5)) * 0.02,
    120 + (random() * 60)::INT,
    -45 - (random() * 10)::INT,
    '192.168.1.100',
    0
FROM generate_series(0, 11) AS n
ON CONFLICT (device_id, timestamp) DO NOTHING;
```

### 2.3 数据持久化与备份策略

#### 2.3.1 Docker Volume 持久化

数据库数据持久化通过 Docker named volume `db_data` 实现：

```yaml
volumes:
  db_data:
    driver: local
```

Volume 挂载至容器内 `/var/lib/kingbase/data`。Volume 数据存储在宿主机的 Docker 管理目录下（默认 `/var/lib/docker/volumes/server_db_data/_data`）。

#### 2.3.2 自动备份脚本

**`deploy/scripts/backup_db.sh`**：

```bash
#!/bin/bash
# KingbaseES 数据库备份脚本
# 用法: ./backup_db.sh [backup_dir]
# 默认备份到 /opt/farmeye/backups/

set -euo pipefail

BACKUP_DIR="${1:-/opt/farmeye/backups}"
BACKUP_RETENTION_DAYS=14
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="${DB_NAME:-farmeye_db}"
DB_USER="${DB_USER:-farmeye}"
BACKUP_FILE="${BACKUP_DIR}/farmeye_db_${TIMESTAMP}.sql.gz"

# 创建备份目录
mkdir -p "${BACKUP_DIR}"

# 通过 Docker 执行 pg_dump
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup of ${DB_NAME}..."
docker exec farmeye-db pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${BACKUP_FILE}"

# 检查备份是否成功
if [ $? -eq 0 ] && [ -s "${BACKUP_FILE}" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup completed: ${BACKUP_FILE}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Size: $(du -h "${BACKUP_FILE}" | cut -f1)"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Backup failed!"
    rm -f "${BACKUP_FILE}"
    exit 1
fi

# 清理过期备份
find "${BACKUP_DIR}" -name "farmeye_db_*.sql.gz" -mtime +${BACKUP_RETENTION_DAYS} -delete
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Old backups cleaned (retention: ${BACKUP_RETENTION_DAYS} days)"
```

Crontab 配置（每日凌晨 2:00 执行）：

```cron
0 2 * * * /opt/farmeye/scripts/backup_db.sh >> /var/log/farmeye/backup.log 2>&1
```

#### 2.3.3 数据恢复脚本

**`deploy/scripts/restore_db.sh`**：

```bash
#!/bin/bash
# KingbaseES 数据库恢复脚本
# 用法: ./restore_db.sh <backup_file>
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    exit 1
fi

BACKUP_FILE="$1"
DB_NAME="${DB_NAME:-farmeye_db}"
DB_USER="${DB_USER:-farmeye}"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "ERROR: Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting restore of ${DB_NAME} from ${BACKUP_FILE}..."

# 解压并恢复
gunzip -c "${BACKUP_FILE}" | docker exec -i farmeye-db ksql -U "${DB_USER}" "${DB_NAME}"

if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restore completed successfully."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Restore failed!"
    exit 1
fi
```

### 2.4 数据保留与清理策略

#### 2.4.1 策略总览

| 表 | 保留策略 | 清理方式 | 执行时机 |
|----|---------|---------|---------|
| `sensor_snapshot` | 保留最近 30 天明细 | 按天聚合后删除原始明细 | 每日凌晨 3:00 |
| `disease_records` | 永久保留 | 不清理 | — |
| `control_logs` | 保留最近 90 天 | 直接 DELETE 过期记录 | 每日凌晨 3:30 |

#### 2.4.2 数据保留定时任务（Python APScheduler）

`server/app/services/data_retention.py`：

```python
"""
数据保留策略定时任务模块。

使用 APScheduler 实现每日凌晨执行的数据清理和聚合任务。
依赖 settings.data_retention_sensor_days 和 settings.data_retention_control_days 配置。
"""
from datetime import datetime, timedelta
from sqlalchemy import text
from app.db.session import SessionLocal
from app.config import settings


def aggregate_and_clean_sensor_data():
    """
    环境数据日聚合与清理。

    1. 对 retention 期限前的 sensor_snapshot 数据按 (device_id, agg_date) 聚合
    2. 写入 sensor_daily_aggregation 表（INSERT ... ON CONFLICT DO NOTHING）
    3. 删除 retention 期限前的原始 sensor_snapshot 明细
    """
    db = SessionLocal()
    try:
        cutoff_date = datetime.utcnow() - timedelta(days=settings.data_retention_sensor_days)
        cutoff_str = cutoff_date.strftime("%Y-%m-%d")

        # 步骤 1：聚合过期数据到日聚合表
        aggregate_sql = text("""
            INSERT INTO sensor_daily_aggregation (
                device_id, agg_date,
                avg_temperature, max_temperature, min_temperature,
                avg_humidity, max_humidity, min_humidity,
                avg_light, max_light, min_light,
                avg_co2, max_co2, min_co2,
                record_count
            )
            SELECT
                device_id,
                DATE(timestamp) AS agg_date,
                AVG(temperature), MAX(temperature), MIN(temperature),
                AVG(humidity), MAX(humidity), MIN(humidity),
                AVG(light), MAX(light), MIN(light),
                AVG(co2), MAX(co2), MIN(co2),
                COUNT(*) AS record_count
            FROM sensor_snapshot
            WHERE timestamp < :cutoff
            GROUP BY device_id, DATE(timestamp)
            ON CONFLICT (device_id, agg_date) DO NOTHING
        """)
        db.execute(aggregate_sql, {"cutoff": cutoff_str})
        db.commit()

        # 步骤 2：删除过期原始明细
        delete_sql = text("""
            DELETE FROM sensor_snapshot
            WHERE timestamp < :cutoff
        """)
        deleted = db.execute(delete_sql, {"cutoff": cutoff_str}).rowcount
        db.commit()

        print(f"[DataRetention] Sensor data: aggregated and deleted {deleted} records before {cutoff_str}")
    except Exception as e:
        db.rollback()
        print(f"[DataRetention] Sensor data ERROR: {e}")
    finally:
        db.close()


def clean_control_logs():
    """
    控制日志清理。
    删除 retention 期限前的 control_logs 记录。
    """
    db = SessionLocal()
    try:
        cutoff_date = datetime.utcnow() - timedelta(days=settings.data_retention_control_days)
        cutoff_str = cutoff_date.strftime("%Y-%m-%d")

        delete_sql = text("""
            DELETE FROM control_logs
            WHERE timestamp < :cutoff
        """)
        deleted = db.execute(delete_sql, {"cutoff": cutoff_str}).rowcount
        db.commit()

        print(f"[DataRetention] Control logs: deleted {deleted} records before {cutoff_str}")
    except Exception as e:
        db.rollback()
        print(f"[DataRetention] Control logs ERROR: {e}")
    finally:
        db.close()


def init_scheduler(app):
    """初始化 APScheduler 定时任务。"""
    from apscheduler.schedulers.background import BackgroundScheduler

    scheduler = BackgroundScheduler()

    # 每日凌晨 3:00 执行传感器数据聚合与清理
    scheduler.add_job(
        aggregate_and_clean_sensor_data,
        "cron",
        hour=3,
        minute=0,
        id="sensor_data_retention",
        replace_existing=True,
    )

    # 每日凌晨 3:30 执行控制日志清理
    scheduler.add_job(
        clean_control_logs,
        "cron",
        hour=3,
        minute=30,
        id="control_logs_retention",
        replace_existing=True,
    )

    scheduler.start()
```

---

## 3. VPS 部署方案

### 3.1 VPS 初始化配置

#### 3.1.1 初始系统设置

VPS 初始创建后的必要配置步骤：

```bash
# 1. 更新系统包
sudo apt update && sudo apt upgrade -y

# 2. 设置主机名
sudo hostnamectl set-hostname farmeye-vps

# 3. 配置时区（新加坡 UTC+8）
sudo timedatectl set-timezone Asia/Singapore

# 4. 创建部署用户
sudo useradd -m -s /bin/bash farmeye
sudo usermod -aG sudo farmeye

# 5. 配置 SSH 密钥认证（禁用密码登录）
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# 6. 配置 UFW 防火墙
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP（Nginx）
sudo ufw allow 443/tcp    # HTTPS（Nginx，后续可选）
sudo ufw allow 8000/tcp   # API 服务（如不使用 Nginx 反向代理时）
sudo ufw --force enable
sudo ufw status verbose

# 7. 配置系统参数（容器优化）
cat << 'EOF' | sudo tee /etc/sysctl.d/99-docker.conf
net.ipv4.ip_forward = 1
net.core.somaxconn = 65535
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
sudo sysctl --system
```

#### 3.1.2 Docker 安装

```bash
# 1. 卸载旧版本
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg 2>/dev/null || true
done

# 2. 安装 Docker 依赖
sudo apt-get install -y ca-certificates curl

# 3. 添加 Docker 官方 GPG 密钥
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 4. 添加 Docker APT 源（使用动态检测的发行版代号，当前 Ubuntu 25.04 代号为 plucky）
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. 安装 Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. 将部署用户加入 docker 组（避免 sudo）
sudo usermod -aG docker farmeye

# 7. 验证安装
docker --version
docker compose version

# 8. 配置 Docker 守护进程（资源限制优化）
sudo mkdir -p /etc/docker
cat << 'EOF' | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3,
  "storage-driver": "overlay2"
}
EOF
sudo systemctl restart docker
```

> **APT 源说明**：`$(lsb_release -cs)` 在 Ubuntu 25.04 上自动解析为 `plucky`。若 Docker 官方尚未发布 `plucky` 的 APT 源（新版 Ubuntu 发布后 Docker 仓库的更新存在延迟），可临时降级使用 `noble` 源并添加 `--allow-releaseinfo-change` 参数：
> ```bash
> echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | \
>     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
> sudo apt-get update --allow-releaseinfo-change
> ```
> 此方案仅在 Ubuntu 25.04 发布初期 Docker 官方尚未推送 `plucky` 源时作为临时回退。一旦 Docker 发布 `plucky` 源，应立即切换。也建议直接使用 §6.2 的 `curl -fsSL https://get.docker.com | sudo sh` 一键安装脚本（该脚本自动检测 OS 版本和架构，无需手动配置 APT 源）。

#### 3.1.3 Digital Ocean 安全组配置

在 Digital Ocean 控制面板中配置以下防火墙规则（也可通过 DO API 配置）：

| 入站规则 | 协议 | 端口 | 来源 | 说明 |
|---------|------|------|------|------|
| SSH | TCP | 22 | 管理员 IP（或 0.0.0.0/0 配合密钥认证） | SSH 远程管理 |
| HTTP | TCP | 80 | 0.0.0.0/0 | Nginx 反向代理 |
| HTTPS | TCP | 443 | 0.0.0.0/0 | （可选）后续启用 TLS |
| API | TCP | 8000 | 0.0.0.0/0 | 直接暴露 API（仅当不使用 Nginx 时） |
| IoTDA | TCP | 8000 | 华为云 IoTDA 出口 IP 段 | Webhook 接收（最小权限最佳实践） |
| ICMP | — | — | 0.0.0.0/0 | Ping 探测（可选） |

出站规则：允许所有到 0.0.0.0/0 的流量。

> **安全说明**：API 端口 8000 在 UFW 和 DO 安全组中开放公网访问，是因为鸿蒙 App 和上位机从公网直接访问 API。生产环境强烈建议：
> 1. 启用 API Key 认证（`X-API-Key` 头）
> 2. 通过 Nginx 反向代理暴露 API（端口 80/443），8000 端口仅限内网或特定 IP
> 3. 后续添加 Let's Encrypt HTTPS 证书

### 3.2 Docker Compose 部署流程

#### 3.2.1 部署目录结构

VPS 上的部署目录布局：

```
/opt/farmeye/
├── docker-compose.yml          # 主编排文件
├── .env                        # 生产环境变量
├── Dockerfile                  # API 镜像构建文件
├── requirements.txt            # Python 依赖
├── app/                        # API 源码
│   ├── main.py
│   ├── config.py
│   ├── api/
│   ├── models/
│   ├── schemas/
│   ├── services/
│   ├── core/
│   └── db/
├── alembic.ini                 # 数据库迁移配置
├── alembic/                    # 迁移脚本
├── init-scripts/               # 数据库初始化脚本
│   ├── 001_create_tables.sql
│   └── 002_seed_data.sql
├── images/                     # 上传图片存储目录
├── nginx/                      # Nginx 配置
│   └── farmeye.conf
├── scripts/
│   ├── backup_db.sh            # 数据库备份
│   ├── restore_db.sh           # 数据库恢复
│   ├── start.sh                # 启动
│   └── stop.sh                 # 停止
└── logs/                       # 日志目录
    ├── api/
    ├── nginx/
    └── backup/
```

#### 3.2.2 VPS 部署步骤

```bash
# 1. SSH 登录到 VPS
ssh farmeye@<VPS_IP>

# 2. 创建部署目录
sudo mkdir -p /opt/farmeye
sudo chown farmeye:farmeye /opt/farmeye
cd /opt/farmeye

# 3. 部署代码（方式 A：从 Git 仓库拉取）
git clone <YOUR_REPO_URL> /tmp/wheat-tea-iot
cp -r /tmp/wheat-tea-iot/server/* /opt/farmeye/
cp /tmp/wheat-tea-iot/deploy/* /opt/farmeye/

# 3. 部署代码（方式 B：scp 上传）
# 从本地执行：scp -r server/* farmeye@<VPS_IP>:/opt/farmeye/

# 4. 创建 .env 配置文件
cat > /opt/farmeye/.env << 'EOF'
APP_NAME=FarmEye API
APP_VERSION=v1.0.0
APP_DEBUG=false
APP_ENV=production
DB_USER=farmeye
DB_PASSWORD=<change_this_password>
DB_NAME=farmeye_db
IOTDA_ENDPOINT=https://iotda.cn-north-4.myhuaweicloud.com
IOTDA_PROJECT_ID=<your_iotda_project_id>
API_KEYS=<prod_key_001>,<prod_key_002>
ADVISORY_WINDOW_MINUTES=60
DATA_RETENTION_SENSOR_DAYS=30
DATA_RETENTION_CONTROL_DAYS=90
CORS_ORIGINS=http://localhost:8000,http://<VPS_IP>:8000
LOG_LEVEL=INFO
EOF

# 5. 创建日志和图片目录
mkdir -p /opt/farmeye/logs/api /opt/farmeye/logs/nginx /opt/farmeye/logs/backup
mkdir -p /opt/farmeye/images

# 6. 拉取/构建镜像并启动
cd /opt/farmeye
docker compose pull
docker compose up -d --build

# 7. 验证部署
docker compose ps
docker compose logs --tail=20 api
curl -s http://localhost:8000/api/v1/health | jq .

# 8. 查看启动日志
docker compose logs -f
```

#### 3.2.3 生产环境 docker-compose override

**`deploy/docker-compose.prod.yml`**（生产覆写文件）：

```yaml
version: "3.9"

services:
  api:
    # 生产镜像直接构建
    build:
      context: /opt/farmeye
      dockerfile: Dockerfile
      target: prod
    # 不挂载源码目录
    environment:
      - APP_DEBUG=false
      - APP_ENV=production
    restart: always
    # 日志驱动遵循 daemon.json 配置

  db:
    restart: always
    # 适配 1GB RAM
    environment:
      - KB_SHARED_BUFFERS=128MB
      - KB_EFFECTIVE_CACHE_SIZE=256MB
      - KB_WORK_MEM=16MB
      - KB_MAINTENANCE_WORK_MEM=32MB

  nginx:
    image: nginx:1.27-alpine
    container_name: farmeye-nginx
    ports:
      - "80:80"
      # HTTPS 端口预留
      # - "443:443"
    volumes:
      - ./nginx/farmeye.conf:/etc/nginx/conf.d/farmeye.conf:ro
      - ./images:/usr/share/nginx/images:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - api
    restart: always
    deploy:
      resources:
        limits:
          memory: 64M
        reservations:
          memory: 32M
    networks:
      - farmeye-net
```

执行部署时合并文件：

```bash
docker compose -f docker-compose.yml -f /opt/farmeye/docker-compose.prod.yml up -d --build
```

### 3.3 Nginx 反向代理配置

#### 3.3.1 基础反向代理

**`deploy/nginx/farmeye.conf`**：

```nginx
upstream farmeye_api {
    server api:8000;
    keepalive 16;
}

server {
    listen 80;
    server_name _;  # 替换为实际域名或 IP

    # 请求体大小限制（图片上传最大 10MB + 少量余量）
    client_max_body_size 12M;

    # 超时配置
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Gzip 压缩
    gzip on;
    gzip_types application/json text/plain text/css text/xml;
    gzip_min_length 1000;
    gzip_proxied any;

    # API 反向代理
    location /api/ {
        proxy_pass http://farmeye_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 禁用缓冲（实时性优先）
        proxy_buffering off;
    }

    # 静态图片服务
    location /images/ {
        alias /usr/share/nginx/images/;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # 健康检查（透传）
    location /api/v1/health {
        proxy_pass http://farmeye_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        # 不记录健康检查到访问日志
        access_log off;
    }

    # 默认路由
    location / {
        return 404;
    }
}
```

#### 3.3.2 启用 Nginx 服务

```yaml
# 在 docker-compose.yml 中新增 nginx 服务
services:
  nginx:
    image: nginx:1.27-alpine
    container_name: farmeye-nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx/farmeye.conf:/etc/nginx/conf.d/farmeye.conf:ro
      - ./images:/usr/share/nginx/images:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - api
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 64M
    networks:
      - farmeye-net
```

使用 Nginx 后，API 的对外暴露方式变更：
- 公网 → Nginx (80) → FastAPI (8000, 内网)
- VPS UFW 可关闭 8000 端口，仅开放 80

### 3.4 日志收集与管理方案

#### 3.4.1 日志层级

| 日志来源 | 存储位置 | 轮转策略 | 保留周期 |
|---------|---------|---------|---------|
| API 应用日志 | Docker stdout（json-file driver） | Docker 内置（max-size 10m, max-file 3） | 容器重建覆盖 |
| Nginx 访问日志 | `./logs/nginx/access.log` | 日志轮转（logrotate） | 30 天 |
| Nginx 错误日志 | `./logs/nginx/error.log` | 日志轮转 | 90 天 |
| 数据库备份日志 | `./logs/backup/backup.log` | 日志轮转 | 90 天 |
| 系统日志 | `/var/log/syslog` | systemd journal | 由系统管理 |

#### 3.4.2 API 日志配置

`server/app/core/logging_config.py`：

```python
import logging
import sys
from app.config import settings


def setup_logging():
    """配置应用日志。"""
    handlers = [logging.StreamHandler(sys.stdout)]

    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s | %(levelname)-8s | %(name)s:%(funcName)s:%(lineno)d | %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
        handlers=handlers,
        force=True,
    )

    # 设置第三方库日志级别
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
```

#### 3.4.3 宿主机日志轮转配置

**`deploy/logrotate/farmeye`**：

```
/opt/farmeye/logs/nginx/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 farmeye farmeye
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 $(cat /var/run/nginx.pid) 2>/dev/null || true
    endscript
}

/opt/farmeye/logs/backup/*.log {
    daily
    rotate 90
    compress
    missingok
    notifempty
    create 0644 farmeye farmeye
}
```

部署 logrotate 配置：

```bash
sudo cp deploy/logrotate/farmeye /etc/logrotate.d/farmeye
sudo chmod 644 /etc/logrotate.d/farmeye
sudo logrotate -d /etc/logrotate.d/farmeye  # 测试
```

#### 3.4.4 查看日志命令速查

```bash
# API 实时日志
docker compose logs -f api

# 最后 50 行 API 日志
docker compose logs --tail=50 api

# Nginx 访问日志
tail -f /opt/farmeye/logs/nginx/access.log

# 备份日志
tail -f /opt/farmeye/logs/backup/backup.log

# 容器资源使用
docker stats --no-stream
```

### 3.5 容器资源限制配置

#### 3.5.1 docker-compose 中的资源声明

已在 `docker-compose.yml` 中通过 `deploy.resources` 配置：

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

  db:
    deploy:
      resources:
        limits:
          memory: 384M
        reservations:
          memory: 256M

  nginx:   # 可选
    deploy:
      resources:
        limits:
          memory: 64M
```

> **注意**：`docker compose` 模式下 `deploy.resources` 默认被 docker-compose 忽略，需通过 `docker compose --compatibility` 模式启动，或直接使用 Docker Run 的 `--memory` 参数。替代方案：直接在 `docker-compose.yml` 使用 `mem_limit`（Compose V2 已弃用，但兼容）。

更可靠的方案——在 `docker-compose.yml` 中使用 `--memory` 等效设置：

```yaml
services:
  api:
    # ...其他配置...
    deploy:
      resources:
        limits:
          memory: 256M
    # 补充限制
    mem_limit: 256m
    mem_reservation: 128m
    cpus: 0.5

  db:
    # ...其他配置...
    deploy:
      resources:
        limits:
          memory: 384M
    mem_limit: 384m
    mem_reservation: 256m
    cpus: 0.5
```

#### 3.5.2 VPS 内存使用预估

| 组件 | 预估内存 | 说明 |
|------|---------|------|
| Ubuntu 25.04 系统 | ~200 MB | 不含图形界面 |
| Docker 守护进程 | ~50 MB | 容器管理开销 |
| KingbaseES 容器 | ~300-384 MB | 含 shared_buffers (128MB) |
| Python API 容器 | ~150-256 MB | 含 uvicorn + Python 运行时 |
| Nginx 容器 | ~30-64 MB | 轻量级反向代理 |
| **总计** | **~730-954 MB** | 在 1GB 范围内有充分余量 |

#### 3.5.3 监控命令

```bash
# 实时容器资源监控
docker stats --no-stream

# 按内存排序显示容器
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}"

# 系统整体内存
free -h

# 磁盘使用
df -h /opt/farmeye
```

### 3.6 启动与停止脚本

#### 3.6.1 启动脚本

**`deploy/scripts/start.sh`**：

```bash
#!/bin/bash
# FarmEye VPS 启动脚本
set -euo pipefail

cd /opt/farmeye

echo "========================================"
echo "  FarmEye Guard VPS Deploy Start"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# 检查 .env 是否存在
if [ ! -f .env ]; then
    echo "ERROR: .env file not found in /opt/farmeye"
    exit 1
fi

# 停止旧容器（如果存在）
echo "[1/3] Stopping existing containers (if any)..."
docker compose down 2>/dev/null || true

# 拉取最新代码（如果是 git 部署）
# git pull origin main

# 构建并启动
echo "[2/3] Building and starting containers..."
docker compose --compatibility up -d --build

# 等待服务就绪
echo "[3/3] Waiting for services to be healthy..."
MAX_RETRIES=12
RETRY_INTERVAL=10
for i in $(seq 1 $MAX_RETRIES); do
    sleep $RETRY_INTERVAL
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/v1/health || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "  API is healthy (HTTP 200)"
        break
    fi
    if [ "$i" = "$MAX_RETRIES" ]; then
        echo "  WARNING: API not healthy after $((MAX_RETRIES * RETRY_INTERVAL))s. Check logs."
    else
        echo "  Waiting... attempt $i/$MAX_RETRIES (HTTP $HTTP_CODE)"
    fi
done

echo "========================================"
echo "  Status:"
docker compose ps
echo ""
echo "  Logs:  docker compose logs -f"
echo "  Stop:  ./scripts/stop.sh"
echo "========================================"
```

#### 3.6.2 停止脚本

**`deploy/scripts/stop.sh`**：

```bash
#!/bin/bash
# FarmEye VPS 停止脚本
set -euo pipefail

cd /opt/farmeye

echo "Stopping FarmEye services..."
docker compose down

echo "All services stopped."
```

#### 3.6.3 重启脚本

**`deploy/scripts/restart.sh`**：

```bash
#!/bin/bash
# FarmEye VPS 重启脚本
cd /opt/farmeye
./scripts/stop.sh
sleep 2
./scripts/start.sh
```

---

## 4. 测试方案

### 4.1 测试框架与组织

#### 4.1.1 测试框架选型

| 测试类型 | 框架 | 说明 |
|---------|------|------|
| 单元测试 | pytest 8.x | Python 主流测试框架 |
| 异步测试 | pytest-asyncio | FastAPI 异步端点测试 |
| 覆盖率 | pytest-cov | 覆盖率报告生成 |
| HTTP 测试 | httpx (AsyncClient) | FastAPI TestClient 兼容 |
| 断言增强 | pytest 内置 assert | 无需额外断言库 |
| Mock | unittest.mock | 标准库 mock |

#### 4.1.2 目录结构

依据架构文档 §5.1 定义的 `server/tests/` 目录：

```
server/tests/
├── __init__.py
├── conftest.py                    # 共享 Fixture（测试数据库、客户端等）
├── test_sensor_api.py             # 传感器 API 测试
├── test_disease_api.py            # 病虫害 API 测试
├── test_command_api.py            # 设备控制 API 测试
├── test_advisory_api.py           # 防治建议 API 测试
├── test_image_api.py              # 图片上传/获取 API 测试
├── test_iotda_webhook.py          # IoTDA Webhook 接收端点测试
├── test_health_api.py             # 健康检查 API 测试
│
├── test_models.py                 # SQLAlchemy 模型测试
├── test_db_integration.py         # 数据库集成测试（DDL + CRUD）
│
├── test_services/
│   ├── __init__.py
│   ├── test_sensor_service.py     # 传感器业务逻辑
│   ├── test_disease_service.py    # 病虫害业务逻辑
│   ├── test_command_service.py    # 命令下发服务
│   ├── test_advisory_service.py   # 防治建议引擎
│   ├── test_iotda_client.py       # IoTDA API 客户端（Mock 测试）
│   └── test_data_retention.py     # 数据保留策略测试
│
├── test_docker_integration.py     # Docker 容器集成测试（标记为 integration）
├── test_e2e.py                    # 端到端测试（标记为 e2e）
├── test_performance.py            # 性能与压力测试（标记为 performance）
│
└── fixtures/                      # 测试夹具数据
    ├── sensor_payload.json        # IoTDA 传感器 Webhook 载荷样本
    ├── ai_payload.json            # IoTDA AI 识别 Webhook 载荷样本
    ├── cmd_response_payload.json  # IoTDA 命令应答 Webhook 载荷样本
    └── seed_data.sql              # 测试种子数据
```

#### 4.1.3 conftest 共享 Fixture

`server/tests/conftest.py` 关键 Fixture 设计：

```python
import pytest
import pytest_asyncio
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.db.session import get_db
from app.config import settings


# === 测试专用 SQLite 内存数据库 Fixture ===
@pytest.fixture(scope="session")
def test_engine():
    """创建测试引擎（使用 SQLite 内存数据库）。"""
    engine = create_engine("sqlite:///./data/test_farmeye.db", connect_args={"check_same_thread": False})
    # 建表
    from app.db.base import Base
    Base.metadata.create_all(bind=engine)
    yield engine
    # 清理测试数据库
    import os
    try:
        os.remove("./data/test_farmeye.db")
    except FileNotFoundError:
        pass  # 数据库文件未创建时跳过清理


@pytest.fixture
def test_db_session(test_engine):
    """提供测试数据库会话，每个测试结束后回滚。"""
    connection = test_engine.connect()
    transaction = connection.begin()
    session = sessionmaker(bind=connection)()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


# === FastAPI TestClient Fixture ===
@pytest.fixture
def client(test_db_session):
    """提供带测试数据库的 FastAPI TestClient。"""

    def override_get_db():
        yield test_db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# === 异步客户端 Fixture ===
@pytest_asyncio.fixture
async def async_client(test_db_session):
    """提供异步 HTTP 客户端用于测试异步端点。"""
    from httpx import AsyncClient, ASGITransport

    def override_get_db():
        yield test_db_session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()
```

### 4.2 API 接口测试

#### 4.2.1 测试用例清单

**A. IoTDA Webhook 接收端点测试 — `test_iotda_webhook.py`**

| # | 测试名称 | 方法 | 路径 | 输入 | 预期结果 |
|---|---------|------|------|------|---------|
| 1 | test_properties_report_success | POST | `/api/v1/iotda/properties/report` | 合法传感器 JSON 载荷（含全部字段） | HTTP 200, `code: 0`, `message: "received"` |
| 2 | test_properties_report_missing_fields | POST | `/api/v1/iotda/properties/report` | 缺少部分非必填字段的载荷 | HTTP 200, 有效字段被写入 | 写入成功, 缺失字段为 NULL |
| 3 | test_properties_report_idempotency | POST | `/api/v1/iotda/properties/report` | 同一载荷发送两次 | HTTP 200, 数据库仅 1 条记录（ON CONFLICT DO NOTHING） |
| 4 | test_properties_report_db_error | POST | `/api/v1/iotda/properties/report` | 数据库不可用时的请求 | HTTP 500, 触发 IoTDA 重试 |
| 5 | test_ai_report_success | POST | `/api/v1/iotda/ai/report` | 合法 AI 识别载荷 | HTTP 200, `code: 0`, `disease_records` 表写入成功 |
| 6 | test_ai_report_idempotency | POST | `/api/v1/iotda/ai/report` | 同一 AI 载荷发送两次 | HTTP 200, 数据库仅 1 条记录 |
| 7 | test_ai_report_severe_triggers_action | POST | `/api/v1/iotda/ai/report` | severity_code=3 的载荷 | HTTP 200, control_logs 表新增自动记录 |
| 8 | test_ai_report_linkage_analysis | POST | `/api/v1/iotda/ai/report` | 有环境数据的载荷 | HTTP 200, disease_records.linkage_risk_level 非空 |
| 9 | test_cmd_response_success | POST | `/api/v1/iotda/cmd/response` | 合法命令应答载荷 | HTTP 200, control_logs.result_code 被更新 |
| 10 | test_cmd_response_unknown_command | POST | `/api/v1/iotda/cmd/response` | command_id 不存在的应答 | HTTP 200, 无更新（非错误） |

**B. 传感器数据查询 — `test_sensor_api.py`**

| # | 测试名称 | 方法 | 路径 | 输入 | 预期结果 |
|---|---------|------|------|------|---------|
| 11 | test_sensor_latest_success | GET | `/api/v1/sensor/latest` | `device_id=farmeye_guard_ws63` | HTTP 200, `data.records` 长度为 1, 所有字段正确 |
| 12 | test_sensor_latest_all_devices | GET | `/api/v1/sensor/latest` | 无参数 | HTTP 200, 返回所有设备最新数据 |
| 13 | test_sensor_latest_no_data | GET | `/api/v1/sensor/latest` | `device_id=nonexistent` | HTTP 200, `data.records` 为空数组 |
| 14 | test_sensor_history_pagination | GET | `/api/v1/sensor/history` | `page=1&page_size=10` | HTTP 200, 有 `total`, `page`, `page_size`, `records` |
| 15 | test_sensor_history_filter_by_time | GET | `/api/v1/sensor/history` | `start&end` 参数 | HTTP 200, 仅返回时间范围内数据 |
| 16 | test_sensor_history_page_size_max | GET | `/api/v1/sensor/history` | `page_size=200`（超最大） | HTTP 200, `page_size` 被截断为 100 |
| 17 | test_sensor_history_page_out_of_range | GET | `/api/v1/sensor/history` | `page=9999` | HTTP 200, `records` 为空数组 |
| 18 | test_sensor_daily_aggregation | GET | `/api/v1/sensor/daily` | `device_id&start&end` | HTTP 200, 返回日聚合数据 |
| 19 | test_device_list | GET | `/api/v1/device/list` | 无参数 | HTTP 200, `data.devices` 包含所有注册设备 |
| 20 | test_device_list_online_status | GET | `/api/v1/device/list` | 无参数 | HTTP 200, `online` 字段反映真实状态 |

**C. 病虫害记录查询 — `test_disease_api.py`**

| # | 测试名称 | 方法 | 路径 | 输入 | 预期结果 |
|---|---------|------|------|------|---------|
| 21 | test_disease_records_list | GET | `/api/v1/disease/records` | 无参数 | HTTP 200, 分页列表 |
| 22 | test_disease_records_filter_crop | GET | `/api/v1/disease/records` | `crop_type=wheat` | HTTP 200, 仅返回小麦记录 |
| 23 | test_disease_records_filter_severity | GET | `/api/v1/disease/records` | `severity=Severe` | HTTP 200, 仅返回严重记录 |
| 24 | test_disease_records_contains_linkage | GET | `/api/v1/disease/records` | 有联动数据的记录 | HTTP 200, 响应含 `linkage_risk_level` 字段 |
| 25 | test_disease_stats | GET | `/api/v1/disease/stats` | 含时间范围 | HTTP 200, 返回 `by_crop`, `by_severity`, `by_disease` 统计 |
| 26 | test_disease_heatmap | GET | `/api/v1/disease/heatmap` | 含时间范围 | HTTP 200, 返回 `heatmap_points` 数组和 `summary` |

**D. 设备控制 — `test_command_api.py`**

| # | 测试名称 | 方法 | 路径 | 输入 | 预期结果 |
|---|---------|------|------|------|---------|
| 27 | test_command_send_success | POST | `/api/v1/command` | 合法命令体 (device_id, command, source) | HTTP 200, `code: 0`, `status: "sent"`, 含 `command_id` |
| 28 | test_command_device_offline | POST | `/api/v1/command` | 离线设备的命令 | HTTP 200, `code: 1003`, 调用 IoTDA |
| 29 | test_command_invalid_params | POST | `/api/v1/command` | 缺少必填字段 | HTTP 422, 参数校验失败 |
| 30 | test_command_unknown_device | POST | `/api/v1/command` | 不存在的 device_id | HTTP 200, `code: 1003` |
| 31 | test_command_logs | GET | `/api/v1/command/logs` | 无参数 | HTTP 200, 分页日志 |
| 32 | test_command_logs_filter_source | GET | `/api/v1/command/logs` | `source=auto` | HTTP 200, 仅返回自动命令 |

**E. 防治建议 — `test_advisory_api.py`**

| # | 测试名称 | 方法 | 路径 | 输入 | 预期结果 |
|---|---------|------|------|------|---------|
| 33 | test_advisory_with_detection | GET | `/api/v1/advisory` | 含病虫害检测记录的 1h 窗口 | HTTP 200, 含 `latest_detection`, `current_env`, `advisory` |
| 34 | test_advisory_no_detection | GET | `/api/v1/advisory` | 窗口内无检测记录 | HTTP 200, `latest_detection` 为 null |
| 35 | test_advisory_env_disease_linkage | GET | `/api/v1/advisory` | 含环境与病虫害数据的窗口 | HTTP 200, `env_disease_linkage` 非空 |
| 36 | test_advisory_auto_action_true | GET | `/api/v1/advisory` | severity_code=3 的记录 | HTTP 200, `auto_action_triggered: true` |
| 37 | test_advisory_custom_window | GET | `/api/v1/advisory` | `window_minutes=30` | HTTP 200, 仅返回 30min 内数据 |

**F. 图片上传/获取 — `test_image_api.py`**

| # | 测试名称 | 方法 | 路径 | 输入 | 预期结果 |
|---|---------|------|------|------|---------|
| 38 | test_image_upload_success | POST | `/api/v1/image/upload` | 合法图片文件 (jpg, <10MB) | HTTP 200, 返回 `image_id`, `image_path` |
| 39 | test_image_upload_too_large | POST | `/api/v1/image/upload` | 超过 10MB 的文件 | HTTP 422, 文件过大 |
| 40 | test_image_upload_invalid_type | POST | `/api/v1/image/upload` | 非图片文件（如 .txt） | HTTP 422, 类型不支持 |
| 41 | test_image_get_success | GET | `/api/v1/image/{id}` | 已上传的图片 ID | HTTP 200, 返回图片二进制流 |
| 42 | test_image_get_not_found | GET | `/api/v1/image/{id}` | 不存在的图片 ID | HTTP 200, `code: 1002` |
| 43 | test_image_upload_with_disease_record | POST | `/api/v1/image/upload` | `disease_record_id` 参数 | HTTP 200, 图片路径写入对应 disease_records |

**G. 健康检查 — `test_health_api.py`**

| # | 测试名称 | 方法 | 路径 | 输入 | 预期结果 |
|---|---------|------|------|------|---------|
| 44 | test_health_success | GET | `/api/v1/health` | 无 | HTTP 200, `status: "healthy"`, `db_connected: true` |
| 45 | test_health_db_disconnected | GET | `/api/v1/health` | 数据库不可用 | HTTP 503, `status: "degraded"`, `db_connected: false` |

**H. 认证与安全 — `test_auth.py`**

| # | 测试名称 | 方法 | 路径 | 输入 | 预期结果 |
|---|---------|------|------|------|---------|
| 46 | test_api_key_auth_success | GET | `/api/v1/sensor/latest` | 携带有效 `X-API-Key` | HTTP 200 |
| 47 | test_api_key_auth_missing | GET | `/api/v1/sensor/latest` | 无 `X-API-Key` 头 | HTTP 200（开发模式）或 401（生产模式） |
| 48 | test_api_key_auth_invalid | GET | `/api/v1/sensor/latest` | 携带无效 `X-API-Key` | HTTP 200（开发模式）或 401（生产模式） |

### 4.3 数据库集成测试

| # | 测试名称 | 测试内容 | 步骤 | 预期结果 |
|---|---------|---------|------|---------|
| 49 | test_ddl_schema_creation | DDL 建表验证 | 在空数据库中运行 001_create_tables.sql | 5 张表全部创建成功, 索引均存在 |
| 50 | test_sensor_snapshot_insert | 传感器数据写入 | INSERT 一条完整传感器记录 | 写入成功, 可 SELECT 返回 |
| 51 | test_sensor_snapshot_unique_constraint | 唯一约束验证 | 插入两条 `(device_id, timestamp)` 相同的数据 | 第二条命中 UNIQUE 约束, 行数不变 |
| 52 | test_sensor_snapshot_idempotent_insert | 幂等写入 | 使用 `INSERT ON CONFLICT DO NOTHING` | 不报错, 行数保持为 1 |
| 53 | test_disease_records_crud | 病虫害 CRUD | INSERT → SELECT → UPDATE → SELECT | 各步骤操作成功, 联动分析字段可写入 |
| 54 | test_control_logs_insert_with_command_id | 控制日志插入 | INSERT 含 command_id 的记录 | 写入成功, 部分索引生效 |
| 55 | test_control_logs_null_command_id | 控制日志 NULL | INSERT command_id 为 NULL 的记录 | 写入成功, 部分索引不阻止 |
| 56 | test_devices_upsert | 设备 upsert | 首次 INSERT → 重复 INSERT ON CONFLICT DO NOTHING | 首次成功, 重复不报错 |
| 57 | test_sensor_daily_aggregation | 日聚合 | 插入多条传感器数据后执行聚合 SQL | 聚合表记录正确, 统计值准确 |
| 58 | test_data_retention_sensor | 传感器数据清理 | 插入过期数据后执行删除 | 过期数据被删除, 未过期数据保留 |
| 59 | test_data_retention_control | 控制日志清理 | 插入过期数据后执行删除 | 过期数据被删除, 90 天内数据保留 |
| 60 | test_seed_data | 种子数据验证 | 运行 002_seed_data.sql | devices 表有初始设备, sensor_snapshot 有示例数据 |

### 4.4 Docker 容器测试

| # | 测试名称 | 测试内容 | 步骤 | 预期结果 |
|---|---------|---------|------|---------|
| 61 | test_container_startup | 容器启动 | `docker compose up -d` | API 和 DB 容器正常启动, 状态为 Up |
| 62 | test_container_healthcheck_api | API 健康检查 | 等待 healthcheck 完成 | API 容器 health status 为 healthy |
| 63 | test_container_healthcheck_db | DB 健康检查 | 等待 healthcheck 完成 | DB 容器 health status 为 healthy |
| 64 | test_api_db_connectivity | API-DB 连通性 | 调用 `/api/v1/health` | `db_connected: true` |
| 65 | test_container_network_communication | 容器间通信 | 从 API 容器 ping 或 curl db:5432 | 通信正常, 端口可达 |
| 66 | test_container_resource_limits | 资源限制验证 | `docker inspect` 查看容器 | 内存限制正确应用（api: 256M, db: 384M） |
| 67 | test_container_log_output | 日志输出 | 查看容器日志 | API 日志包含启动信息, 无关键错误 |
| 68 | test_container_restart | 容器重启 | `docker compose restart api` | 重启后 API 恢复正常, 数据不丢失 |
| 69 | test_image_build | 镜像构建 | `docker build -t farmeye-api:test .` | 构建成功, 镜像大小合理 |
| 70 | test_container_shutdown | 容器停止 | `docker compose down` | 容器正常停止, Volume 数据保留 |

### 4.5 端到端测试

#### 4.5.1 全链路测试（模拟 IoTDA Webhook → API → DB）

| # | 测试名称 | 模拟步骤 | 验证点 | 预期结果 |
|---|---------|---------|--------|---------|
| 71 | test_e2e_sensor_full_flow | ① 发送传感器 Webhook → API → ② 查询最新数据 | ① HTTP 200, ② 返回数据与①发送数据一致 | 数据完整经过"Webhook 接收 → DB 持久化 → API 查询"全链路 |
| 72 | test_e2e_ai_full_flow | ① 发送 AI 识别 Webhook → ② 查询病虫害记录 → ③ 查询防治建议 | ① HTTP 200, ② 记录存在, ③ 建议含联动分析 | 识别 → 分析 → 建议全链路通畅 |
| 73 | test_e2e_command_full_flow | ① 发送控制命令 → ② 查询控制日志 | ① HTTP 200, 含 command_id, ② 日志中存在该命令 | 命令下发 → 日志记录全链路 |
| 74 | test_e2e_severe_disease_auto_action | ① 发送 severity_code=3 的 AI 识别 → ② 查询 control_logs | ① HTTP 200, ② control_logs 中存在自动 `spray ON` 记录 | 重度检测 → 自动决策 → 命令记录全链路 |
| 75 | test_e2e_image_upload_and_retrieve | ① 上传图片 → ② 获取图片 | ① HTTP 200, ② 返回图片二进制 | 上传 → 存储 → 获取全链路 |
| 76 | test_e2e_multi_sensor_burst | ① 批量发送 100 条传感器 Webhook → ② 分页查询历史 | ① 全部 200, ② 总数 100, 分页正确 | 批量写入 → 分页查询正确 |

#### 4.5.2 端到端测试脚本结构

`server/tests/test_e2e.py`：

```python
"""
端到端集成测试。

这些测试需要完整的 Docker 环境（API + DB），使用 httpx 通过 HTTP 调用真实服务。
标记为 `@pytest.mark.e2e`，默认被跳过，需通过 `--run-e2e` 参数执行。
"""
import pytest
import httpx


def pytest_addoption(parser):
    parser.addoption(
        "--run-e2e", action="store_true", default=False, help="Run end-to-end tests"
    )


def pytest_configure(config):
    config.addinivalue_line("markers", "e2e: mark test as end-to-end")


def pytest_collection_modifyitems(config, items):
    if config.getoption("--run-e2e"):
        return
    skip_e2e = pytest.mark.skip(reason="need --run-e2e option to run")
    for item in items:
        if "e2e" in item.keywords:
            item.add_marker(skip_e2e)


@pytest.mark.e2e
class TestSensorE2E:
    """传感器数据端到端测试。"""

    BASE_URL = "http://localhost:8000/api/v1"

    @pytest.fixture
    def client(self):
        return httpx.Client(base_url=self.BASE_URL, timeout=30.0)

    def test_sensor_full_flow(self, client):
        # 步骤 1: 模拟 IoTDA 发送传感器数据
        payload = {
            "resource": "device.property",
            "event": "report",
            "event_time": "2026-07-01T00:00:00Z",
            "notify_data": {
                "header": {"device_id": "farmeye_guard_ws63"},
                "body": {
                    "services": [{
                        "service_id": "farmeye_env",
                        "properties": {
                            "temperature": 26.5,
                            "humidity": 58.0,
                            "light": 80,
                            "co2": 420,
                            "soil_n": 50.3,
                            "soil_p": 23.8,
                            "soil_k": 51.6,
                            "distance": 145,
                            "rssi": -50,
                            "ip_addr": "192.168.1.100",
                            "mac_addr": "A1:B2:C3:D4:E5:F6",
                            "alarm_flag": 0,
                        },
                    }]
                },
            },
        }
        resp = client.post("/iotda/properties/report", json=payload)
        assert resp.status_code == 200
        assert resp.json()["code"] == 0

        # 步骤 2: 查询最新传感器数据
        resp = client.get("/sensor/latest", params={"device_id": "farmeye_guard_ws63"})
        assert resp.status_code == 200
        data = resp.json()
        assert data["code"] == 0
        records = data["data"]["records"]
        assert len(records) >= 1
        assert records[0]["temperature"] == 26.5
        assert records[0]["humidity"] == 58.0
```

### 4.6 性能与压力测试方案

#### 4.6.1 测试目标

针对 1 vCPU / 1GB RAM 的 VPS 资源约束，性能测试的核心目标是：

1. **确认系统在资源限制下的稳定运行能力**
2. **找出资源瓶颈**
3. **建立性能基线**

#### 4.6.2 测试场景

| # | 场景名称 | 模拟行为 | 并发数 | 持续时间 | 指标目标 |
|---|---------|---------|--------|---------|---------|
| P1 | IoTDA Webhook 吞吐量 | 模拟 IoTDA 批量推送传感器数据到 `/api/v1/iotda/properties/report` | 5-10 并发 | 5 min | 平均响应时间 < 1s, 错误率 < 1% |
| P2 | API 查询负载 | 模拟多个客户端轮询 `/api/v1/sensor/latest` | 10-20 并发 | 5 min | 平均响应时间 < 500ms, P99 < 2s |
| P3 | 历史数据分页查询 | 模拟查询 `/api/v1/sensor/history` 大量数据分页 | 5 并发 | 3 min | 平均响应时间 < 3s |
| P4 | 混合负载 | 80% 查询 + 20% Webhook 写入 | 10 并发 | 10 min | 错误率 < 1%, 无 OOM |
| P5 | 长时间运行 | 混合负载持续运行 | 5 并发 | 60 min | 无内存泄漏, 内存稳定 |
| P6 | 图片上传 | 模拟上传 500KB-2MB 图片 | 2-5 并发 | 3 min | 平均响应时间 < 5s |
| P7 | 并发命令下发 | 模拟同时发送控制命令 | 3 并发 | 2 min | 平均响应时间 < 3s |

#### 4.6.3 性能测试工具

| 工具 | 用途 | 安装 | 备注 |
|------|------|------|------|
| locust | 分布式负载测试 | `pip install locust` | Python 原生, 可编写复杂测试场景 |
| Apache Bench (ab) | 快速吞吐量测试 | `sudo apt install apache2-utils` | 简单 GET/POST 压测 |
| docker stats | 容器资源监控 | Docker 内置 | 实时 CPU/内存使用 |

#### 4.6.4 Locust 测试脚本

**`server/tests/locustfile.py`**：

```python
from locust import HttpUser, task, between
import json
import random
from datetime import datetime


class FarmEyeLoadTest(HttpUser):
    """FarmEye API 负载测试。"""

    wait_time = between(0.5, 2.0)

    def on_start(self):
        """测试开始前的初始化。"""
        self.headers = {"Content-Type": "application/json", "X-API-Key": "test_key"}
        self.device_id = "farmeye_guard_ws63"

    @task(3)
    def sensor_latest(self):
        """高频轮询：获取最新传感器数据。"""
        self.client.get(
            f"/api/v1/sensor/latest?device_id={self.device_id}",
            headers=self.headers,
            name="/sensor/latest",
        )

    @task(1)
    def sensor_history(self):
        """中频查询：历史传感器数据。"""
        self.client.get(
            f"/api/v1/sensor/history?device_id={self.device_id}&page_size=20",
            headers=self.headers,
            name="/sensor/history",
        )

    @task(2)
    def disease_records(self):
        """中频查询：病虫害记录。"""
        self.client.get(
            f"/api/v1/disease/records?device_id={self.device_id}&page_size=10",
            headers=self.headers,
            name="/disease/records",
        )

    @task(2)
    def advisory(self):
        """中频查询：防治建议。"""
        self.client.get(
            f"/api/v1/advisory?device_id={self.device_id}",
            headers=self.headers,
            name="/advisory",
        )

    @task(1)
    def device_list(self):
        """低频查询：设备列表。"""
        self.client.get("/api/v1/device/list", headers=self.headers, name="/device/list")

    @task(1)
    def health_check(self):
        """高频检查：健康检查。"""
        self.client.get("/api/v1/health", name="/health")

    @task(1)
    def simulate_webhook(self):
        """模拟 IoTDA 传感器 Webhook 推送。"""
        payload = {
            "resource": "device.property",
            "event": "report",
            "event_time": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "notify_data": {
                "header": {"device_id": self.device_id},
                "body": {
                    "services": [{
                        "service_id": "farmeye_env",
                        "properties": {
                            "temperature": round(25.0 + random.uniform(-3, 3), 1),
                            "humidity": round(55.0 + random.uniform(-10, 10), 1),
                            "light": random.randint(50, 100),
                            "co2": random.randint(350, 600),
                            "soil_n": round(45.0 + random.uniform(-5, 5), 1),
                            "soil_p": round(20.0 + random.uniform(-3, 3), 1),
                            "soil_k": round(50.0 + random.uniform(-3, 3), 1),
                            "distance": random.randint(50, 200),
                            "rssi": random.randint(-70, -30),
                            "ip_addr": "192.168.1.100",
                            "mac_addr": "A1:B2:C3:D4:E5:F6",
                            "alarm_flag": 0,
                        },
                    }]
                },
            },
        }
        self.client.post(
            "/api/v1/iotda/properties/report",
            json=payload,
            headers=self.headers,
            name="/iotda/properties/report",
        )
```

#### 4.6.5 执行与报告

```bash
# 1. Web 界面模式（推荐）
locust -f server/tests/locustfile.py --host=http://localhost:8000 --web-port=8089

# 2. 无头模式（CI）
locust -f server/tests/locustfile.py --host=http://localhost:8000 \
    --headless -u 10 -r 2 --run-time 5m \
    --csv=reports/performance/locust_report

# 3. Apache Bench 快速测试
ab -n 1000 -c 10 http://localhost:8000/api/v1/health

# 4. 查看容器资源使用
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

#### 4.6.6 性能基线预期

| 指标 | 目标值 | 说明 |
|------|-------|------|
| API /health 响应时间 | < 100ms (P50), < 500ms (P99) | 无需数据库查询 |
| API /sensor/latest 响应时间 | < 200ms (P50), < 1s (P99) | 含数据库查询 |
| API Webhook 写入响应时间 | < 500ms (P50), < 2s (P99) | 含数据库写入 |
| API 吞吐量（混合负载） | > 50 req/s | 10 并发下的吞吐 |
| DB 连接池 | < 10 活跃连接 | max_connections=20 足够 |
| API 容器内存 | < 200MB 稳定 | 无内存泄漏 |
| DB 容器内存 | < 350MB 稳定 | shared_buffers=128MB |
| API 错误率 | < 0.1% | 非 2xx 响应 |

#### 4.6.7 1GB RAM 优化建议

| 优化项 | 措施 | 预期效果 |
|-------|------|---------|
| API 单 worker | uvicorn workers=1 | 减少内存开销, 避免多 worker 竞争 |
| DB shared_buffers 调低 | 128MB (默认通常 256MB+) | 为 OS 和 API 留出空间 |
| DB max_connections 调低 | 20 (默认通常 100) | 减少连接内存开销 |
| 日志轮转 | Docker json-file max-size=10m, max-file=3 | 防止日志撑满磁盘 |
| 图片压缩 | 上传时后端压缩 JPEG 质量 85% | 减少磁盘占用 |
| 监控告警 | 设置 Docker 内存使用告警阈值 80% | 提前发现内存不足 |
| swap 配置 | VPS 默认有 1GB swap | 提供紧急时的内存溢出保护 |
| Nginx 可选 | 仅在需要时才启用 | 节省 ~64MB 内存 |

---

## 5. 开发工作流

### 5.1 本地开发 → Docker 测试 → VPS 部署 CI 流程

```
┌─────────────────┐     ┌─────────────────┐     ┌──────────────────┐
│  1. 本地开发      │     │  2. Docker 测试   │     │  3. VPS 部署      │
│                  │     │                  │     │                  │
│  - 编写代码       │────▶│  - 构建 Dev 镜像  │────▶│  - 构建 Prod 镜像 │
│  - 运行单元测试    │     │  - 运行集成测试    │     │  - 部署到 VPS     │
│  - 手动验证 API   │     │  - 端到端测试     │     │  - 验证健康状态   │
│  - 本地 Git 提交  │     │  - 性能基线检查   │     │  - 监控日志      │
└─────────────────┘     └─────────────────┘     └──────────────────┘
```

#### 5.1.1 阶段 1：本地开发

```bash
# 1. 激活虚拟环境
cd server
python -m venv .venv
source .venv/bin/activate  # Linux
# .venv\Scripts\Activate.ps1  # Windows

# 2. 安装依赖
pip install -r requirements-dev.txt

# 3. 配置环境变量（从模板复制）
cp .env.template .env
# 编辑 .env 中的配置

# 4. 初始化数据库（SQLite 开发模式）
# 应用启动时会自动建表（通过 SQLAlchemy Base.metadata.create_all）
# 或运行 Alembic 迁移

# 5. 启动开发服务器（热重载）
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 6. 验证
curl http://localhost:8000/api/v1/health

# 7. 运行测试
pytest tests/ -v --cov=app --cov-report=term-missing
```

#### 5.1.2 阶段 2：Docker 测试

```bash
# 1. 构建开发镜像
cd server
docker build --target dev -t farmeye-api:dev .

# 2. 启动完整环境
DOCKER_TARGET=dev docker compose up -d

# 3. 运行集成测试
pytest tests/test_db_integration.py -v

# 4. 运行端到端测试
pytest tests/ --run-e2e -v

# 5. 查看日志
docker compose logs -f api

# 6. 清理
docker compose down
```

#### 5.1.3 阶段 3：VPS 部署

```bash
# 1. 构建生产镜像
docker build --target prod -t farmeye-api:latest .

# 2. 推送到镜像仓库（可选）
docker tag farmeye-api:latest your-registry/farmeye-api:latest
docker push your-registry/farmeye-api:latest

# 3. SSH 到 VPS
ssh farmeye@<VPS_IP>

# 4. 拉取最新代码
cd /opt/farmeye
git pull origin main

# 5. 构建并启动
docker compose --compatibility up -d --build

# 6. 验证部署
curl -s http://localhost:8000/api/v1/health | jq .
curl -s http://localhost:80/api/v1/health | jq .   # 如有 Nginx

# 7. 检查日志
docker compose logs --tail=30 api
```

### 5.2 CI 流程（可选 / 推荐）

采用 GitHub Actions 或 GitLab CI 实现自动化：

```yaml
# .github/workflows/backend-ci.yml
name: Backend CI

on:
  push:
    branches: [main, develop]
    paths:
      - "server/**"
  pull_request:
    branches: [main]
    paths:
      - "server/**"

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: farmeye
          POSTGRES_PASSWORD: farmeye_pwd
          POSTGRES_DB: farmeye_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        working-directory: server
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements-dev.txt

      - name: Lint check
        working-directory: server
        run: ruff check app/ tests/

      - name: Run unit & integration tests
        working-directory: server
        run: |
          pytest tests/ -v --cov=app --cov-report=xml \
            --ignore=tests/test_e2e.py \
            --ignore=tests/test_docker_integration.py \
            --ignore=tests/test_performance.py
        env:
          DATABASE_URL: postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: server/coverage.xml

  docker-build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        working-directory: server
        run: docker build --target prod -t farmeye-api:${{ github.sha }} .

      - name: Run Docker compose smoke test
        working-directory: server
        run: |
          DOCKER_TARGET=dev docker compose up -d
          sleep 15
          curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"'
          docker compose down
```

### 5.3 热重载开发配置

热重载通过以下机制实现：

1. **uvicorn --reload**：监控 Python 文件变化，自动重启服务
2. **Docker 源码挂载**：开发模式下将宿主源码目录挂载到容器

```yaml
# docker-compose.yml 开发覆写
services:
  api:
    build:
      target: dev
    volumes:
      - ./app:/app/app           # 源码挂载实现热重载
      - ./alembic:/app/alembic   # 迁移脚本挂载
      - ./alembic.ini:/app/alembic.ini
    environment:
      - APP_DEBUG=true
      - APP_ENV=development
      - LOG_LEVEL=DEBUG
```

启动方式：

```bash
# 方式 A：直接本地运行（最快）
cd server && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 方式 B：Docker 开发模式（环境一致性）
DOCKER_TARGET=dev docker compose up
```

### 5.4 环境变量管理

#### 5.4.1 分层策略

```
.gitignore 中排除 .env 文件，避免机密信息入版本库
.env 文件按环境分目录管理（推荐）

server/
├── .env.template           # 模板（入版本库）
├── env/                    # 环境变量目录（入版本库）
│   ├── dev.env.example     # 开发环境示例
│   └── prod.env.example    # 生产环境示例
└── .env                    # 实际环境变量（不入版本库, .gitignore 忽略）
```

#### 5.4.2 环境变量覆盖优先级

```
最低优先级: docker-compose.yml 中的 environment 默认值
     ↓
次低优先级: .env 文件
     ↓
次高优先级: shell 环境变量（export 设置）
     ↓
最高优先级: docker compose 命令行传递
```

#### 5.4.3 敏感信息管理

| 敏感信息 | 存储方式 | 说明 |
|---------|---------|------|
| DB 密码 | `.env` 文件 + VPS 环境变量 | VPS 上通过 `chmod 600 .env` 限制访问 |
| API Keys | `.env` 文件 | 定期轮换 |
| IoTDA Project ID | `.env` 文件 | 非敏感但建议保护 |

```bash
# VPS 上 .env 文件权限
sudo chown farmeye:farmeye /opt/farmeye/.env
sudo chmod 600 /opt/farmeye/.env
```

### 5.5 数据迁移策略

#### 5.5.1 使用 Alembic

基于架构文档 §5.1 定义的 `alembic` 目录结构：

```bash
server/
├── alembic.ini              # Alembic 配置
└── alembic/                 # 迁移脚本
    ├── env.py               # 运行环境配置
    ├── script.py.mako       # 迁移脚本模板
    └── versions/            # 版本历史
        ├── 0001_initial_schema.py
        └── ...
```

#### 5.5.2 初始化

```bash
cd server
alembic init alembic

# 配置 alembic.ini
# sqlalchemy.url = postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db

# 创建初始迁移（基于 SQLAlchemy 模型自动生成）
alembic revision --autogenerate -m "initial_schema"

# 应用迁移
alembic upgrade head

# 查看状态
alembic current
alembic history
```

#### 5.5.3 迁移工作流

```bash
# 1. 修改 SQLAlchemy 模型（如新增字段）
# 2. 生成迁移脚本
alembic revision --autogenerate -m "add_field_xxx"

# 3. 审查生成的迁移脚本（关键步骤！）
# 4. 应用迁移
alembic upgrade head

# 5. 回滚迁移
alembic downgrade -1
```

#### 5.5.4 部署时自动迁移

在生产环境中，API 容器启动时自动执行迁移：

```python
# app/main.py
import asyncio
from alembic.config import Config as AlembicConfig
from alembic import command


def run_migrations():
    """应用未完成的数据库迁移。"""
    if settings.app_env == "production":
        alembic_cfg = AlembicConfig("alembic.ini")
        command.upgrade(alembic_cfg, "head")


@app.on_event("startup")
async def startup_event():
    # 在异步事件循环中通过线程池执行同步 Alembic 迁移，避免阻塞事件循环
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, run_migrations)
    # ... 其他初始化
```

或通过启动脚本显式运行：

```bash
# start.sh
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

---

## 6. 附录：完整配置文件与脚本清单

### 6.1 文件清单

```
server/
├── Dockerfile                         # 多阶段构建（base/dev/prod）
├── docker-compose.yml                 # 主编排文件
├── .dockerignore
├── requirements.txt                   # 生产依赖
├── requirements-dev.txt               # 开发依赖
├── .env.template                      # 环境变量模板
├── .env                               # 实际环境变量（gitignore）
├── alembic.ini                        # 数据库迁移配置
├── alembic/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
│       └── 0001_initial_schema.py
├── init-scripts/
│   ├── 001_create_tables.sql          # DDL 建表
│   └── 002_seed_data.sql              # 种子数据
├── app/
│   ├── main.py
│   ├── config.py
│   ├── api/
│   │   ├── v1/
│   │   │   ├── iotda.py
│   │   │   ├── sensor.py
│   │   │   ├── disease.py
│   │   │   ├── device.py
│   │   │   ├── command.py
│   │   │   ├── advisory.py
│   │   │   └── image.py
│   ├── models/
│   │   ├── sensor.py
│   │   ├── disease.py
│   │   └── control.py
│   ├── schemas/
│   │   ├── sensor.py
│   │   ├── disease.py
│   │   ├── command.py
│   │   └── common.py
│   ├── services/
│   │   ├── sensor_service.py
│   │   ├── disease_service.py
│   │   ├── command_service.py
│   │   ├── advisory_service.py
│   │   ├── iotda_client.py
│   │   └── data_retention.py
│   ├── core/
│   │   └── logging_config.py
│   └── db/
│       ├── session.py
│       └── base.py
└── tests/
    ├── conftest.py
    ├── test_sensor_api.py
    ├── test_disease_api.py
    ├── test_command_api.py
    ├── test_advisory_api.py
    ├── test_image_api.py
    ├── test_iotda_webhook.py
    ├── test_health_api.py
    ├── test_models.py
    ├── test_db_integration.py
    ├── test_services/
    │   └── ...
    ├── test_docker_integration.py
    ├── test_e2e.py
    ├── test_performance.py
    └── fixtures/
        ├── sensor_payload.json
        ├── ai_payload.json
        └── cmd_response_payload.json
```

```
deploy/
├── docker-compose.prod.yml            # 生产环境覆写
├── nginx/
│   └── farmeye.conf                   # Nginx 反向代理配置
├── scripts/
│   ├── start.sh                       # 启动脚本
│   ├── stop.sh                        # 停止脚本
│   ├── restart.sh                     # 重启脚本
│   ├── backup_db.sh                   # 数据库备份脚本
│   └── restore_db.sh                  # 数据库恢复脚本
└── logrotate/
    └── farmeye                        # 日志轮转配置
```

### 6.2 VPS 快速部署命令模板

```bash
# ===== 快速部署 =====
# 以下命令在全新 Ubuntu 25.04 VPS 上执行

# 1. 系统初始化
sudo apt update && sudo apt upgrade -y
sudo hostnamectl set-hostname farmeye-vps
sudo timedatectl set-timezone Asia/Singapore

# 2. 安装 Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker   # 或重新登录

# 3. 配置防火墙
sudo ufw --force enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 4. 部署应用
sudo mkdir -p /opt/farmeye
sudo chown $USER:$USER /opt/farmeye
cd /opt/farmeye

# 5. 复制项目文件（scp 或 git clone）
# scp -r server/* user@vps:/opt/farmeye/
# cp -r deploy/* /opt/farmeye/

# 6. 创建 .env 配置文件（参见 3.2.2 节）

# 7. 创建日志和图片目录
mkdir -p logs/api logs/nginx logs/backup images

# 8. 构建并启动
docker compose up -d --build

# 9. 验证
curl -s http://localhost:8000/api/v1/health
echo "---"
docker compose ps
```

---

> 本方案设计依据 `docs/system_architecture.md` (FarmEye Guard v1.0) 中的架构定义，针对 Digital Ocean VPS (1 vCPU / 1GB RAM / Ubuntu 25.04 / 新加坡节点) 的资源约束进行适配。所有配置文件和脚本可直接在指定 VPS 上运行。

---

## 修订说明（v2）

| 审查意见 | 处理方式 |
|---------|---------|
| Docker APT 源使用 Ubuntu 24.04 "noble" 代号而非 25.04 "plucky" 代号，可能导致仓库元数据不匹配和安装失败 | 修改：将静态 `noble` 替换为动态 `$(lsb_release -cs)` 自动检测；同时增加说明文档：若 Docker 官方尚未发布 plucky 源，可回退到 noble 源并添加 `--allow-releaseinfo-change` 参数，注明风险 |
| 声称 "Python 3.12.x 与 Ubuntu 25.04 默认 Python 版本对齐" 不准确，Ubuntu 25.04 默认 Python 为 3.13 | 修改：更正为 "Python 3.13.x（Ubuntu 25.04 默认 Python 版本）"，并注明可额外安装 python3.12；同步更新 Dockerfile 改用系统默认 python3（3.13） |
| `.dockerignore` 中存在重复条目（`.venv/` 和 `.venv_old/` 各出现两次） | 修改：删除重复的 `.venv/` 和 `.venv_old/` 条目 |
| `conftest.py` 中 `os.remove("./data/test_farmeye.db")` 缺乏防御性处理，若 `create_all` 失败导致文件未创建将抛出 `FileNotFoundError` | 修改：增加 `try/except FileNotFoundError` 包裹 `os.remove`，确保清理阶段不会因文件不存在而引发异常 |
| 异步 startup handler 中执行同步 Alembic 调用会阻塞事件循环 | 修改：将 `run_migrations()` 改为通过 `loop.run_in_executor(None, run_migrations)` 在默认线程池中执行，避免阻塞异步事件循环 |
