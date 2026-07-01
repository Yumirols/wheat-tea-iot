# 任务：实现本地开发、容器化与验证

## 任务目标

根据 `docs/2_vps-deployment.md` 中第 1、2、4、5 章的设计方案，以及 `docs/local-development.md` 的开发规划，在空的 `server/` 目录中实现完整的本地开发环境、容器化配置与自动化测试验证体系。

## 约束条件

- 所有代码/配置文件位于 `server/` 目录下
- server 目录当前为空，需从零创建
- 使用 Python 3.13+、FastAPI、PostgreSQL 16
- 生产环境目标：Ubuntu 25.04 / 1 vCPU / 1 GB RAM / 35 GB Disk
- 开发环境兼容 Windows（PowerShell）和 Linux

## 涵盖范围

### 1. 本地开发环境与依赖
- `server/requirements.txt`：生产依赖（FastAPI、SQLAlchemy、Alembic、psycopg2、httpx、Pillow、openpyxl、APScheduler）
- `server/requirements-dev.txt`：开发依赖（pytest、pytest-asyncio、ruff、mypy、watchfiles）
- `server/.env.dev.example`：开发环境变量模板
- `server/.env.prod.example`：生产环境变量模板
- `server/.gitignore`：Git 忽略规则
- `server/.dockerignore`：Docker 构建上下文排除规则

### 2. 数据库初始化与迁移
- `server/init/01_create_tables.sql`：DDL 建表（sensor_snapshot、disease_records、control_logs、devices、sensor_daily_aggregation）
- `server/init/02_seed_data.sql`：种子数据
- `server/alembic.ini` + `server/alembic/`：Alembic 迁移框架
- `server/alembic/env.py`：从环境变量动态读取 DATABASE_URL

### 3. FastAPI 应用核心
- `server/app/main.py`：FastAPI 应用入口
- `server/app/config.py`：Pydantic Settings 配置管理
- `server/app/db/session.py`：SQLAlchemy 数据库会话
- `server/app/db/base.py`：SQLAlchemy Base 声明
- `server/app/models/`：SQLAlchemy ORM 模型（对应 5 张表）
- `server/app/schemas/`：Pydantic 请求/响应 Schema
- `server/app/api/router.py`：路由注册
- `server/app/api/deps.py`：依赖注入（API Key 认证等）
- `server/app/api/v1/`：REST API 端点
  - `iotda.py`：IoTDA Webhook（properties/report、ai/report、cmd/response）
  - `sensor.py`：传感器数据查询（latest、history、daily）
  - `disease.py`：病虫害记录查询与统计
  - `device.py`：设备列表与状态
  - `command.py`：手动控制命令下发与日志
  - `advisory.py`：防治建议
  - `image.py`：图片上传与管理
- `server/app/services/`：业务逻辑层
  - `sensor_service.py`
  - `disease_service.py`
  - `command_service.py`
  - `advisory_service.py`（含联动分析与决策引擎）
  - `iotda_client.py`（华为 IoTDA HTTP 客户端）
  - `data_retention.py`（数据保留定时任务）
- `server/app/core/logging_config.py`：日志配置

### 4. Docker 容器化
- `server/Dockerfile`：多阶段构建（base/dev/prod）
- `server/docker-compose.yml`：主编排文件（API + DB）
- `server/docker-compose.prod.yml`：生产环境覆写
- `server/entrypoint.sh`：容器入口脚本（迁移 + 启动）

### 5. 自动化测试
- `server/tests/conftest.py`：全局 fixture、pytest 钩子、示例 payload
- `server/tests/test_health.py`：健康检查测试
- `server/tests/test_iotda_webhook.py`：Webhook 端点测试
- `server/tests/test_sensor.py`：传感器查询测试
- `server/tests/test_disease.py`：病虫害接口测试
- `server/tests/test_command.py`：控制接口测试
- `server/tests/test_advisory.py`：防治建议测试
- `server/tests/test_image.py`：图片管理测试
- `server/tests/test_device.py`：设备列表测试
- `server/tests/integration/`：数据库集成测试
- `server/tests/docker/`：Docker 容器测试
- `server/tests/e2e/`：端到端测试

### 6. 开发工作流与部署辅助
- `server/nginx/farmeye.conf`：Nginx 反向代理配置
- `server/deploy/scripts/start.sh`、`stop.sh`、`restart.sh`、`backup.sh`

## 设计参考文档

- `docs/2_vps-deployment.md`：完整设计与配置方案
- `docs/local-development.md`：开发阶段规划
- `docs/0_system_specification.md`：系统规格
- `docs/1_system_architecture.md`：系统架构

注意：每次 PDC 轮次实现一个子任务，由 Planner 根据实际情况拆分和安排优先级。
