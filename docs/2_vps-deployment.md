# VPS 后端开发与容器化详细设计和测试方案

> **文档版本**: v9（迭代 v3 修订）
> **修订依据**: 迭代 v3 要求（a_v3_iteration_requirement.md）
> **系统版本**: FarmEye Guard v1.0
> **目标 VPS**: Digital Ocean / Ubuntu 25.04 / 1 vCPU / 1 GB RAM / 35 GB Disk

---

## 目录

1. [Python API 后端 (FastAPI) 容器化](#1-python-api-后端-fastapi-容器化)
   - 1.1 本地开发环境配置
   - 1.2 依赖管理
   - 1.3 环境变量模板
   - 1.4 Dockerfile 设计
   - 1.4.1 .dockerignore 配置
   - 1.5 docker-compose.yml 设计
   - 1.6 生产/开发配置分离策略
   - 1.7 健康检查配置
2. [数据库 (PostgreSQL 16 / KingbaseES)](#2-数据库-postgresql-16--kingbasees)
   - 2.1 镜像适配方案
   - 2.2 数据库初始化脚本
   - 2.3 数据持久化与备份策略
   - 2.4 数据保留与清理策略
   - 2.5 KingbaseES V8 完整等效配置
3. [VPS 部署方案](#3-vps-部署方案)
   - 3.1 VPS 初始化配置
   - 3.2 Docker Compose 部署流程
   - 3.3 Nginx 反向代理配置
   - 3.3.1 server/nginx/farmeye.conf
   - 3.3.2 Nginx 启用/禁用
   - 3.3.3 SSL 证书管理（Certbot + Let's Encrypt）
   - 3.4 日志收集与管理方案
   - 3.5 容器资源限制配置
   - 3.6 启动与停止脚本
4. [测试方案](#4-测试方案)
   - 4.1 单元测试框架与组织
   - 4.2 API 接口测试
   - 4.3 数据库集成测试
   - 4.4 Docker 容器测试
   - 4.5 端到端测试
   - 4.6 性能与压力测试方案
5. [开发工作流](#5-开发工作流)
   - 5.1 本地开发 → Docker 测试 → VPS 部署流程
   - 5.2 热重载开发配置
   - 5.3 环境变量管理
   - 5.4 数据迁移策略
   - 5.4.1 Alembic 初始化
   - 5.4.2 server/alembic.ini
   - 5.4.3 迁移工作流
   - 5.4.4 迁移与 Docker 集成
   - 5.4.5 环境变量读取
   - 5.4.6 初始基准迁移
   - 5.4.7 首次运行边界处理
6. [附录](#6-附录)
   - 6.1 文件清单
   - 6.2 快速部署命令

---

## 1. Python API 后端 (FastAPI) 容器化

### 1.1 本地开发环境配置方案

#### 1.1.1 Python 版本与虚拟环境

项目使用 Python 3.13+（Ubuntu 25.04 默认搭载 Python 3.13），推荐使用 `venv` 管理虚拟环境：

```bash
# 创建虚拟环境
python3 -m venv .venv

# 激活虚拟环境
# Linux/macOS
source .venv/bin/activate
# Windows PowerShell
.venv\Scripts\Activate.ps1

# 升级 pip
pip install --upgrade pip

# 安装依赖
pip install -r server/requirements.txt
pip install -r server/requirements-dev.txt

> **注意**：`server/requirements.txt` 中的 `psycopg2~=2.9.0` 为源码编译版本，需要在宿主机安装 PostgreSQL C 库头文件和编译工具链：
> - Linux (Ubuntu/Debian)：`sudo apt-get install libpq-dev build-essential python3-dev`
> - **Windows/macOS 开发者**：如果无法安装编译依赖，可在本地开发环境临时使用 `pip install psycopg2-binary` 替代（仅限本地开发，不得用于生产镜像构建）
> - 生产环境使用 Docker 多阶段构建（参见 §1.4），编译依赖在 base 阶段预先安装，无需宿主机额外配置
```

#### 1.1.2 IDE 配置建议（VS Code）

在 `server/.vscode/settings.json` 中配置：

```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.testing.pytestArgs": ["tests"],
  "python.testing.unittestEnabled": false,
  "python.testing.pytestEnabled": true,
  "python.analysis.typeCheckingMode": "basic",
  "python.analysis.autoImportCompletions": true
}
```

### 1.2 依赖管理

#### 1.2.1 server/requirements.txt（生产依赖）

```
# FastAPI & ASGI
fastapi~=0.115.0
uvicorn[standard]~=0.30.0
pydantic~=2.9.0
pydantic-settings~=2.5.0

# Database
psycopg2~=2.9.0            # 从源码编译，生产环境推荐；非 psycopg2-binary
sqlalchemy~=2.0.0
alembic~=1.13.0

# HTTP Client（调用 IoTDA API）
httpx~=0.27.0

# Image processing（上传图片处理）
Pillow~=10.4.0
python-multipart~=0.0.12

# Data export（excel 导出）
openpyxl~=3.1.0

# Scheduling（数据保留定时任务）
apscheduler~=3.10.0
```

> **版本约束说明**：以上使用 pip 兼容发布说明符 `~=`（如 `~=0.115.0` 等价于 `>=0.115.0, ==0.115.*`），会安装指定主版本内的最新补丁版本。实际使用时可根据发布情况调整版本号。`pip install` 时请确保已升级 pip 至最新版本。

#### 1.2.2 server/requirements-dev.txt（开发依赖）

```
# Testing
pytest~=8.3.0
pytest-asyncio~=0.24.0
httpx~=0.27.0          # TestClient 使用

# Code quality
ruff~=0.6.0
mypy~=1.11.0

# Hot reload
watchfiles~=0.24.0
```

> **版本约束说明**：同上，使用 `~=` 兼容发布说明符。`requirements.txt` 与 `requirements-dev.txt` 中的 httpx 版本应保持一致。

### 1.3 环境变量模板

#### 1.3.1 server/.env.dev（开发环境模板）

```ini
# --- Database ---
DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db
DB_USER=farmeye
DB_NAME=farmeye_db

# --- Huawei IoTDA ---
IOTDA_ENDPOINT=https://iotda.cn-north-4.myhuaweicloud.com
IOTDA_PROJECT_ID=your_project_id_here

# --- Advisory Engine ---
ADVISORY_WINDOW_MINUTES=60

# --- Data Retention ---
DATA_RETENTION_SENSOR_DAYS=30
DATA_RETENTION_CONTROL_DAYS=90

# --- Image Storage ---
IMAGE_STORAGE_PATH=./images

# --- API Keys ---
API_KEYS=farmeye_dev_key_001

# --- Logging ---
LOG_LEVEL=DEBUG
```

#### 1.3.2 server/.env.prod（生产环境模板）

```ini
# --- Database ---
DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@db:5432/farmeye_db
DB_USER=farmeye
DB_NAME=farmeye_db

# --- Huawei IoTDA ---
IOTDA_ENDPOINT=https://iotda.cn-north-4.myhuaweicloud.com
IOTDA_PROJECT_ID=your_actual_project_id

# --- Advisory Engine ---
ADVISORY_WINDOW_MINUTES=60

# --- Data Retention ---
DATA_RETENTION_SENSOR_DAYS=30
DATA_RETENTION_CONTROL_DAYS=90

# --- Image Storage ---
IMAGE_STORAGE_PATH=/app/images

# --- API Keys ---
API_KEYS=farmeye_prod_key_001,farmeye_prod_key_002

# --- Logging ---
LOG_LEVEL=INFO

# --- Server（预留字段，当前由 Dockerfile CMD 硬编码）---
# HOST=0.0.0.0
# PORT=8000
# WORKERS=1
```

> **生产安全警示**：`.env.prod` 文件**绝不提交到 Git 仓库**，仅通过 VPS 管理员手动部署到 `/opt/farmeye/.env.prod`。提交到 Git 的仅为 `.env.dev.example` 和 `.env.prod.example` 示例模板（**不带真实密钥值**）。

### 1.4 Dockerfile 设计

基于 Ubuntu 25.04 官方镜像的多阶段构建，与 VPS 操作系统保持一致，降低运行时兼容性风险。

```dockerfile
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
# 注：psycopg2 从源码编译，base 镜像增加约 150-200 MB（含编译依赖工具链）

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
# 1 vCPU 场景下使用 1 worker + 2 线程
ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--limit-max-requests", "10000"]
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s \
    CMD curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"' || exit 1
```

> **安全说明**：构建镜像前务必确认 `.env.prod` 等敏感文件不在构建上下文中。项目中已配置 `.dockerignore`（参见下文），在 `docker build` 时会自动排除敏感文件。生产构建前建议运行 `docker build --check .`（Docker BuildKit 内置检查）验证构建上下文中无意外包含的文件。

> **多阶段构建说明**：
> - `base` 阶段：安装 Python 3.13（Ubuntu 25.04 默认版本）、创建虚拟环境、安装生产依赖。此阶段为 prod 和 dev 的共享基础。
> - `dev` 阶段：在 base 基础上添加调试工具、开发依赖，启用 `--reload` 热重载模式。
> - `prod` 阶段：在 base 基础上仅复制应用代码和 entrypoint 启动脚本，不包含任何开发工具和编译工具链，镜像体积最小化。容器启动时通过 entrypoint.sh 自动执行数据库迁移。

#### 1.4.1 .dockerignore 配置

在 `server/` 目录下创建 `.dockerignore` 文件，排除构建上下文中不必要的文件和敏感信息，确保镜像体积最小化且无凭据泄露风险：

```
# 环境变量文件（含敏感信息）
.env*
!.env.*.example

# Python 缓存与虚拟环境
__pycache__/
*.py[cod]
.venv/

# Git
.git/
.gitignore

# 文档
README.md

# 日志与备份
logs/
backups/
```

> **安全说明**：`.dockerignore` 文件应在仓库中管理并提交至 Git，确保所有开发者和 CI 环境使用一致的排除规则。生产构建前可运行 `docker build --check .` 验证构建上下文。

### 1.5 docker-compose.yml 设计

#### 1.5.1 server/docker-compose.yml（主编排文件）

```yaml
version: "3.9"

services:
  api:
    build:
      context: .
      target: prod
    container_name: farmeye-api
    ports:
      - "127.0.0.1:8000:8000"  # 监听 localhost 仅，由 Nginx 通过 Docker 内部网络转发
    env_file:
      - .env.prod
    volumes:
      - images_data:/app/images
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:8000/api/v1/health | grep -q '\"status\":\"healthy\"' || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    profiles:
      - production
    networks:
      - farmeye-net
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

  db:
    image: postgres:16-alpine
    container_name: farmeye-db
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_USER: farmeye
      POSTGRES_PASSWORD: farmeye_pwd
      POSTGRES_DB: farmeye_db
    volumes:
      - db_data:/var/lib/postgresql/data
      - ./init/:/docker-entrypoint-initdb.d/
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U farmeye -d farmeye_db || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 60s
    restart: unless-stopped
    networks:
      - farmeye-net
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M
    # 1GB RAM 优化：限制 PostgreSQL 共享内存
    command: >
      -c shared_buffers=64MB
      -c effective_cache_size=256MB
      -c work_mem=4MB
      -c maintenance_work_mem=16MB
      -c max_connections=10

  # 开发模式覆盖服务（通过 profile 与主 api 服务二选一：api 使用 production profile，api-dev 使用 dev profile）
  api-dev:
    build:
      context: .
      target: dev
    container_name: farmeye-api-dev
    ports:
      - "8000:8000"
    env_file:
      - .env.dev
    volumes:
      - ./app:/app/app
      - images_data:/app/images
      - ./logs:/app/logs
      - ./tests:/app/tests
    healthcheck:
      disable: true  # dev 模式禁用 healthcheck，避免 reload 中断探测
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - farmeye-net
    profiles:
      - dev  # 仅通过 `--profile dev` 启动
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

networks:
  farmeye-net:
    driver: bridge

volumes:
  db_data:
  images_data:
```

#### 1.5.2 server/docker-compose.prod.yml（生产环境覆写文件）

```yaml
version: "3.9"

services:
  api:
    # 生产环境覆写：restart 策略、日志驱动、资源限制加严
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    environment:
      - LOG_LEVEL=INFO
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

  db:
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    deploy:
      resources:
        limits:
          memory: 384M
        reservations:
          memory: 256M

  # 生产环境可选：Nginx 反向代理
  nginx:
    image: nginx:1.27-alpine
    container_name: farmeye-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/farmeye.conf:/etc/nginx/conf.d/farmeye.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro     # SSL 证书挂载
      - images_data:/usr/share/nginx/images:ro
    depends_on:
      api:
        condition: service_healthy
    restart: always
    networks:
      - farmeye-net
    deploy:
      resources:
        limits:
          memory: 64M
        reservations:
          memory: 32M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

> **覆写文件设计说明**：生产环境专用的配置（Nginx 服务、更严格的 restart 策略、日志驱动）放在 `docker-compose.prod.yml` 中作为覆写层。部署时通过 `-f` 参数合并主文件与覆写文件。开发环境不加载此文件，保持轻量。

### 1.6 生产/开发配置分离策略

| 配置维度 | 开发环境 | 生产环境 |
|---------|---------|---------|
| Docker target | `target: dev` | `target: prod` |
| 启动命令 | `--reload` 热重载 | 固定 workers=1 |
| 环境变量 | `.env.dev` | `.env.prod` |
| API Key | 开发密钥 | 生产密钥（多密钥轮换） |
| 数据库地址 | `localhost:5432`（宿主机直连） | `db:5432`（Docker 内网） |
| 日志级别 | DEBUG | INFO |
| 镜像构建 | 含 dev 工具链 | 最小化生产镜像 |
| Healthcheck | 禁用（避免 reload 中断） | 启用（30s 间隔） |
| Nginx | 不启用 | 可选启用（通过 prod 覆写） |

### 1.7 健康检查配置

健康检查端点在架构文档 §4.10.1 中定义，对应 `GET /api/v1/health`。

**Docker Healthcheck 配置要点**：

1. **API 服务**（Dockerfile 中定义）：
   - 开发模式：`interval=15s, timeout=5s, retries=3, start_period=10s`
   - 生产模式：`interval=30s, timeout=10s, retries=3, start_period=30s`
   - 检查命令：`curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"' || exit 1`

2. **数据库服务**（docker-compose.yml 中定义）：
   - `interval=10s, timeout=5s, retries=5, start_period=60s`
   - 检查命令：`pg_isready -U farmeye -d farmeye_db || exit 1`

3. **API → DB 依赖顺序**：
   - `depends_on.db.condition: service_healthy` 确保 API 仅在数据库健康后才启动
   - 避免 API 启动时因数据库未就绪而崩溃重试

---

## 2. 数据库 (PostgreSQL 16 / KingbaseES)

### 2.1 镜像适配方案

#### 2.1.1 镜像选择

KingbaseES V8 兼容 PostgreSQL 协议，因此可使用标准 PostgreSQL 镜像开发与部署，并在需要时切换至 KingbaseES。可选方案如下：

| 方案 | 描述 | 优点 | 缺点 | 推荐 |
|------|------|------|------|:----:|
| **B** | 使用 PostgreSQL 16 Alpine 镜像 | 镜像小（~200MB），社区活跃，Docker Hub 公开可用，无需商业授权 | 非国产数据库 | **推荐** |
| **A** | 使用 KingbaseES V8 官方 Docker 镜像 | 纯国产数据库，语法 100% 兼容 | 镜像大（~1.5GB），需要商业授权，内存占用较高 | 可选 |
| **C** | 宿主机直接安装 KingbaseES | 无容器化开销 | 污染宿主机环境，与容器网络隔离方案冲突 | 不推荐 |

**选用方案 B（PostgreSQL 16 Alpine）**，理由：
- PostgreSQL 16 Alpine 镜像可在 Docker Hub 直接 `docker pull postgres:16-alpine`，部署无附加条件
- Digital Ocean VPS 无需商业授权即可使用
- 与 SQLAlchemy / Alembic / psycopg2 完全兼容，开发体验一致
- 1GB RAM 下通过参数调优可获得良好的资源效率
- 如需后续切换至 KingbaseES V8，仅需修改 docker-compose.yml 中的 image、healthcheck 命令和 DATABASE_URL 连接串即可

> **方案 A（KingbaseES）说明**：`kingbase/kb_v8:V008R006C008B0020` 是人大金仓的商业数据库产品 Docker 镜像，**需要商业授权**并通过特定渠道获取，并非 Docker Hub 上的公共镜像。如需使用 KingbaseES：
> 1. 向人大金仓（https://www.kingbase.com.cn）申请商业授权或试用许可
> 2. 从授权渠道获取镜像 tar 文件后，通过 `docker load -i kingbase.tar` 导入至 VPS
> 3. 或配置内网私有 registry 进行镜像分发
> 4. 在 docker-compose.yml 中将 image 更换为 `kingbase/kb_v8:V008R006C008B0020`，将 healthcheck 改为 `ksql -U ${DB_USER} -d ${DB_NAME} -c 'SELECT 1'`，volume 路径改为 `/var/lib/kingbase/data`，并更新 DATABASE_URL 连接串
> 本文档下文以 PostgreSQL 16 为主线提供完整配置；KingbaseES 用户可参照差异说明自行调整。

#### 2.1.2 1GB RAM 环境下的 PostgreSQL 16 配置调优

针对 VPS 1GB RAM 约束，PostgreSQL 16 关键参数调整如下：

```ini
# postgresql.conf 覆盖参数（通过 docker-compose command 传入）
shared_buffers = 64MB             # 1GB 环境下从默认 128MB 降至 64MB
effective_cache_size = 256MB      # 操作系统缓存预估
work_mem = 4MB                    # 每排序操作内存，降低以支持并发
maintenance_work_mem = 16MB       # 维护操作（VACUUM、CREATE INDEX）
max_connections = 10              # 单 API 实例足够
checkpoint_timeout = 15min        # 减少写盘频率
checkpoint_completion_target = 0.9
wal_buffers = 1MB                 # WAL 缓冲区缩小
random_page_cost = 1.1            # SSD 优化
```

**内存分配计算**（1GB RAM 总量）：

| 组件 | 分配内存 | 说明 |
|------|---------|------|
| PostgreSQL 16 | 384MB | shared_buffers 64MB + 进程 + WAL + 缓存，生产环境预留余量应对连接高峰 |
| Python API | 256MB | Uvicorn worker + 应用代码 + 请求处理 |
| Nginx（可选） | 64MB | 反向代理，最小化占用 |
| OS + 缓存 | 296MB | Ubuntu 25.04 内核 + 文件系统缓存（含 Docker 守护进程约 50-100 MB） |
| **总计** | **~1000MB** | 留有约 24MB 余量 |

> **说明**：主 `docker-compose.yml`（§1.5.1）中 DB 内存限制设为 256M（开发环境默认值），生产覆写文件 `docker-compose.prod.yml`（§1.5.2）将其提升至 384M 以应对生产负载。上表为生产环境分配计划，§3.5 资源限制表与之对齐。

### 2.2 数据库初始化脚本

#### 2.2.1 server/init/01_create_tables.sql

```sql
-- ============================================================
-- FarmEye Guard v1.0 — 数据库初始化 DDL
-- 目标数据库：PostgreSQL 16（兼容 KingbaseES V8）
-- ============================================================

-- 表 1：环境数据快照
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


-- 表 2：病虫害识别记录
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


-- 表 3：设备控制日志
CREATE TABLE IF NOT EXISTS control_logs (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    command_id      VARCHAR(64),               -- IoTDA 命令 ID
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    command         VARCHAR(64) NOT NULL,
    source          VARCHAR(32) NOT NULL,       -- 'auto' / 'manual_app' / 'manual_pc'
    operator        VARCHAR(64),
    result_code     INT,
    result_msg      VARCHAR(255),

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_control_command_id
    ON control_logs (command_id) WHERE command_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_control_device_time
    ON control_logs (device_id, timestamp);


-- 表 4：设备注册信息
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


-- 表 5：环境数据日聚合
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

    record_count    INT,

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (device_id, agg_date)
);

CREATE INDEX IF NOT EXISTS idx_agg_device_date
    ON sensor_daily_aggregation (device_id, agg_date);
```

#### 2.2.2 server/init/02_seed_data.sql

```sql
-- ============================================================
-- 种子数据：初始设备注册
-- ============================================================

INSERT INTO devices (device_id, device_name, mac_addr, online)
VALUES ('farmeye_guard_ws63', 'FarmEye Guard WS63 #1', 'A1:B2:C3:D4:E5:F6', FALSE)
ON CONFLICT (device_id) DO NOTHING;
```

### 2.3 数据持久化与备份策略

#### 2.3.1 Docker Volume 持久化

```yaml
# docker-compose.yml 中的 volume 定义
volumes:
  db_data:          # PostgreSQL 16 数据文件，位于 /var/lib/docker/volumes/
  images_data:      # 上传的病虫害图片
```

#### 2.3.2 备份策略

鉴于 35GB 磁盘约束和课程项目规模，采用轻量级备份方案：

| 备份类型 | 频率 | 内容 | 保留周期 | 存储位置 |
|---------|------|------|---------|---------|
| 数据库全量备份 | 每日凌晨 3:00 | `pg_dump` 全库 SQL | 7 天 | `./backups/db/` |
| 数据库逻辑备份 | 每周日凌晨 4:00 | `pg_dump --format=custom` | 30 天 | `./backups/db/weekly/` |
| 图片文件备份 | 每周一次 | `tar -czf` | 30 天 | `./backups/images/` |

备份脚本 `deploy/scripts/backup.sh`：

```bash
#!/bin/bash
# FarmEye Guard — 数据库备份脚本
# 用法: ./backup.sh                    # 每日增量
#       ./backup.sh --full             # 全量（每周）

BACKUP_DIR="/opt/farmeye/backups/db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_CONTAINER="farmeye-db"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

# 检查数据库容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "[ERROR] 数据库容器 ${DB_CONTAINER} 未运行，备份中止"
    exit 1
fi

if [ "$1" = "--full" ]; then
    docker exec "$DB_CONTAINER" pg_dump \
        --format=custom \
        --file="/tmp/farmeye_full_${TIMESTAMP}.dump" \
        -U farmeye farmeye_db
    docker cp "${DB_CONTAINER}:/tmp/farmeye_full_${TIMESTAMP}.dump" \
        "${BACKUP_DIR}/weekly/"
    RETENTION_DAYS=30
else
    docker exec "$DB_CONTAINER" pg_dump \
        --format=plain \
        --no-owner \
        --file="/tmp/farmeye_daily_${TIMESTAMP}.sql" \
        -U farmeye farmeye_db
    docker cp "${DB_CONTAINER}:/tmp/farmeye_daily_${TIMESTAMP}.sql" \
        "${BACKUP_DIR}/"
fi

# 清理过期备份
find "$BACKUP_DIR" -name "farmeye_daily_*.sql" -mtime +${RETENTION_DAYS} -delete
find "$BACKUP_DIR/weekly" -name "farmeye_full_*.dump" -mtime +30 -delete

echo "[$(date)] Backup completed: farmeye_${TIMESTAMP}" >> /opt/farmeye/backups/backup.log
```

### 2.4 数据保留与清理策略

定时任务（APScheduler，在 Python API 进程中运行）每日凌晨执行：

```python
# server/app/services/data_retention.py
"""
数据保留策略定时任务

执行时间：每日凌晨 2:30（北京时间 UTC+8 → UTC 18:30）
"""
from datetime import datetime, timedelta, timezone
from sqlalchemy import text
from app.db.session import SessionLocal
import logging

logger = logging.getLogger(__name__)

def cleanup_expired_data():
    """
    清理过期数据：
    1. sensor_snapshot：保留最近 30 天明细，30 天前数据先聚合至
       sensor_daily_aggregation，再删除原始明细
    2. control_logs：保留最近 90 天

    设计决策：此函数定义为普通同步函数（而非 async def），内部直接使用同步
    SQLAlchemy 调用（SessionLocal）。在 APScheduler 中配置此 job 时应使用
    ThreadPoolExecutor（而非 AsyncExecutor），以避免阻塞事件循环。
    选择同步路径的理由：函数逻辑为纯 I/O 密集的数据库操作，同步编程模型更简洁、
    错误处理更直观（try/except 直接包裹），且在 APScheduler 的
    ThreadPoolExecutor 中运行不会影响 API 事件循环。
    """
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        sensor_retention_days = 30  # 可从环境变量读取
        control_retention_days = 90

        # 步骤 1：聚合 30 天前的 sensor_snapshot 到日聚合表
        cutoff_sensor = (now - timedelta(days=sensor_retention_days)).replace(tzinfo=None)
        agg_date = cutoff_sensor.date()

        db.execute(text("""
            INSERT INTO sensor_daily_aggregation (
                device_id, agg_date,
                avg_temperature, max_temperature, min_temperature,
                avg_humidity, max_humidity, min_humidity,
                avg_light, max_light, min_light,
                avg_co2, max_co2, min_co2,
                record_count
            )
            SELECT
                device_id, DATE(timestamp) AS agg_date,
                AVG(temperature), MAX(temperature), MIN(temperature),
                AVG(humidity), MAX(humidity), MIN(humidity),
                AVG(light), MAX(light), MIN(light),
                AVG(co2), MAX(co2), MIN(co2),
                COUNT(*)
            FROM sensor_snapshot
            WHERE timestamp < :cutoff
            GROUP BY device_id, DATE(timestamp)
            ON CONFLICT (device_id, agg_date) DO NOTHING
        """), {"cutoff": cutoff_sensor})

        # 步骤 2：删除已聚合的原始明细
        db.execute(text("""
            DELETE FROM sensor_snapshot
            WHERE timestamp < :cutoff
        """), {"cutoff": cutoff_sensor})

        # 步骤 3：删除过期控制日志
        cutoff_control = (now - timedelta(days=control_retention_days)).replace(tzinfo=None)
        db.execute(text("""
            DELETE FROM control_logs
            WHERE timestamp < :cutoff
        """), {"cutoff": cutoff_control})

        db.commit()
        logger.info(
            "Data retention cleanup completed: sensor before %s, control before %s",
            cutoff_sensor, cutoff_control
        )
    except Exception as e:
        db.rollback()
        logger.error("Data retention cleanup failed: %s", str(e))
    finally:
        db.close()
```

### 2.5 KingbaseES V8 完整等效配置

本节提供 KingbaseES V8 的完整等效配置，适用于需要严格遵循架构文档 KingbaseES 要求的部署场景。本方案主体使用 PostgreSQL 16 Alpine（理由见 §2.1.1 及 §2.5.6 的切换决策说明），以下提供在需要 KingbaseES 时的完整配置指引。

#### 2.5.1 Docker 镜像获取与加载

KingbaseES V8 商业版 Docker 镜像需要从人大金仓获取，步骤如下：

1. 向人大金仓（https://www.kingbase.com.cn）申请商业授权或课程项目试用许可
2. 从授权渠道获取 Docker 镜像 tar 文件（约 1.5GB）
3. 在 VPS 上执行导入：

```bash
# 加载镜像
docker load -i kingbase_v8_V008R006C008B0020.tar

# 验证镜像
docker images | grep kingbase
# 输出示例: kingbase/kb_v8   V008R006C008B0020   abc123def456   ...
```

#### 2.5.2 docker-compose 服务定义

替换 §1.5.1 中 `db` 服务为以下定义：

```yaml
db:
  image: kingbase/kb_v8:V008R006C008B0020
  container_name: farmeye-db
  ports:
    - "127.0.0.1:5432:5432"   # 仅 Docker 内网，不对外暴露
  environment:
    DB_USER: farmeye
    DB_PASSWORD: farmeye_pwd
    DB_NAME: farmeye_db
    # KingbaseES 内存参数（适配 1GB RAM）
    SHARED_BUFFERS: 64MB
    EFFECTIVE_CACHE_SIZE: 256MB
    WORK_MEM: 4MB
    MAINTENANCE_WORK_MEM: 16MB
    MAX_CONNECTIONS: "10"
  volumes:
    - kingbase_data:/var/lib/kingbase/data
    - ./init/:/docker-entrypoint-initdb.d/
  healthcheck:
    test: ["CMD-SHELL", "ksql -U ${DB_USER} -d ${DB_NAME} -c 'SELECT 1' || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 120s   # KingbaseES 首次启动较慢（~2min）
  restart: unless-stopped
  networks:
    - farmeye-net
  deploy:
    resources:
      limits:
        memory: 384M
      reservations:
        memory: 256M
```

#### 2.5.3 连接字符串

```ini
# KingbaseES V8 兼容 PostgreSQL 网络协议，连接串格式与 PostgreSQL 相同
DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@db:5432/farmeye_db
```

KingbaseES V8 支持 PostgreSQL 的线缆协议，因此 SQLAlchemy（psycopg2 驱动）、Alembic 迁移工具均可直接使用，DDL 和 SQL 语法也完全兼容（KingbaseES V8 基于 PostgreSQL 内核）。

> **已知差异**：
> - `BIGSERIAL` 在 KingbaseES 中内部映射为 `BIGINT` + `SEQUENCE`，功能与 PostgreSQL 一致，DDL 无需修改
> - 项目 DDL 中未使用 PostgreSQL 专有扩展（如 `pg_trgm`），不构成兼容性问题
> - `pg_isready` 工具在部分 KingbaseES 镜像中可用；健康检查命令可优先使用 `ksql -c 'SELECT 1'`

#### 2.5.4 资源调优参数（1GB RAM）

针对 1GB RAM VPS 的 KingbaseES 关键参数调整：

```ini
# KingbaseES 关键参数（通过环境变量或 kingbase.conf 配置）
shared_buffers = 64MB              # 1GB 环境下降低至 64MB
effective_cache_size = 256MB       # 操作系统缓存预估
work_mem = 4MB                     # 每排序操作内存
maintenance_work_mem = 16MB        # 维护操作
max_connections = 10               # 单 API 实例足够
checkpoint_timeout = 15min         # 减少写盘频率
wal_buffers = 1MB                  # WAL 缓冲区缩小
```

#### 2.5.5 备份脚本适配

§2.3.2 的备份脚本中 `pg_dump`/`psql` 命令需替换为 KingbaseES 的等效命令：

| PostgreSQL 命令 | KingbaseES 等效命令 | 说明 |
|:----------------|:-------------------|:-----|
| `pg_dump` | `sys_dump` | 数据库导出 |
| `psql` | `ksql` | 交互式查询 |
| `pg_isready` | `ksql -c 'SELECT 1'` | 健康检查 |

每日备份命令示例：

```bash
docker exec farmeye-db sys_dump \
    --format=plain \
    --file="/tmp/farmeye_daily_${TIMESTAMP}.sql" \
    -U farmeye farmeye_db
```

#### 2.5.6 数据库选型决策说明

本方案主体以 PostgreSQL 16 Alpine 作为实际部署推荐，理由如下：

| 因素 | PostgreSQL 16 Alpine | KingbaseES V8 |
|------|:-------------------:|:-------------:|
| Docker Hub 公开可用 | 是，直接 `docker pull` | 否，需商业授权后获取 |
| 镜像大小 | ~200MB（Alpine） | ~1.5GB |
| 1GB RAM 适配 | 成熟，可通过参数精确控制 | 需额外调优 |
| DDL/SQL 兼容性 | — | 兼容 PostgreSQL 协议，DDL 无需修改 |
| 国产化合规 | 否 | 是 |
| Digital Ocean VPS 部署 | 直接可用 | 需手动导入镜像 |
| 开发环境一致性 | 本地 `docker pull` 即可 | 需先获取镜像，增加开发环境搭建门槛 |

**建议**：
- **开发/测试/课程演示阶段**：使用 PostgreSQL 16 Alpine 快速启动，降低环境搭建复杂度和资源占用
- **生产部署/国产化合规要求**：按照本附录 §2.5.2 的配置切换至 KingbaseES，DDL 和数据无需修改，仅需替换 docker-compose 中的 `db` 服务定义和备份脚本命令
- 两种数据库可共享同一套 DDL 初始化脚本（`init/01_create_tables.sql`），零迁移成本

---

## 3. VPS 部署方案

### 3.1 VPS 初始化配置

#### 3.1.1 初始 SSH 登录与安全加固

```bash
# 1. SSH 登录（使用 root 或初始用户）
ssh root@<VPS_IP>

# 2. 创建普通用户并赋予 sudo
adduser farmeye
usermod -aG sudo farmeye

# 3. 配置 SSH 密钥登录（禁用密码登录）
su - farmeye
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# 将本地公钥追加到 ~/.ssh/authorized_keys
echo "<your-public-key>" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 4. 编辑 SSH 配置 /etc/ssh/sshd_config
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# 5. 配置 UFW 防火墙
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh              # 端口 22
sudo ufw allow 80/tcp           # HTTP
sudo ufw allow 443/tcp          # HTTPS（如需）
# sudo ufw allow 8000/tcp         # API（仅在无 Nginx 时开放；生产环境启用 Nginx 时无需此规则）
sudo ufw --force enable
```

#### 3.1.2 Docker 安装

```bash
# Ubuntu 25.04 Docker 安装（使用官方 apt 源）
# 注意：如果 Ubuntu 25.04 尚未被 docker.com 收录，回退至
# Ubuntu 24.04 LTS 的仓库。以下命令通用：

sudo apt-get update
sudo apt-get install -y ca-certificates curl

# 添加 Docker 官方 GPG 密钥
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 添加仓库（使用 noble=24.04 代号，对 25.04 兼容）
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu noble stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

# 将 farmeye 用户加入 docker 组（免 sudo 执行 docker）
sudo usermod -aG docker farmeye

# 验证安装
docker --version
docker compose version
```

#### 3.1.3 系统优化（1GB RAM）

```bash
# 1. 增加 swap 空间（防 OOM 兜底）
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 2. 调整内核参数
cat << 'EOF' | sudo tee /etc/sysctl.d/99-farmeye.conf
# FarmEye Guard — 低内存优化
vm.swappiness=10              # 减少 swap 使用倾向
vm.vfs_cache_pressure=50      # 延长 dentry/inode 缓存保留时间
net.core.somaxconn=1024       # 连接队列
net.ipv4.tcp_fin_timeout=15   # 加快 TIME_WAIT 回收
net.ipv4.tcp_tw_reuse=1       # 复用 TIME_WAIT 连接
EOF
sudo sysctl --system

# 3. 关闭不必要的系统服务（节省内存）
sudo systemctl disable --now snapd.service 2>/dev/null || true
sudo systemctl disable --now whoopsie.service 2>/dev/null || true
sudo systemctl disable --now motd-news.service 2>/dev/null || true
```

### 3.2 Docker Compose 部署流程

#### 3.2.1 项目文件部署

```bash
# 1. 在 VPS 上创建项目目录
mkdir -p /opt/farmeye
mkdir -p /opt/farmeye/{logs,backups,images,nginx,init}

# 2. 将项目文件上传至 VPS
# 在本地执行：
# rsync -avz --exclude='.venv' --exclude='__pycache__' \
#   --exclude='.git' --exclude='*.pyc' \
#   server/ farmeye@<VPS_IP>:/opt/farmeye/

# 或使用 scp：
# scp -r server/ farmeye@<VPS_IP>:/opt/farmeye/
```

#### 3.2.2 部署命令

```bash
# 3. 创建生产环境变量文件
# 注意：手动创建 /opt/farmeye/.env.prod，填入真实值

# 4. 构建并启动服务（生产模式）
cd /opt/farmeye

# 使用主文件 + 生产覆写文件合并启动
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    --compatibility \
    up -d --build

# 5. 验证部署
docker compose ps                    # 查看服务状态
docker compose logs api --tail=50    # 查看 API 日志
curl http://localhost:8000/api/v1/health  # 健康检查
docker inspect farmeye-api | jq '.[0].HostConfig.Memory'
# 预期输出：268435456（即 256M，确认 --compatibility 资源限制生效）
```

#### 3.2.3 版本更新流程

```bash
# 更新 API 代码后重新部署
cd /opt/farmeye

# 拉取最新代码（或 rsync）
# 仅重建 api 服务
docker compose build api

# 重新启动（零停机：先启动新容器，再停止旧容器）
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    up -d --no-deps --build api

# 回滚（如需）
# docker compose --profile production up -d --no-deps api  # 使用旧镜像
```

### 3.3 Nginx 反向代理配置

#### 3.3.1 server/nginx/farmeye.conf

```nginx
# FarmEye Guard — Nginx 反向代理配置
# 部署路径：/opt/farmeye/nginx/farmeye.conf
# 在 docker-compose.prod.yml 中通过 volume 挂载至容器内

upstream farmeye_api {
    server api:8000;
    keepalive 32;
}

# HTTP → HTTPS 重定向（SSL 启用时生效）
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

# HTTPS 服务器（SSL 配置）
server {
    listen 443 ssl http2;
    server_name _;

    # SSL 证书路径（通过 Certbot 或手动配置）
    ssl_certificate     /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    # SSL 协议与加密套件
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # API 反向代理
    location /api/ {
        proxy_pass http://farmeye_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 升级支持（预留 WebSocket 未来升级）
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 超时配置
        proxy_connect_timeout 30s;
        proxy_read_timeout 30s;
        proxy_send_timeout 30s;

        # 缓冲
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 8k;
    }

    # 图片文件静态资源（直接由 Nginx 服务，不经过 Python）
    location /images/ {
        alias /usr/share/nginx/images/;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # 健康检查（直接转发至 API）
    location /api/v1/health {
        access_log off;
        proxy_pass http://farmeye_api;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # 访问日志格式
    log_format farmeye '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent"';

    access_log /var/log/nginx/farmeye_access.log farmeye;
    error_log /var/log/nginx/farmeye_error.log warn;
}
```

#### 3.3.2 Nginx 启用/禁用

```bash
# Nginx 在 docker-compose.prod.yml 中定义，故：
# 启用：合并启动时自动启动
# 禁用：注释 docker-compose.prod.yml 中 nginx 段落后重启
```

#### 3.3.3 SSL 证书管理（Certbot + Let's Encrypt）

SSL 证书使用 Let's Encrypt 免费证书，通过 Certbot 自动申请与续期。

**首次证书申请**：

```bash
# 1. 安装 Certbot（VPS 宿主机上，非容器内）
sudo apt-get install -y certbot

# 2. 申请证书（手动验证，需域名已解析至 VPS IP）
sudo certbot certonly --standalone -d farmeye.example.com

# 3. 将证书复制到 Nginx SSL 目录
sudo mkdir -p /opt/farmeye/nginx/ssl
sudo cp /etc/letsencrypt/live/farmeye.example.com/fullchain.pem \
    /opt/farmeye/nginx/ssl/
sudo cp /etc/letsencrypt/live/farmeye.example.com/privkey.pem \
    /opt/farmeye/nginx/ssl/
sudo chmod 600 /opt/farmeye/nginx/ssl/privkey.pem
```

**自动续期配置**：

```bash
# 1. 测试续期
sudo certbot renew --dry-run

# 2. 续期后自动更新证书文件（通过 cron 或 systemd timer）
# 创建续期后复制证书的 hook 脚本
sudo tee /etc/letsencrypt/renewal-hooks/deploy/farmeye-nginx.sh << 'SCRIPT'
#!/bin/bash
cp /etc/letsencrypt/live/farmeye.example.com/fullchain.pem \
    /opt/farmeye/nginx/ssl/
cp /etc/letsencrypt/live/farmeye.example.com/privkey.pem \
    /opt/farmeye/nginx/ssl/
chmod 600 /opt/farmeye/nginx/ssl/privkey.pem
docker exec farmeye-nginx nginx -s reload
SCRIPT

sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/farmeye-nginx.sh

# 3. 验证部署
curl -k https://localhost:443/api/v1/health
```

> **说明**：
> - 首次证书申请前，需确保域名（如 `farmeye.example.com`）已通过 DNS A 记录解析至 VPS 的公网 IP 地址
> - 生产部署中，建议使用 DNS-01 挑战模式（Certbot 配合 DNS 插件），不依赖 `:80` 端口的临时占用
> - 证书文件路径在 `docker-compose.prod.yml` 中通过 volume 挂载至 Nginx 容器内的 `/etc/nginx/ssl/` 目录

### 3.4 日志收集与管理方案

#### 3.4.1 日志策略

| 日志来源 | 存储方式 | 路径 | 轮转策略 |
|---------|---------|------|---------|
| API（Uvicorn） | Docker json-file driver | `docker logs farmeye-api` | max-size=10m, max-file=3 |
| API（应用日志） | 文件挂载 + logging | `/opt/farmeye/logs/app.log` | Python RotatingFileHandler 10MB×5 |
| 数据库（PostgreSQL 16） | Docker json-file driver | `docker logs farmeye-db` | max-size=10m, max-file=3 |
| Nginx 访问日志 | Docker json-file driver | `docker logs farmeye-nginx` | max-size=10m, max-file=3 |
| 系统日志 | systemd journal | `journalctl` | journald 默认策略 |

#### 3.4.2 应用日志配置

```python
# server/app/core/logging_config.py
import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path

LOG_DIR = Path("/app/logs")
LOG_DIR.mkdir(parents=True, exist_ok=True)

def setup_logging(level: str = "INFO"):
    """配置应用日志"""
    formatter = logging.Formatter(
        fmt="%(asctime)s | %(levelname)-8s | %(name)s:%(funcName)s:%(lineno)d | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # 控制台输出
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)

    # 文件输出（10MB 轮转，保留 5 个文件）
    file_handler = RotatingFileHandler(
        LOG_DIR / "app.log",
        maxBytes=10 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8"
    )
    file_handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    root_logger.addHandler(console_handler)
    root_logger.addHandler(file_handler)

    # 第三方库日志级别调整
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
```

#### 3.4.3 日志查看

```bash
# 实时查看 API 日志
docker compose logs -f api

# 查看最近 100 行应用日志
docker compose exec api tail -100 /app/logs/app.log

# 查看 Nginx 访问日志（如启用）
docker compose exec nginx tail -f /var/log/nginx/farmeye_access.log
```

### 3.5 容器资源限制配置

在 `docker-compose.yml` 的 `deploy.resources` 中定义限制（已应用于 §1.5 的编排文件）：

| 服务 | 内存限制 | 内存预留 | CPU 限制 |
|------|---------|---------|---------|
| api | 256M | 128M | 无（默认共享） |
| db | 384M | 256M | 无（默认共享） |
| nginx（可选） | 64M | 32M | 无（默认共享） |

> **说明**：上表为生产环境限制值。`deploy.resources.limits` 在 docker compose 的 `--compatibility` 模式下生效，会转换为容器的 `--memory` 和 `--memory-reservation` 参数。主 `docker-compose.yml` （§1.5.1）中 DB 默认限制为 256M（开发环境），生产覆写文件 `docker-compose.prod.yml`（§1.5.2）将 DB 提升至 384M。部署生产环境时务必使用 `-f docker-compose.yml -f docker-compose.prod.yml --compatibility` 合并启动。
>
> **`--compatibility` 说明**：`docker compose --compatibility` 模式在不同 Docker Compose 版本间行为可能不一致（例如 v1 与 v2 版的实现细节差异）。部署到新的 Docker Compose 环境时，应通过以下命令验证资源限制是否生效：
> ```bash
> docker inspect farmeye-api | jq '.[0].HostConfig.Memory'
> # 预期输出：268435456（即 256M）
> ```
> 若返回 `0` 表示资源限制未生效，需排查 Docker Compose 版本兼容性或改用原生 `mem_limit`/`mem_reservation` 参数（非 `deploy` 子节）。

### 3.6 启动与停止脚本

#### 3.6.1 deploy/scripts/start.sh

```bash
#!/bin/bash
# FarmEye Guard — VPS 生产启动脚本
# 用法: ./start.sh
#
# 说明：使用 docker-compose.yml 主文件 + docker-compose.prod.yml
# 生产覆写文件合并启动，确保 Nginx 服务和生产覆写配置生效。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "[FarmEye] 启动服务..."

# 合并主文件 + 生产覆写文件启动
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    --compatibility \
    up -d --build

echo "[FarmEye] 服务启动完成"

# 等待健康检查
echo "[FarmEye] 等待 API 健康检查..."
for i in $(seq 1 12); do
    if curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"'; then
        echo "[FarmEye] API 服务健康"
        break
    fi
    if [ "$i" -eq 12 ]; then
        echo "[FarmEye] 警告: API 健康检查超时，请查看日志"
        docker compose logs api --tail=20
    fi
    sleep 5
done

docker compose ps
echo "[FarmEye] 部署完成"
```

#### 3.6.2 deploy/scripts/stop.sh

```bash
#!/bin/bash
# FarmEye Guard — VPS 生产停止脚本
# 用法: ./stop.sh [--down] [--volumes]
#   --down     停止并移除容器（默认仅 stop）
#   --volumes  同时移除数据卷（危险！）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

if [ "${1:-}" = "--down" ]; then
    echo "[FarmEye] 停止并移除容器..."
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --profile production \
        down
    echo "[FarmEye] 容器已移除"
elif [ "${1:-}" = "--volumes" ]; then
    echo "[FarmEye] 警告: 将移除所有容器和数据卷！"
    echo "[FarmEye] 5 秒后执行，按 Ctrl+C 取消..."
    sleep 5
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --profile production \
        down --volumes
    echo "[FarmEye] 容器和数据卷已移除"
else
    echo "[FarmEye] 停止服务（保留容器）..."
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --profile production \
        stop
    echo "[FarmEye] 服务已停止"
fi
```

#### 3.6.3 deploy/scripts/restart.sh

```bash
#!/bin/bash
# FarmEye Guard — VPS 生产重启脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
echo "[FarmEye] 重启服务..."
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    restart
echo "[FarmEye] 服务已重启"
```

---

## 4. 测试方案

### 4.1 单元测试框架与组织

#### 4.1.1 测试框架选择

| 项目 | 选择 | 理由 |
|------|------|------|
| 测试框架 | pytest 8.x | 广泛使用，插件生态丰富，fixture 机制灵活 |
| 异步支持 | pytest-asyncio | FastAPI 路由为 async 函数，需异步测试支持 |
| HTTP 测试 | httpx.AsyncClient | FastAPI TestClient 基于 httpx |
| Mock | unittest.mock（内置） | 无需额外依赖 |
| 覆盖率 | pytest-cov | 主要用于 CI 门禁 |

#### 4.1.2 测试目录结构

```
server/tests/
├── __init__.py
├── conftest.py                 # 全局 fixture（含 pytest 钩子）
├── test_sensor.py              # 传感器数据查询接口测试
├── test_disease.py             # 病虫害记录接口测试
├── test_command.py             # 设备控制接口测试
├── test_advisory.py            # 防治建议接口测试
├── test_image.py               # 图片上传/获取接口测试
├── test_device.py              # 设备列表接口测试
├── test_iotda_webhook.py       # IoTDA Webhook 接收端点测试
├── test_health.py              # 健康检查端点测试
│
├── integration/
│   ├── __init__.py
│   ├── test_db_ddl.py          # DDL 验证（表结构检查）
│   ├── test_db_crud.py         # 基本 CRUD 操作
│   └── test_db_retention.py    # 数据保留策略验证
│
├── docker/
│   ├── __init__.py
│   ├── test_container_start.py  # 容器启动测试
│   ├── test_healthcheck.py      # 健康检查验证
│   └── test_network.py          # 容器间通信测试
│
├── e2e/
│   ├── __init__.py
│   └── test_e2e.py             # 端到端全链路测试
│
└── conftest_docker.py          # Docker 测试专用 fixture
```

#### 4.1.3 server/tests/conftest.py（全局 fixture 和 pytest 钩子）

```python
"""
全局测试配置、fixture 和 pytest 钩子函数。

pytest 钩子函数（pytest_addoption, pytest_configure,
pytest_collection_modifyitems）必须定义在 conftest.py 或注册的插件中，
不会被 pytest 从 test_*.py 文件中自动发现。
"""
import pytest
import asyncio
from typing import AsyncGenerator, Generator
from httpx import AsyncClient, ASGITransport

# ============================================================
# pytest 钩子：命令行选项与 marker 注册
# ============================================================

def pytest_addoption(parser: pytest.Parser) -> None:
    """注册自定义命令行参数"""
    parser.addoption(
        "--run-e2e",
        action="store_true",
        default=False,
        help="运行端到端测试（需要 Docker 环境）"
    )
    parser.addoption(
        "--run-docker",
        action="store_true",
        default=False,
        help="运行 Docker 相关测试（需要 Docker 环境）"
    )
    parser.addoption(
        "--run-integration",
        action="store_true",
        default=False,
        help="运行数据库集成测试（需要数据库连接）"
    )
    parser.addoption(
        "--run-performance",
        action="store_true",
        default=False,
        help="运行性能测试"
    )


def pytest_configure(config: pytest.Config) -> None:
    """注册自定义 markers"""
    config.addinivalue_line("markers", "e2e: 端到端测试，需要 Docker 环境")
    config.addinivalue_line("markers", "docker: Docker 容器相关测试")
    config.addinivalue_line("markers", "integration: 数据库集成测试")
    config.addinivalue_line("markers", "performance: 性能测试")
    config.addinivalue_line("markers", "slow: 慢速测试，默认跳过")


def pytest_collection_modifyitems(
    config: pytest.Config, items: list[pytest.Item]
) -> None:
    """根据命令行参数条件性跳过测试"""
    run_e2e = config.getoption("--run-e2e")
    run_docker = config.getoption("--run-docker")
    run_integration = config.getoption("--run-integration")
    run_performance = config.getoption("--run-performance")

    skip_e2e = pytest.mark.skipif(
        not run_e2e, reason="需要 --run-e2e 选项来运行"
    )
    skip_docker = pytest.mark.skipif(
        not run_docker, reason="需要 --run-docker 选项来运行"
    )
    skip_integration = pytest.mark.skipif(
        not run_integration, reason="需要 --run-integration 选项来运行"
    )
    skip_performance = pytest.mark.skipif(
        not run_performance, reason="需要 --run-performance 选项来运行"
    )

    for item in items:
        if "e2e" in item.keywords:
            item.add_marker(skip_e2e)
        elif "docker" in item.keywords:
            item.add_marker(skip_docker)
        elif "integration" in item.keywords:
            item.add_marker(skip_integration)
        elif "performance" in item.keywords:
            item.add_marker(skip_performance)


# ============================================================
# 全局 Fixtures
# ============================================================

@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """为 async 测试创建事件循环（session 级复用）"""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """
    提供 FastAPI TestClient（httpx.AsyncClient 封装）。

    需要 API 应用实例，此处示意结构。实际使用时需 import app.main
    并创建 ASGITransport。
    """
    # from app.main import app
    # transport = ASGITransport(app=app)
    # async with AsyncClient(transport=transport, base_url="http://test") as client:
    #     yield client
    yield  # 占位，实现时替换


@pytest.fixture
def sample_sensor_payload() -> dict:
    """示例传感器上报 payload"""
    return {
        "resource": "device.property",
        "event": "report",
        "event_time": "2026-06-30T10:15:30Z",
        "notify_data": {
            "header": {
                "device_id": "farmeye_guard_ws63",
                "product_id": "farmeye_guard",
                "app_id": "farmeye_guard_app"
            },
            "body": {
                "services": [{
                    "service_id": "farmeye_env",
                    "properties": {
                        "temperature": 25.5,
                        "humidity": 60.2,
                        "light": 85,
                        "co2": 450,
                        "soil_n": 50.1,
                        "soil_p": 24.0,
                        "soil_k": 51.7,
                        "distance": 150,
                        "rssi": -45,
                        "ip_addr": "192.168.1.100",
                        "mac_addr": "A1:B2:C3:D4:E5:F6",
                        "alarm_flag": 0
                    }
                }]
            }
        }
    }


@pytest.fixture
def sample_ai_payload() -> dict:
    """示例 AI 识别结果上报 payload"""
    return {
        "resource": "device.message",
        "event": "report",
        "event_time": "2026-06-30T10:15:30Z",
        "notify_data": {
            "header": {"device_id": "farmeye_guard_ws63"},
            "body": {
                "services": [{
                    "service_id": "farmeye_ai",
                    "properties": {
                        "crop_type": "wheat",
                        "disease_type": "rust",
                        "confidence": 0.92,
                        "severity": "Moderate",
                        "severity_code": 2
                    }
                }]
            }
        }
    }
```

### 4.2 API 接口测试

所有 API 测试用例覆盖架构文档 §4 定义的完整接口规范。按接口分组，每组例举关键测试用例。

#### 4.2.1 IoTDA Webhook 接收端点测试

| # | 测试用例 | 输入 | 预期结果 | 类型 |
|---|---------|------|---------|------|
| 1 | 正常传感器属性上报 | 完整 `farmeye_env` payload | HTTP 200, `code=0` | Unit |
| 2 | 正常 AI 识别结果上报 | 完整 `farmeye_ai` payload | HTTP 200, `code=0` | Unit |
| 3 | 正常命令应答上报 | 完整命令应答 payload | HTTP 200, `code=0` | Unit |
| 4 | 重复属性上报（幂等性） | 两次相同 payload（IoTDA 重试模拟） | 返回 200，数据库无重复记录 | Unit |
| 5 | 重复 AI 结果上报（幂等性） | 两次相同 AI payload | 返回 200，数据库无重复记录 | Unit |
| 6 | 无效 payload 格式 | 缺少 `notify_data` | HTTP 422 或业务层拒绝 | Unit |
| 7 | 未知 service_id | properties 但 `service_id=unknown` | 返回 200，不写入数据库 | Unit |
| 8 | 数据库写入失败 | Mock DB session 抛异常 | HTTP 500，触发 IoTDA 重试 | Unit |
| 9 | 传感器上报时 device 不存在 | 新 device_id 首次上报 | 自动创建设备记录 + 写入传感器数据 | Unit |

#### 4.2.2 传感器数据查询接口测试

| # | 测试用例 | 输入 | 预期结果 | 类型 |
|---|---------|------|---------|------|
| 10 | 查询最新传感器数据（指定设备） | `device_id=farmeye_guard_ws63` | 200，返回单条最新记录 | Unit |
| 11 | 查询最新传感器数据（不指定设备） | 无参数 | 200，返回所有设备最新记录 | Unit |
| 12 | 查询历史传感器数据（分页） | `page=1, page_size=10` | 200，返回 10 条记录 + total | Unit |
| 13 | 查询历史传感器数据（时间范围） | `start=..., end=...` | 200，仅返回范围内的记录 | Unit |
| 14 | page_size 超过 100 | `page_size=200` | 200，实际 page_size=100 | Unit |
| 15 | page 超出范围 | `page=9999` | 200，空 records 列表 | Unit |
| 16 | 查询日聚合数据 | `start=2026-06-01, end=2026-06-30` | 200，返回日聚合记录 | Unit |
| 17 | 获取设备列表 | 无参数 | 200，包含设备在线状态 | Unit |

#### 4.2.3 病虫害记录接口测试

| # | 测试用例 | 输入 | 预期结果 | 类型 |
|---|---------|------|---------|------|
| 18 | 查询病虫害记录列表（多条件筛选） | `crop_type=wheat, severity=Moderate` | 200，返回筛选后的记录 | Unit |
| 19 | 查询病虫害记录列表（仅时间范围） | `start=..., end=...` | 200 | Unit |
| 20 | 查询病虫害统计 | `start=..., end=...` | 200，返回按作物/严重度/类型的统计 | Unit |
| 21 | 查询热力图数据 | 无参数 | 200，返回 heatmap_points + summary | Unit |
| 22 | 无数据时查询 | 无匹配条件 | 200，空 records | Unit |

#### 4.2.4 设备控制接口测试

| # | 测试用例 | 输入 | 预期结果 | 类型 |
|---|---------|------|---------|------|
| 23 | 手动下发控制命令（设备在线） | `{device_id, command: "spray ON", source: "manual_app"}` | 200，`status=sent`，返回 command_id | Unit |
| 24 | 手动下发控制命令（设备离线） | 设备状态为离线时下发 | 200，`code=1003` 设备离线 | Unit |
| 25 | 控制命令缺少必填字段 | 缺少 `command` 字段 | 422 参数校验错误 | Unit |
| 26 | 查询控制日志（来源筛选） | `source=auto` | 200，仅返回自动触发的命令 | Unit |
| 27 | 查询控制日志（时间范围） | `start=..., end=...` | 200 | Unit |
| 28 | 查询控制日志（分页） | `page=1, page_size=20` | 200 | Unit |

#### 4.2.5 防治建议与图片接口测试

| # | 测试用例 | 输入 | 预期结果 | 类型 |
|---|---------|------|---------|------|
| 29 | 获取防治建议（有最新检测） | 近期有 AI 识别记录 | 200，含 latest_detection + advisory | Unit |
| 30 | 获取防治建议（无检测） | 时间窗口内无识别记录 | 200，advisory 为 null | Unit |
| 31 | 获取防治建议（环境联动分析） | 有检测+环境数据 | 200，含 env_disease_linkage | Unit |
| 32 | 上传图片（关联病虫害记录） | multipart file + disease_record_id | 200，返回 image_id | Unit |
| 33 | 上传图片（文件过大） | 超过 10MB 的文件 | 422 或 413 | Unit |
| 34 | 获取已上传的图片 | 有效 image_id | 200，二进制流 | Unit |
| 35 | 获取不存在的图片 | 无效 image_id | 200，`code=1002` | Unit |
| 36 | 导出传感器数据（CSV） | `format=csv` | 200，text/csv 文件流 | Unit |
| 37 | 导出传感器数据（Excel） | `format=xlsx` | 200，xlsx 文件流 | Unit |
| 38 | 导出数据超过限制 | 时间范围超过 10 万条 | 200，`code=1001` | Unit |

#### 4.2.6 健康检查与安全测试

| # | 测试用例 | 输入 | 预期结果 | 类型 |
|---|---------|------|---------|------|
| 39 | 健康检查（全部正常） | 无参数 | 200，`status=healthy` | Unit |
| 40 | 健康检查（数据库断开） | DB 连接失败 | HTTP 503，`status=degraded` | Unit |
| 41 | 无 API Key 请求（启用了认证） | `X-API-Key` 头缺失 | 401 `code=1004` | Unit |
| 42 | 无效 API Key | `X-API-Key: invalid` | 401 `code=1004` | Unit |
| 43 | 有效 API Key | `X-API-Key: valid_key` | 正常响应 | Unit |
| 44 | 请求频率限制（如实现） | 连续 100 次请求 | 429 或 200 `code=1005` | Unit |
| 45 | SQL 注入尝试 | `device_id="'; DROP TABLE--"` | 安全处理，无 SQL 注入 | Unit |
| 46 | XSS 尝试 | payload 中包含 `<script>` | 响应不渲染 HTML | Unit |
| 47 | 路径遍历尝试 | `image_id="../../etc/passwd"` | 安全拒绝 | Unit |
| 48 | 超大 page_size | `page_size=99999` | 200，自动截断至 100 | Unit |

### 4.3 数据库集成测试

#### 4.3.1 测试环境

数据库集成测试需要真实或内存数据库。测试配置使用独立的测试数据库，避免污染开发/生产数据。

```python
# pytest 配置（conftest.py 中）
# 使用独立的测试数据库连接字符串，优先从环境变量读取
import os
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_test"
)
```

#### 4.3.2 数据库集成测试用例

| # | 测试用例 | 操作 | 预期结果 | 类型 |
|---|---------|------|---------|------|
| 1 | 全部 5 个表创建验证 | 执行 `01_create_tables.sql` 并查询 `information_schema.tables` | 5 个表全部存在 | DDL |
| 2 | 所有 UNIQUE 索引存在 | 查询索引信息 | sensor_snapshot: (device_id, timestamp); disease_records: (device_id, timestamp, disease_type); control_logs: command_id; devices: device_id; 日聚合: (device_id, agg_date) | DDL |
| 3 | sensor_snapshot UNIQUE 约束生效 | 插入重复 (device_id, timestamp) | 第二行被拒绝或 ON CONFLICT 生效 | DDL |
| 4 | control_logs 部分索引验证 | 插入 NULL 和 非 NULL command_id 的重复 | 非 NULL 重复被拒绝；NULL 可以重复 | DDL |
| 5 | sensor_snapshot 插入与查询 | 插入一条完整传感器数据 | SELECT 返回该行，所有字段值正确 | CRUD |
| 6 | disease_records 插入与查询 | 插入一条病虫害记录 | SELECT 返回该行 | CRUD |
| 7 | control_logs 插入与更新 | 先插入，再通过 command_id 更新 result_code | UPDATE 生效 | CRUD |
| 8 | 日聚合查询 | 向 sensor_snapshot 插入多条数据后查询聚合 | AVG/MAX/MIN 计算正确 | CRUD |
| 9 | 数据清理（sensor_snapshot 30 天） | 插入 30 天前和 1 天前的数据，运行 cleanup | 仅 30 天前数据被删除 | 保留策略 |
| 10 | 数据清理（control_logs 90 天） | 插入 90 天前和 1 天前的数据，运行 cleanup | 仅 90 天前数据被删除 | 保留策略 |
| 11 | 日聚合后再清理数据完整性 | 先聚合 30 天前数据，再删除原始明细 | 聚合表包含正确统计数据 | 保留策略 |
| 12 | 并发写入（模拟 IoTDA 重试） | 两个连接同时插入相同 (device_id, timestamp) | 仅一条写入成功 | 并发 |

### 4.4 Docker 容器测试

#### 4.4.1 测试前提

Docker 测试需要 Docker 运行环境，使用 `--run-docker` 选项启用。

#### 4.4.2 Docker 测试用例

| # | 测试用例 | 操作 | 预期结果 | 类型 |
|---|---------|------|---------|------|
| 1 | API 容器正常启动 | `docker compose up -d api` | 容器状态为 running | 启动 |
| 2 | API 健康检查通过 | 等待 30s 后检查 health 端点 | `GET /api/v1/health` 返回 `{"status":"healthy"}` | 健康检查 |
| 3 | 数据库容器正常启动 | `docker compose up -d db` | 容器状态为 running | 启动 |
| 4 | DB 健康检查通过 | 等待 60s 后 | `pg_isready -U farmeye -d farmeye_db` 执行成功 | 健康检查 |
| 5 | API → DB 容器间通信 | API 容器 curl db:5432 | TCP 连接成功 | 网络 |
| 6 | API 可通过 hostname "db" 访问数据库 | API 应用连接 `DATABASE_URL` | 数据库查询正常返回 | 网络 |
| 7 | API 端口映射 | 宿主机 curl `localhost:8000/api/v1/health` | 200 响应 | 端口 |
| 8 | DB 端口未对外暴露 | 从 VPS 外部 telnet `<IP>:5432` | 连接超时或被拒绝 | 安全 |
| 9 | Volume 持久化验证 | 写入图片文件后重启容器 | 文件存在 | 持久化 |
| 10 | 资源限制生效 | `docker stats` 观察 | API ≤ 256M, DB ≤ 384M | 资源 |

### 4.5 端到端测试

#### 4.5.1 测试前提

端到端测试需要完整的 Docker 环境 + 真实 API 和数据库服务运行，使用 `--run-e2e` 选项启用。

#### 4.5.2 端到端测试用例

| # | 测试用例 | 模拟流程 | 验证点 | 类型 |
|---|---------|---------|--------|------|
| 1 | 传感器上报 → 持久化全链路 | POST IoTDA Webhook（传感器数据）→ API 写入 → GET sensor/latest | 最新数据与上报一致 | Full |
| 2 | AI 识别 → 决策 → 控制全链路 | POST AI 识别结果 → API 写入 disease_records → 决策引擎评估 → 自动下发命令 | disease_records 写入成功，control_logs 有对应记录 | Full |
| 3 | AI 识别 → 环境联动分析 | POST AI 识别 + 环境数据 → API 联动分析 → GET advisory | linkage_risk_level 和 linkage_detail 非空 | Full |
| 4 | 手动控制命令 → 日志记录 | POST /api/v1/command → 写入 control_logs → GET command/logs | 日志记录包含预生成的 command_id | Full |
| 5 | 图片上传 → 存储 → 获取 | POST image/upload → 文件写入 volume → GET image/{id} | 上传和获取的图片内容一致 | Full |
| 6 | 30 天数据保留触发 | 模拟插入超期数据 → 触发 cleanup | 超期数据被聚合和删除 | Full |
| 7 | 设备在线状态 → 离线识别 | 模拟连续上报 → 停止上报 35s → 查询设备状态 | 设备状态变为 offline | Full |

### 4.6 性能与压力测试方案

#### 4.6.1 测试工具

| 工具 | 用途 | 理由 |
|------|------|------|
| locust | HTTP 压力测试 | Python 编写，与项目技术栈一致，Web UI 实时监控 |
| `time` + `curl` | 单请求延迟测定 | 简单快速，无需额外工具 |
| `docker stats` | 容器资源监控 | 内置 Docker CLI 命令 |

#### 4.6.2 压力测试方案概述

针对 1 vCPU / 1GB RAM VPS 的极限约束，设计以下压力场景：

| # | 场景 | 模拟方式 | 目标 | 通过标准 |
|---|------|---------|------|---------|
| 1 | 单用户长时间轮询 | 1 个虚拟用户持续 5min 调用 sensor/latest | 服务稳定性 | 无 5xx 错误 |
| 2 | 多用户并发查询 | 10 虚拟用户并发 GET 请求（sensor/history, disease/records） | 并发查询能力 | P95 < 500ms |
| 3 | IoTDA Webhook 突发 | 20 个虚拟用户同时 POST 传感器数据（模拟多设备） | 写入吞吐 | 无 5xx，写入成功率 > 99% |
| 4 | 混合负载 | 5 读 + 2 写混合 | 读写共存场景 | P95 < 1000ms |
| 5 | 长时间运行 | 混合负载持续 30min | 内存泄漏检测 | 内存不持续增长 |
| 6 | 数据库连接池耗尽 | 30 并发请求触发长查询 | 连接池行为 | 请求排队而非崩溃 |
| 7 | 磁盘写入压力 | 连续上传大图片（5MB×20） | 图片写入+DB 混合 | 磁盘不耗尽，服务不 OOM |

#### 4.6.3 性能优化建议

| 方向 | 建议 | 预期效果 |
|------|------|---------|
| 数据库连接池 | SQLAlchemy `pool_size=2, max_overflow=2` | 控制最大连接数为 4，避免撑爆 PostgreSQL |
| API JSON 编码 | uvicorn `--limit-concurrency=20` | 限制并发请求数，排队而非崩溃 |
| 大查询分页 | 强制 `page_size <= 100` | 避免一次查询大量数据 |
| 日志 I/O | 异步日志 + 轮转 | 避免日志写盘阻塞请求处理 |
| 图片文件 | Nginx 直接服务静态文件 | 减少 Python 进程的文件读取开销 |
| 定时任务 | 数据清理避开业务高峰期 | 避免 cleanup 与 API 请求争用 CPU/IO |

---

## 5. 开发工作流

### 5.1 本地开发 → Docker 测试 → VPS 部署流程

```
[本地开发]          [Docker 测试]            [VPS 部署]
     |                    |                      |
 1. 编写代码        5. docker compose         8. rsync 至 VPS
     |               up -d --profile dev         |
 2. venv 激活        (API + DB 全栈)          9. docker compose
     |                    |                  -f docker-compose.yml
 3. 单元测试         6. 运行集成测试           -f docker-compose.prod.yml
  pytest                  |                  up -d --build
     |                 7. 端到端测试              |
 4. git commit            |                 10. curl healthcheck
     |                    |                      |
  ───┴───              ───┴───                ───┴───
  编码循环            容器验证循环             部署循环
```

#### 5.1.1 本地开发循环（每 ~10 分钟）

```bash
# 1. 激活虚拟环境
source .venv/bin/activate

# 2. 运行单元测试（快，< 30s）
cd server
pytest tests/ -v --ignore=tests/integration --ignore=tests/docker --ignore=tests/e2e

# 3. 代码格式检查
ruff check app/ tests/
ruff format app/ tests/

# 4. 类型检查
mypy app/

# 5. 提交
git add -A
git commit -m "feat: add sensor history query with pagination"
```

#### 5.1.2 Docker 验证循环（每次功能完成）

```bash
# 1. 启动全栈 Docker 环境
cd server
docker compose --profile dev up -d --build

# 2. 运行数据库集成测试
pytest tests/integration/ -v --run-integration

# 3. 运行 API 测试（针对 Docker 内 API）
pytest tests/test_sensor.py tests/test_disease.py tests/test_command.py -v

# 4. 手动测试（curl）
curl http://localhost:8000/api/v1/health
curl http://localhost:8000/api/v1/sensor/latest

# 5. 查看日志
docker compose logs api-dev --tail=20

# 6. 清理
docker compose --profile dev down
```

#### 5.1.3 VPS 部署循环（每次发布）

```bash
# 1. 构建和本地验证
cd server
docker compose --profile dev up -d --build
pytest tests/ -v --run-integration --run-docker
docker compose --profile dev down

# 2. 同步代码至 VPS
rsync -avz --delete \
    --exclude='.venv' --exclude='__pycache__' --exclude='.git' \
    --exclude='*.pyc' --exclude='.env.*' \
    server/ farmeye@<VPS_IP>:/opt/farmeye/

# 3. SSH 登录 VPS 并部署
ssh farmeye@<VPS_IP>
cd /opt/farmeye

# 使用主文件 + 生产覆写文件合并启动
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    --compatibility \
    up -d --build

# 4. 验证
curl http://localhost:8000/api/v1/health
```

### 5.2 热重载开发配置

开发模式下通过 Docker `dev` stage 实现热重载：

```yaml
# docker-compose.yml 中 dev profile 的关键配置
api-dev:
  build:
    target: dev                # Dockerfile 中的 dev stage
  volumes:
    - ./app:/app/app           # 代码挂载，本地修改即时反映
  command: >
    uvicorn app.main:app
    --host 0.0.0.0 --port 8000
    --reload --reload-dir /app/app  # 仅监控 app/ 目录变化
  profiles: ["dev"]            # 仅通过 --profile dev 启动
```

启动命令：

```bash
# 启动开发环境（热重载）
cd server
docker compose --profile dev up -d --build

# 修改代码后，uvicorn --reload 会自动检测并重启
# 无需手动重启容器

# 查看热重载日志
docker compose logs -f api-dev
```

### 5.3 环境变量管理

#### 5.3.1 环境变量文件清单

| 文件 | 用途 | 提交至 Git | 包含密钥 |
|------|------|:----------:|:--------:|
| `.env.dev.example` | 开发环境模板（示例值） | 是 | 否 |
| `.env.prod.example` | 生产环境模板（示例值） | 是 | 否 |
| `.env.dev` | 实际开发环境变量 | 否（已 .gitignore） | 可能 |
| `.env.prod` | 实际生产环境变量 | 否（已 .gitignore） | 是 |
| `.env.test` | 测试环境变量 | 否（已 .gitignore） | 否 |

#### 5.3.2 .env.dev.example

```ini
DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db
DB_USER=farmeye
DB_NAME=farmeye_db
IOTDA_ENDPOINT=https://iotda.cn-north-4.myhuaweicloud.com
IOTDA_PROJECT_ID=your_project_id
ADVISORY_WINDOW_MINUTES=60
DATA_RETENTION_SENSOR_DAYS=30
DATA_RETENTION_CONTROL_DAYS=90
IMAGE_STORAGE_PATH=./images
API_KEYS=farmeye_dev_key_001
LOG_LEVEL=DEBUG
```

#### 5.3.3 .env.prod.example

```ini
DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@db:5432/farmeye_db
DB_USER=farmeye
DB_NAME=farmeye_db
IOTDA_ENDPOINT=https://iotda.cn-north-4.myhuaweicloud.com
IOTDA_PROJECT_ID=your_actual_project_id
ADVISORY_WINDOW_MINUTES=60
DATA_RETENTION_SENSOR_DAYS=30
DATA_RETENTION_CONTROL_DAYS=90
IMAGE_STORAGE_PATH=/app/images
API_KEYS=farmeye_prod_key_001,farmeye_prod_key_002
LOG_LEVEL=INFO
#HOST=0.0.0.0     # 预留字段，当前由 Dockerfile CMD 硬编码
#PORT=8000         # 预留字段
#WORKERS=1         # 预留字段
```

#### 5.3.4 .gitignore 配置

```
# 环境变量文件（含敏感信息）
.env
.env.*
!.env.*.example

# Python
__pycache__/
*.py[cod]
.venv/
*.egg-info/

# IDE
.vscode/
.idea/

# Docker
.docker/

# 日志
logs/*.log

# 图片上传
images/

# 备份
backups/

# 操作系统
.DS_Store
Thumbs.db
```

### 5.4 数据迁移策略

使用 Alembic 管理数据库 Schema 迁移。

#### 5.4.1 Alembic 初始化

```bash
cd server
alembic init alembic
```

#### 5.4.2 server/alembic.ini

```ini
[alembic]
script_location = alembic
# sqlalchemy.url 不在此硬编码，由 alembic/env.py 从环境变量 DATABASE_URL 动态读取
# 以支持本地开发（localhost:5432）、Docker 容器内（db:5432）、测试环境的不同地址

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

#### 5.4.3 迁移工作流

```bash
# 1. 自动生成迁移脚本（基于 models/ 与数据库的差异）
cd server
alembic revision --autogenerate -m "add sensor_daily_aggregation table"

# 2. 审查生成的迁移脚本（必须！自动生成不保证正确）
# 编辑 alembic/versions/xxxx_add_sensor_daily_aggregation.py

# 3. 应用迁移
alembic upgrade head

# 4. 回滚
alembic downgrade -1

# 5. 查看历史
alembic history

# 6. 查看当前版本
alembic current
```

#### 5.4.4 迁移与 Docker 集成

```yaml
# Dockerfile prod stage 启动脚本改为 entrypoint.sh
# 启动时自动执行迁移
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
```

```bash
#!/bin/bash
# server/entrypoint.sh — 容器启动入口
set -e

echo "[FarmEye] 执行数据库迁移..."

# 步骤1：检测 Alembic 版本状态，判断是否为首次部署
# alembic current 输出模式：
#   - 首次部署（未 stamp）：alembic_version 表不存在，输出错误或空
#   - 已 stamp：输出当前版本号（如 abc123def456 (head)）
CURRENT_OUTPUT=$(alembic current 2>&1 || true)

# 如果输出包含 12 位十六进制版本号，说明已有迁移记录
if echo "$CURRENT_OUTPUT" | grep -qE '^[a-f0-9]{12}'; then
    echo "[FarmEye] 检测到已有迁移版本记录"
    STRICT_MIGRATION=true
else
    echo "[FarmEye] 未检测到迁移版本记录（首次部署或无版本信息）"
    STRICT_MIGRATION=false
fi

# 步骤2：执行迁移；根据 STRICT_MIGRATION 决定失败行为
if alembic upgrade head 2>&1; then
    echo "[FarmEye] 数据库迁移成功"
else
    if [ "$STRICT_MIGRATION" = "true" ]; then
        # 非首次部署但迁移失败 — 真实错误，阻塞启动
        echo "[FarmEye] 错误: 数据库迁移失败（已有版本记录但升级出错）" >&2
        echo "[FarmEye] 请检查迁移脚本或数据库连接，修复后重新启动容器。" >&2
        echo "[FarmEye] 常见原因：迁移脚本 SQL 语法错误、数据库连接中断、迁移版本历史冲突" >&2
        exit 1
    else
        echo "[FarmEye] 警告: 数据库迁移未完成 - 可能是首次部署，"
        echo "        init SQL 已完成基线初始化。"
        echo "        请部署后执行: alembic stamp head"
        echo "        详情参见 §5.4.6"
    fi
fi

echo "[FarmEye] 启动 API 服务..."
exec "$@"
```

#### 5.4.5 server/alembic/env.py — 从环境变量读取数据库连接

`alembic.ini` 中的 `sqlalchemy.url` 不再硬编码，改为在 `env.py` 中从 `DATABASE_URL` 环境变量动态读取。

```python
"""
FarmEye Guard — Alembic 环境配置

数据库连接地址从 DATABASE_URL 环境变量读取，
支持本地开发（localhost:5432）、Docker 容器（db:5432）、
测试环境等不同部署场景。
"""
from logging.config import fileConfig
from alembic import context
import os

config = context.config

# 从环境变量覆盖数据库连接地址
database_url = os.getenv("DATABASE_URL")
if database_url:
    config.set_main_option("sqlalchemy.url", database_url)

# 日志配置
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# 元数据导入（根据实际 models 位置调整）
# from app.db.base import Base
# target_metadata = Base.metadata
target_metadata = None

def run_migrations_offline() -> None:
    """离线模式迁移"""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    """在线模式迁移"""
    from sqlalchemy import create_engine
    connectable = create_engine(config.get_main_option("sqlalchemy.url"))

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

> **重要说明**：`DATABASE_URL` 环境变量由 `docker-compose.yml` 中 `api` 服务的 `env_file: .env.prod` 注入。entrypoint.sh 执行 `alembic upgrade head` 时，`env.py` 自动读取该变量，使用正确的 `db:5432` 地址连接数据库。本地开发时，开发者在 shell 中 export DATABASE_URL 或通过 `.env.dev` 文件设置即可。`alembic.ini` 中不保留任何硬编码的连接地址。

#### 5.4.6 初始基准迁移 — init SQL 与 Alembic 的调和策略

**职责边界**：

- **init SQL 脚本**（`init/01_create_tables.sql`）：仅用于**首次部署时的数据库初始化基线**。由 PostgreSQL 16 镜像的 `/docker-entrypoint-initdb.d/` 机制自动执行，仅在数据库为空（首次创建）时触发。init SQL 负责 DDL 建表和种子数据，不参与后续 Schema 变更管理。
- **Alembic 迁移**：用于**增量 Schema 变更管理**。首次部署后，所有字段新增、表结构修改等操作均通过 `alembic revision --autogenerate` 生成迁移脚本并受版本控制。

**首次部署后的调和策略（方案 A — 推荐）**：

首次部署时，PostgreSQL 容器启动后自动通过 init SQL 脚本创建了完整的 Schema 结构。此时 Alembic 尚未记录任何迁移版本。调和策略如下：

1. **首次部署完成后**，立即执行 `alembic stamp head`（若项目中已有一个初始迁移脚本，其内容与 init SQL 产出的 Schema 一致）：
   ```bash
   cd server
   DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db \
   alembic stamp head
   ```
2. 该命令将当前数据库 Schema 状态标记为已处于最新迁移版本，**不执行任何 DDL 变更**。
3. 此后所有 Schema 变更均通过正常迁移流程（`alembic revision --autogenerate` → `alembic upgrade head`）。

**如果尚无初始迁移脚本**，则执行：
```bash
alembic revision --autogenerate -m "initial schema baseline"
# 审查生成的脚本，确认其内容与 init SQL 一致（CREATE TABLE IF NOT EXISTS）
alembic stamp head
```

> **方案 B（备选）**：生成初始 Alembic 迁移脚本（`alembic revision --autogenerate`），编辑其中的 `upgrade()` 函数使用 `CREATE TABLE IF NOT EXISTS` 以及 `op.execute("... ON CONFLICT DO NOTHING")` 以避免与 init SQL 冲突。此方案更复杂，仅建议在需要完整迁移历史追溯时采用。

#### 5.4.7 entrypoint.sh — 首次运行边界处理

entrypoint.sh 已在 §5.4.4 中定义为最终的改进版本。其迁移失败处理逻辑实现了两阶段判断：

**阶段 1 — 检测版本状态**：

在尝试迁移前，先执行 `alembic current` 检查 `alembic_version` 表是否存在并包含版本号。如果输出版本号，设 `STRICT_MIGRATION=true`（非首次部署）；否则设 `STRICT_MIGRATION=false`（首次部署或尚无版本信息）。

**阶段 2 — 根据状态决定失败行为**：

1. **非首次部署 + 迁移失败**（`STRICT_MIGRATION=true`）：**阻塞容器启动**，输出详细错误日志并退出（`exit 1`）。此时需要运维排查迁移脚本的 SQL 语法、数据库连接或版本历史冲突等问题（常见排查方向已在错误信息中列出）。
2. **首次部署 + 迁移失败**（`STRICT_MIGRATION=false`）：**不退出容器启动流程**，输出警告信息，提示需要部署后执行 `alembic stamp head`。这是预期行为——init SQL 已通过 PostgreSQL 的 `/docker-entrypoint-initdb.d/` 机制完成了建表，数据库 Schema 处于最新状态但 Alembic 无版本记录。
3. **迁移成功**：无论哪种模式，均输出成功信息并正常启动。

> **说明**：此设计确保了首次部署时的开箱即用体验，同时在生产运维中捕获真实迁移错误。在部署完成后应参考 §5.4.6 的调和策略执行 `alembic stamp head` 以完成版本对齐。

---

## 6. 附录

### 6.1 完整文件清单

```
server/
├── Dockerfile                    # 多阶段构建（base/dev/prod）
├── docker-compose.yml            # 主编排文件（API + DB）
├── docker-compose.prod.yml       # 生产覆写（Nginx + 加严配置）
├── .env.dev.example              # 开发环境变量模板
├── .env.prod.example             # 生产环境变量模板
├── .gitignore                    # Git 忽略规则
├── .dockerignore                 # Docker 构建上下文排除规则
│
├── requirements.txt              # 生产依赖
├── requirements-dev.txt          # 开发依赖
├── entrypoint.sh                 # 容器入口（迁移 + 启动）
├── alembic.ini                   # 迁移配置
├── alembic/                      # 迁移脚本目录
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
│
├── app/
│   ├── main.py                   # FastAPI 入口
│   ├── config.py                 # 配置管理
│   ├── api/
│   │   ├── router.py             # 路由注册
│   │   ├── deps.py               # 依赖注入
│   │   └── v1/
│   │       ├── iotda.py          # IoTDA Webhook
│   │       ├── sensor.py         # 传感器查询
│   │       ├── disease.py        # 病虫害接口
│   │       ├── device.py         # 设备列表
│   │       ├── command.py        # 控制接口
│   │       ├── advisory.py       # 防治建议
│   │       └── image.py          # 图片管理
│   ├── models/                   # SQLAlchemy 模型
│   ├── schemas/                  # Pydantic Schema
│   ├── services/                 # 业务逻辑
│   │   ├── sensor_service.py
│   │   ├── disease_service.py
│   │   ├── command_service.py
│   │   ├── advisory_service.py
│   │   ├── iotda_client.py
│   │   └── data_retention.py
│   ├── core/
│   │   └── logging_config.py     # 日志配置
│   └── db/
│       ├── session.py
│       └── base.py
│
├── tests/
│   ├── conftest.py               # 全局 fixture + pytest 钩子
│   ├── test_health.py
│   ├── test_iotda_webhook.py
│   ├── test_sensor.py
│   ├── test_disease.py
│   ├── test_command.py
│   ├── test_advisory.py
│   ├── test_image.py
│   ├── test_device.py
│   ├── integration/
│   │   ├── test_db_ddl.py
│   │   ├── test_db_crud.py
│   │   └── test_db_retention.py
│   ├── docker/
│   │   ├── test_container_start.py
│   │   ├── test_healthcheck.py
│   │   └── test_network.py
│   └── e2e/
│       └── test_e2e.py
│
├── init/
│   ├── 01_create_tables.sql      # DDL 建表
│   └── 02_seed_data.sql          # 种子数据
│
├── nginx/
│   └── farmeye.conf              # Nginx 反向代理配置
│
└── deploy/
    └── scripts/
        ├── start.sh              # 生产启动（合并覆写文件）
        ├── stop.sh               # 生产停止
        ├── restart.sh            # 生产重启
        └── backup.sh             # 数据备份
```

### 6.2 快速部署命令

#### VPS 首次部署（汇总）

```bash
# === 1. VPS 初始化 ===
ssh root@<VPS_IP>
# 创建用户、配置防火墙、安装 Docker（参见 §3.1）

# === 2. 部署应用 ===
ssh farmeye@<VPS_IP>
mkdir -p /opt/farmeye/{logs,backups,images,nginx,init}

# === 3. 在本地构建并推送（或 VPS 上直接构建） ===
# 本地：
cd server
rsync -avz --delete \
    --exclude='.venv' --exclude='__pycache__' --exclude='.git' \
    --exclude='*.pyc' --exclude='.env.*' \
    ./ farmeye@<VPS_IP>:/opt/farmeye/

# === 4. SSH 登录部署 ===
ssh farmeye@<VPS_IP>
cd /opt/farmeye
cp .env.prod.example .env.prod
# 编辑 .env.prod 填入真实值
# vi .env.prod

# 合并主文件 + 生产覆写文件启动
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    --compatibility \
    up -d --build

# === 5. 验证 ===
curl http://localhost:8000/api/v1/health
curl http://localhost:8000/api/v1/sensor/latest
```