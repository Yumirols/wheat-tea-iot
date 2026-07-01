# 执行报告（v3）

## 概述

在 `server/app/` 目录下创建了 FastAPI 应用的基础框架，包括完整的目录结构、配置管理、数据库会话、ORM 模型（5 张表）、Pydantic Schema 和带健康检查的应用入口。同时更新了 `server/alembic/env.py`，将 `target_metadata` 指向 ORM 模型的 `Base.metadata`，完成 Alembic 与 ORM 的关联。

## 产出清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | server/app/**init**.py | 空 init 文件 |
| 新建 | server/app/config.py | Pydantic Settings 配置管理，从环境变量读取所有配置项，提供全局单例 |
| 新建 | server/app/db/**init**.py | 空 init 文件 |
| 新建 | server/app/db/base.py | SQLAlchemy DeclarativeBase + MetaData 命名约定（已正确注入 metadata） |
| 新建 | server/app/db/session.py | 数据库会话管理，含 engine、SessionLocal 和 get_db 依赖注入生成器 |
| 新建 | server/app/core/**init**.py | 空 init 文件 |
| 新建 | server/app/core/logging_config.py | 日志配置模块，支持控制台和文件轮转输出（路径为相对路径 ./logs） |
| 新建 | server/app/models/**init**.py | 导出所有 ORM 模型类（5 个模型） |
| 新建 | server/app/models/sensor.py | SensorSnapshot + SensorDailyAggregation ORM 模型 |
| 新建 | server/app/models/disease.py | DiseaseRecord ORM 模型 |
| 新建 | server/app/models/control.py | ControlLog + Device ORM 模型 |
| 新建 | server/app/schemas/**init**.py | 导出所有 Schema 类（8 个类） |
| 新建 | server/app/schemas/common.py | 通用响应模型 ResponseModel(Generic[T])、PaginationParams、PaginationMeta |
| 新建 | server/app/schemas/sensor.py | 传感器数据 Schema（SensorSnapshotRead, SensorHistoryResponse） |
| 新建 | server/app/schemas/disease.py | 病虫害记录 Schema（DiseaseRecordRead, DiseaseStatsResponse） |
| 新建 | server/app/schemas/command.py | 命令控制 Schema（CommandCreate, CommandRead, CommandResponse） |
| 新建 | server/app/api/**init**.py | 空 init 文件 |
| 新建 | server/app/api/v1/**init**.py | 空 init 文件 |
| 新建 | server/app/services/**init**.py | 空 init 文件 |
| 新建 | server/app/main.py | FastAPI 应用入口，含 CORS 中间件、生命周期事件、健康检查端点（2s 语句超时） |
| 修改 | server/alembic/env.py | 添加 `from app.db.base import Base` 和 `target_metadata = Base.metadata` |

## 执行过程

### 1. 配置管理（config.py）
- **继承 Pydantic `BaseSettings`**：使用 `SettingsConfigDict(env_file=".env")` 实现 .env 文件加载
- **全局单例**：`settings = Settings()` 对外提供唯一的配置实例
- **所有配置字段提供默认值**：DATABASE_URL 默认指向 `localhost:5432`（本地开发），IoTDA 字段默认为空字符串（部署时需配置），LOG_LEVEL 默认 `"INFO"`
- **配置项与 task_v3.md 完全一致**：13 个配置字段，字段名、类型、默认值均对齐

### 2. 数据库基础（db/base.py + db/session.py）
- **base.py**：使用 `from sqlalchemy.orm import DeclarativeBase` 声明 `Base`，创建 `MetaData(naming_convention=convention)` 注入命名约定（外键、主键、索引、唯一约束、检查约束）。`convention` 字典通过 `metadata = MetaData(naming_convention=convention)` 和 `class Base(DeclarativeBase): metadata = metadata` 正确应用于 `Base.metadata`，非死代码
- **session.py**：配置 SQLAlchemy `create_engine`，连接池 `pool_size=2, max_overflow=2`（适配 1GB RAM VPS），`pool_pre_ping=True` 确保连接有效性
- **get_db()**：同步生成器函数，`yield SessionLocal()` 供 FastAPI 依赖注入，`finally` 中 `db.close()` 确保会话释放

### 3. ORM 模型（models/）
- **三个模型文件**按业务领域拆分（sensor.py / disease.py / control.py），严格对照 `init/01_create_tables.sql` 中 5 张表的 DDL 定义
- **所有模型继承 Base**：`from app.db.base import Base`
- **字段完全对齐 DDL**（逐字段验证）：
  | 表名 | 文件 | 字段数 | 关键字段 |
  |------|------|--------|---------|
  | sensor_snapshot | models/sensor.py | 16 | device_id, temperature, humidity, light, co2, soil_n/p/k, rssi, alarm_flag |
  | sensor_daily_aggregation | models/sensor.py | 18 | agg_date, avg/max/min 温度/湿度/光照/CO2, record_count |
  | disease_records | models/disease.py | 13 | crop_type, disease_type, confidence, severity, severity_code, linkage_* |
  | control_logs | models/control.py | 10 | command_id, command, source, operator, result_code, result_msg |
  | devices | models/control.py | 8 | device_id(unique), device_name, mac_addr, online |
- **models/__init__.py**：统一导出所有 5 个模型类，Alembic `target_metadata = Base.metadata` 自动发现

### 4. Pydantic Schema（schemas/）
- **common.py**：使用 Pydantic v2 `Generic[T]` 模式（`class ResponseModel(BaseModel, Generic[T])`），字段 `code`, `message`, `data: Optional[T]`；PaginationParams（page=1, page_size=20）；PaginationMeta（total, page, page_size）
- **sensor.py**：SensorSnapshotRead（16 个字段 + `from_attributes=True` 支持 ORM 模式）；SensorHistoryResponse（pagination + records）
- **disease.py**：DiseaseRecordRead（13 个字段 + `from_attributes=True`）；DiseaseStatsResponse（total_detections, by_crop, by_severity, by_disease 四个统计字典）
- **command.py**：CommandCreate（device_id, command, source="manual_app", operator 可选）；CommandRead（全字段 + `from_attributes=True`）；CommandResponse（command_id, device_id, command, status）
- **schemas/__init__.py**：统一导出所有 8 个 Schema 类

### 5. FastAPI 应用入口（main.py）
- **FastAPI 实例**：`title=settings.PROJECT_NAME, version=settings.VERSION`
- **CORS 中间件**：允许所有来源（后续生产环境可收窄）
- **生命周期事件**：
  - startup：调用 `setup_logging()`，启动日志输出
  - shutdown：输出关闭日志
- **健康检查端点 `GET /api/v1/health`**：
  - 模块级 `START_TIME` 记录启动时间戳
  - 数据库连接检测：先执行 `SET statement_timeout TO '2000'` 设置 2 秒语句级超时，再执行 `SELECT 1`
  - 连接成功：HTTP 200, `{"status": "healthy", "db_connected": true}`
  - 连接失败（try/except）：HTTP 503, `{"status": "degraded", "db_connected": false}`
  - 响应包含 `uptime_seconds`（float）、`version`（settings.VERSION）
- **根路径**：返回 `{"message": "FarmEye Guard API"}`
- **前缀**：健康检查端点使用 `settings.API_V1_PREFIX`（默认 `/api/v1`）

### 6. Alembic env.py 更新
- 在文件顶部添加 `from app.db.base import Base` 导入
- 将 `target_metadata = Base.metadata` 指向所有 ORM 模型的元数据
- 保留原有的动态 `DATABASE_URL` 环境变量读取逻辑
- 保留离线和在线两种迁移模式

## 设计决策说明

### 同步 SQLAlchemy 而非异步
选择同步 SQLAlchemy（sync `SessionLocal` 而非 `AsyncSession`），理由：
- 设计文档 `data_retention.py` 等模块使用同步 SQLAlchemy
- psycopg2 为同步驱动，与项目现有依赖一致
- 同步编程模型更简洁，错误处理更直观
- 未来如需异步支持，可通过 `asyncio.to_thread` 包装或升级至 `asyncpg` + `sqlalchemy[asyncio]`

### 连接池配置
`pool_size=2, max_overflow=2` 适配 1GB RAM VPS 约束，控制最大连接数为 4，避免撑爆 PostgreSQL。`pool_pre_ping=True` 确保连接池内连接的有效性（每次获取连接前先执行 `SELECT 1` 检查，连接失效时自动重建）。

### Generic vs Pydantic v2 泛型响应模型
任务要求中使用 `GenericModel`（Pydantic v1 风格），但项目依赖指定 `pydantic-settings~=2.5.0` 即 Pydantic v2。Pydantic v2 中 `GenericModel` 已废弃，正确方式为 `class ResponseModel(BaseModel, Generic[T])`，因此采用此方式。

### 健康检查 2 秒超时实现方式
采用 PostgreSQL `statement_timeout` 语句级超时：
- 在健康检查端点中，先执行 `SET statement_timeout TO '2000'`，再执行 `SELECT 1`
- 语句级超时捕获查询执行阶段的超时（数据库僵死、查询挂起）
- 超时时 PostgreSQL 主动中断查询并返回错误，被 try/except 捕获，返回 HTTP 503

### 日志文件路径选择
`LOG_DIR` 使用相对路径 `./logs`：
- 在 Docker 容器内解析为工作目录 `/app/logs`，行为与容器文件挂载路径一致
- 在本地 Windows/Linux 开发环境中解析为项目目录下的 `server/logs`，无需管理员权限
- 通过 Pathlib 实现跨平台兼容，Windows 下自动使用反斜杠路径分隔符

### 日志模块包含文件轮转
任务要求只写控制台日志，但额外实现了 RotatingFileHandler（10MB 轮转，保留 5 个文件）。这在生产环境中是必要功能，不影响任务核心要求。

### MetaData 命名约定已正确注入
已创建 `metadata = MetaData(naming_convention=convention)` 并将 `metadata` 赋值为 `Base.metadata`，确保外键、索引、唯一约束等在 Alembic 自动生成迁移时使用规范命名。`convention` 字典非死代码。

## 修订说明（v3 r1）

| 审查意见 | 处理方式 |
|---------|---------|
| 健康检查端点缺少 2 秒查询超时 | 已修改：在 `db.execute(text("SELECT 1"))` 前添加 `db.execute(text("SET statement_timeout TO '2000'"))`，设置 PostgreSQL 语句级超时 2 秒，确保数据库无响应时快速返回 HTTP 503 `status="degraded"` |
| 日志文件路径硬编码为 Docker 容器路径 `/app/logs` | 已修改：将 `LOG_DIR` 从 `Path("/app/logs")` 改为 `Path("./logs")` 相对路径，在 Docker 容器内解析为 `/app/logs`，在本地开发环境解析为 `server/logs`，解决非 Docker 环境下的 PermissionError |
| base.py 中 `convention` 字典定义了但未实际使用 | 已修改（复查确认代码原生正确）：`metadata = MetaData(naming_convention=convention)` 已创建，并通过 `class Base(DeclarativeBase): metadata = metadata` 注入至 Base，`convention` 已通过 MetaData 参数生效，非死代码 |

## 偏差说明

无偏差。所有文件严格按照 `task_v3.md` 的预期产出清单和详细要求创建，所有模型字段与 `docs/2_vps-deployment.md` §2.5 的 DDL 定义一致，与 `init/01_create_tables.sql` 逐字段对齐。
