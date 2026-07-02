# 第一部分：本地后端开发、容器化与验证详细方案

本方案对应系统部署规划的第一部分（包含阶段一至阶段五），聚焦于在本地开发环境完成 FastAPI 后端开发、金仓/PostgreSQL 数据库初始化、Docker 容器化多阶段配置以及完整的自动化测试验证。

---

## 阶段一：本地开发环境与依赖搭建

本阶段的目标是建立符合生产标准的本地 Python 开发环境，定义清晰的生产与开发依赖边界。

### 1.1 Python 3.13 虚拟环境配置
项目推荐使用 Python 3.13 版本进行开发，以确保与生产环境（Ubuntu 25.04）的基础库完全一致。

```bash
# 1. 创建虚拟环境
python3 -m venv .venv

# 2. 激活虚拟环境
# Linux/macOS:
source .venv/bin/activate
# Windows PowerShell:
.venv\Scripts\Activate.ps1

# 3. 升级基础包管理器
pip install --upgrade pip
```

### 1.2 依赖管理划分
将依赖关系严格划分为生产运行所必需的依赖和开发/测试专用的依赖：

* **生产依赖** ([requirements.txt](file:///E:/dev/wheat-tea-iot/server/requirements.txt))：
  * **FastAPI 核心**：`fastapi`, `uvicorn[standard]`, `pydantic`, `pydantic-settings`
  * **数据库访问**：`psycopg2` (源码编译版), `sqlalchemy`, `alembic`
  * **HTTP 客户端**：`httpx` (用于调用华为云 IoTDA API)
  * **图片及其他**：`Pillow`, `python-multipart`, `openpyxl`, `apscheduler`
* **开发依赖** ([requirements-dev.txt](file:///E:/dev/wheat-tea-iot/server/requirements-dev.txt))：
  * **测试框架**：`pytest`, `pytest-asyncio`
  * **代码质量**：`ruff`, `mypy`
  * **热重载辅助**：`watchfiles`

> **本地开发替代说明**：在 Windows 本地开发时，为避免编译 `psycopg2` 所需的 PostgreSQL 客户端头文件缺失，可临时使用 `pip install psycopg2-binary` 进行本地运行，但不得将其写入生产 `requirements.txt`。

---

## 阶段二：数据库初始化与 Alembic 迁移机制建立

本阶段的目标是建立数据库的版本管理控制，处理好首次部署与增量 Schema 变更的平滑过渡。

### 2.1 初始 DDL 与种子数据
* **基线表结构** ([01_create_tables.sql](file:///E:/dev/wheat-tea-iot/server/init/01_create_tables.sql))：
  定义 `sensor_snapshot`（环境快照）、`disease_records`（识别记录）、`control_logs`（控制日志）、`devices`（设备管理）和 `sensor_daily_aggregation`（日聚合）五个核心表。
* **种子数据** ([02_seed_data.sql](file:///E:/dev/wheat-tea-iot/server/init/02_seed_data.sql))：
  预置开发测试设备 `farmeye_guard_ws63` 的基础信息。

### 2.2 Alembic 迁移框架配置
1. **初始化迁移仓库**：
   ```bash
   cd server
   alembic init alembic
   ```
2. **连接地址动态获取**：
   修改 `alembic/env.py`，屏蔽 `alembic.ini` 中的硬编码 `sqlalchemy.url`，改为从系统环境变量中动态读取 `DATABASE_URL`，以适配本地开发、Docker 内网及生产环境的不同连接串。
3. **初始基准 Stamp**：
   首次部署通过 `/docker-entrypoint-initdb.d/` 的 SQL 脚本完成建表后，执行：
   ```bash
   alembic stamp head
   ```
   将其直接对齐至最新迁移版本，避免迁移历史重复建表导致报错。

---

## 阶段三：FastAPI 接口与核心逻辑编写

本阶段完成所有接口开发和后台调度任务编写。

### 3.1 核心 REST API 编写
* **Webhook 接收接口** (`/api/v1/iotda/`)：
  * `properties/report`：解析上报字段，写入 `sensor_snapshot`，更新设备心跳。
  * `ai/report`：解析 AI 识别结果，写入 `disease_records`。
  * `cmd/response`：更新 `control_logs` 执行反馈。
* **数据查询与导出接口** (`/api/v1/sensor/` / `/api/v1/disease/` / `/api/v1/export/`)：
  * 查询最新快照、历史曲线（支持分页）、日聚合记录；支持导出历史数据为 CSV/Excel 格式。
* **命令下发接口** (`/api/v1/command`)：
  * 校验设备在线状态，预生成 `command_id` 并写入控制日志，调用 `IotdaClient` API。

### 3.2 联动分析与决策引擎 (`advisory_service.py`)
当收到 AI 报告时，自动检索设备近 1 小时的环境快照进行关联匹配。若检测到重度病害（`severity_code == 3`）且满足决策矩阵中的环境条件，自动下发开启喷淋命令。

### 3.3 定时任务与在线状态判定
* **设备状态监测**：使用内存 Dict 单例缓存设备最新上报时间，后台异步 Loop 每 30 秒轮询一次，超时未上报的自动标记数据库 `devices.online = False`。
* **数据保留清理**：每日凌晨清理 30 天前的传感器明细数据，并转存为 `sensor_daily_aggregation` 日聚合指标。

---

## 阶段四：Docker 容器化与多阶段构建

本阶段利用容器技术将应用及环境打包，消除环境异构风险。

### 4.1 多阶段 Dockerfile 结构
使用官方 `ubuntu:25.04` 镜像（与 VPS 系统保持一致），分为三个阶段：
* **`base` 阶段**：安装 Python 3.13 依赖及 PostgreSQL 编译依赖，创建虚拟环境并下载生产依赖包。
* **`dev` 阶段**：挂载本地源码，安装测试和 Ruff 工具，开启 `--reload` 热重载以便于本地调试。
* **`prod` 阶段**：复制纯净代码，添加 [entrypoint.sh](file:///E:/dev/wheat-tea-iot/server/entrypoint.sh)，容器启动时自动执行 Alembic 数据库迁移。

### 4.2 本地容器编排 (`docker-compose.yml`)
在本地调试时，利用 `postgres:16-alpine` 替代金仓数据库。
* 对 PostgreSQL 进行 **1GB RAM 资源优化**，降低共享缓冲区限制 (`shared_buffers=64MB`)。
* 设置 `depends_on.db.condition: service_healthy`，确保 API 容器仅在数据库健康检查通过后才开始启动。

---

## 阶段五：本地自动化测试与验证

在代码部署到 VPS 前，必须在本地通过三层测试网，保证质量。

```
                    ┌───────────────────────────┐
                    │       1. 单元测试         │ < pytest
                    │  (Mock 数据, 快速验证, <30s)│
                    └─────────────┬─────────────┘
                                  ▼
                    ┌───────────────────────────┐
                    │      2. 数据库集成测试     │ < docker compose
                    │ (容器化 DB, 验证 CRUD & DDL) │
                    └─────────────┬─────────────┘
                                  ▼
                    ┌───────────────────────────┐
                    │      3. 容器端到端联调     │ < integration_run.py
                    │ (黑盒模拟 Webhook 与命令下发) │
                    └───────────────────────────┘
```

1. **单元测试** (`pytest tests/`)：
   忽略集成测试与 docker 测试，仅使用 TestClient 和 Mock 对 API 逻辑、Advisory 联动规则进行纯静态验证。
2. **集成测试** (`pytest tests/integration/`)：
   启动本地 Compose 的 DB 容器，执行真实 SQL 建表、写入与数据清理任务，验证 SQLAlchemy ORM 与 PostgreSQL 的兼容性。
3. **集成联调脚本** (`tests/integration_run.py`)：
   启动完整容器组，通过 HTTP 请求向 Webhook 推送环境数据，等待 2 秒后调用最新传感器接口，验证数据持久化成功；下发手动命令并模拟 IoTDA 的应答推送，检验控制日志状态是否正确闭环。
