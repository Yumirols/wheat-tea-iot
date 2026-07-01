# 任务指令（v8）

## 动作
NEW

## 任务描述

在 `server/` 目录下创建完整的 Docker 容器化配置，包括 4 个文件：

### 1. server/Dockerfile — 多阶段构建

基于 `ubuntu:25.04` 镜像的三阶段构建（base / dev / prod），与 VPS 系统保持一致。

**base 阶段**：
- 设置 `DEBIAN_FRONTEND=noninteractive`、`PYTHONUNBUFFERED=1`、`PYTHONDONTWRITEBYTECODE=1`、`PIP_NO_CACHE_DIR=1`、`PIP_DISABLE_PIP_VERSION_CHECK=1`
- 安装编译依赖：`python3`、`python3-venv`、`python3-pip`、`curl`、`ca-certificates`、`build-essential`、`python3-dev`、`libpq-dev`
- 清理 `rm -rf /var/lib/apt/lists/*`
- 创建并激活 venv：`python3 -m venv /opt/venv`，`ENV PATH="/opt/venv/bin:$PATH"`
- `WORKDIR /app`
- `COPY requirements.txt .` + `RUN pip install -r requirements.txt`
- 标签：`maintainer="FarmEye Guard Team"`、`version="v1.0.0"`

**dev 阶段**（`FROM base AS dev`）：
- 安装调试工具：`netcat-openbsd`、`vim-tiny`
- `COPY requirements-dev.txt .` + `RUN pip install -r requirements-dev.txt`
- `COPY . .`
- `EXPOSE 8000`
- `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload", "--reload-dir", "/app"]`
- `HEALTHCHECK --interval=15s --timeout=5s --retries=3 --start-period=10s CMD curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"' || exit 1`

**prod 阶段**（`FROM base AS prod`）：
- `COPY . .`
- `COPY entrypoint.sh .` + `RUN chmod +x entrypoint.sh`
- `EXPOSE 8000`
- `ENTRYPOINT ["./entrypoint.sh"]`
- `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--limit-max-requests", "10000"]`
- `HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s CMD curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"' || exit 1`

### 2. server/docker-compose.yml — 主编排文件

version: "3.9"，包含以下服务：

**api 服务**（production profile）：
- `build: { context: ., target: prod }`
- `container_name: farmeye-api`
- `ports: ["127.0.0.1:8000:8000"]`（仅监听 localhost，由 Nginx 转发）
- `env_file: [.env.prod]`
- `volumes: [images_data:/app/images, ./logs:/app/logs]`
- `healthcheck: { interval: 30s, timeout: 10s, retries: 3, start_period: 30s }` — 使用与 Dockerfile 相同的 curl 命令
- `depends_on: { db: { condition: service_healthy } }`
- `restart: unless-stopped`
- `profiles: [production]`
- `networks: [farmeye-net]`
- `deploy.resources: { limits: { memory: 256M }, reservations: { memory: 128M } }`

**db 服务**：
- `image: postgres:16-alpine`
- `container_name: farmeye-db`
- `ports: ["127.0.0.1:5432:5432"]`
- `environment: POSTGRES_USER=farmeye, POSTGRES_PASSWORD=farmeye_pwd, POSTGRES_DB=farmeye_db`
- `volumes: [db_data:/var/lib/postgresql/data, ./init/:/docker-entrypoint-initdb.d/]`
- `healthcheck: { test: ["CMD-SHELL", "pg_isready -U farmeye -d farmeye_db || exit 1"], interval: 10s, timeout: 5s, retries: 5, start_period: 60s }`
- `restart: unless-stopped`
- `networks: [farmeye-net]`
- `deploy.resources: { limits: { memory: 256M }, reservations: { memory: 128M } }`
- `command: -c shared_buffers=64MB -c effective_cache_size=256MB -c work_mem=4MB -c maintenance_work_mem=16MB -c max_connections=10`

**api-dev 服务**（dev profile）：
- `build: { context: ., target: dev }`
- `container_name: farmeye-api-dev`
- `ports: ["8000:8000"]`（直接暴露端口）
- `env_file: [.env.dev]`
- `volumes: [./app:/app/app, images_data:/app/images, ./logs:/app/logs, ./tests:/app/tests]`
- `healthcheck: { disable: true }`
- `depends_on: { db: { condition: service_healthy } }`
- `restart: unless-stopped`
- `profiles: [dev]`
- `networks: [farmeye-net]`
- `deploy.resources: { limits: { memory: 512M }, reservations: { memory: 256M } }`

**networks**：
- `farmeye-net: { driver: bridge }`

**volumes**：
- `db_data:`（PostgreSQL 数据持久化）
- `images_data:`（上传图片持久化）

### 3. server/docker-compose.prod.yml — 生产环境覆写

version: "3.9"，覆盖以下内容：

**api 覆写**：
- `restart: always`
- `logging: { driver: "json-file", options: { max-size: "10m", max-file: "3" } }`
- `environment: { LOG_LEVEL: INFO }`
- `deploy.resources: { limits: { memory: 256M }, reservations: { memory: 128M } }`

**db 覆写**：
- `restart: always`
- `logging: { driver: "json-file", options: { max-size: "10m", max-file: "3" } }`
- `deploy.resources: { limits: { memory: 384M }, reservations: { memory: 256M } }`

**nginx 服务**（生产可选）：
- `image: nginx:1.27-alpine`
- `container_name: farmeye-nginx`
- `ports: ["80:80", "443:443"]`
- `volumes: [./nginx/farmeye.conf:/etc/nginx/conf.d/farmeye.conf:ro, ./nginx/ssl:/etc/nginx/ssl:ro, images_data:/usr/share/nginx/images:ro]`
- `depends_on: { api: { condition: service_healthy } }`
- `restart: always`
- `networks: [farmeye-net]`
- `deploy.resources: { limits: { memory: 64M }, reservations: { memory: 32M } }`
- `logging: { driver: "json-file", options: { max-size: "10m", max-file: "3" } }`

### 4. server/entrypoint.sh — 容器入口脚本

```bash
#!/bin/bash
set -e

echo "[FarmEye] 执行数据库迁移..."

# 检测 Alembic 版本状态
CURRENT_OUTPUT=$(alembic current 2>&1 || true)

if echo "$CURRENT_OUTPUT" | grep -qE '^[a-f0-9]{12}'; then
    echo "[FarmEye] 检测到已有迁移版本记录"
    STRICT_MIGRATION=true
else
    echo "[FarmEye] 未检测到迁移版本记录（首次部署或无版本信息）"
    STRICT_MIGRATION=false
fi

if alembic upgrade head 2>&1; then
    echo "[FarmEye] 数据库迁移成功"
else
    if [ "$STRICT_MIGRATION" = "true" ]; then
        echo "[FarmEye] 错误: 数据库迁移失败（已有版本记录但升级出错）" >&2
        echo "[FarmEye] 请检查迁移脚本或数据库连接，修复后重新启动容器。" >&2
        echo "[FarmEye] 常见原因：迁移脚本 SQL 语法错误、数据库连接中断、迁移版本历史冲突" >&2
        exit 1
    else
        echo "[FarmEye] 警告: 数据库迁移未完成 - 可能是首次部署，"
        echo "        init SQL 已完成基线初始化。"
        echo "        请部署后执行: alembic stamp head"
    fi
fi

echo "[FarmEye] 启动 API 服务..."
exec "$@"
```

注意：Docker 健康检查使用的 `curl` 命令已内置在 base 镜像中（通过 `apt-get install curl`）。健康检查命令在 Dockerfile 中定义（dev 和 prod 阶段各有一个 HEALTHCHECK 指令），并在 docker-compose.yml 的 api 服务中覆写为相同的检查。健康检查端点 `GET /api/v1/health` 返回的 JSON 中包含 `"status":"healthy"` 字符串，grep 可正确匹配。

## 预期产出

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | server/Dockerfile | 三阶段多阶段构建（base/dev/prod） |
| 新建 | server/docker-compose.yml | 主编排（api + db + api-dev，双 profile） |
| 新建 | server/docker-compose.prod.yml | 生产覆写（nginx + 日志 + 重启 + 资源限制） |
| 新建 | server/entrypoint.sh | 容器入口（迁移检测 + alembic upgrade + 启动） |

## 选择理由

所有 API/Service 代码已完成。Docker 容器化配置是独立的基础设施层，不依赖其他待办任务（测试、Nginx 配置、部署脚本），可独立实现和验证。完成后即可通过 `docker compose build` 构建镜像并通过 `docker compose up` 启动完整的 API + DB 服务栈，验证整个应用在容器化环境中的运行状态。

## 任务上下文

### 设计依据

参考 `docs/2_vps-deployment.md`：
- §1.4 Dockerfile 设计（三阶段构建，完整配置参数）
- §1.4.1 .dockerignore 配置（已存在，无需新建）
- §1.5 docker-compose.yml 设计（双 profile、双服务、健康检查依赖链）
- §1.5.2 docker-compose.prod.yml（生产覆写：Nginx、日志、重启策略）
- §1.6 生产/开发配置分离策略表
- §1.7 健康检查配置（API + DB 健康检查参数）
- §5.4.4 entrypoint.sh（迁移逻辑，两阶段失败处理）
- §3.5 容器资源限制表（1GB RAM 约束下的资源分配）

### 已有产出

server/ 目录下已有完整产出：
- `requirements.txt` / `requirements-dev.txt`（依赖文件）
- `.env.dev.example` / `.env.prod.example`（环境变量模板，注意 Docker compose 使用 `.env.prod` 和 `.env.dev` 文件名，example 文件需在部署时复制）
- `.dockerignore`（Docker 构建上下文排除规则，已包含 __pycache__、.env*、.git 等）
- `app/`（完整 FastAPI 应用代码，含 main.py 健康检查端点）
- `init/01_create_tables.sql` / `02_seed_data.sql`（DB 初始化脚本，通过 `/docker-entrypoint-initdb.d/` 挂载）
- `alembic/` + `alembic.ini`（迁移框架，`env.py` 从 DATABASE_URL 环境变量读取连接地址）

### 健康检查端点格式

`GET /api/v1/health` 返回格式（部分）：
```json
{"code": 0, "message": "success", "data": {"status": "healthy", ...}}
```
因此 `grep -q '"status":"healthy"'` 可正确匹配健康状态。
