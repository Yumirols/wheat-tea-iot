# 任务指令（v3）

## 动作
NEW

## 任务描述
在 `server/app/` 目录下创建 FastAPI 应用的基础框架，包括完整的目录结构、配置管理、数据库会话、ORM 模型、Pydantic Schema 和带健康检查的应用入口。所有实现严格参照 `docs/2_vps-deployment.md` 中第 2.5 节（5 张表的字段定义）、第 4.10 节（健康检查接口）以及第 5.1 节（server/ 目录结构）的设计方案。

### 预期产出清单

| # | 文件路径 | 说明 |
|---|---------|------|
| 1 | server/app/__init__.py | 空 init 文件 |
| 2 | server/app/config.py | Pydantic Settings 配置管理 |
| 3 | server/app/db/__init__.py | 空 init 文件 |
| 4 | server/app/db/base.py | SQLAlchemy Declarative Base |
| 5 | server/app/db/session.py | 数据库会话管理 |
| 6 | server/app/core/__init__.py | 空 init 文件 |
| 7 | server/app/core/logging_config.py | 日志配置模块 |
| 8 | server/app/models/__init__.py | 导出所有模型 |
| 9 | server/app/models/sensor.py | SensorSnapshot + SensorDailyAggregation ORM 模型 |
| 10 | server/app/models/disease.py | DiseaseRecord ORM 模型 |
| 11 | server/app/models/control.py | ControlLog + Device ORM 模型 |
| 12 | server/app/schemas/__init__.py | 导出所有 Schema |
| 13 | server/app/schemas/common.py | 通用响应模型（ResponseModel、PaginationParams、PaginationMeta） |
| 14 | server/app/schemas/sensor.py | 传感器数据 Schema |
| 15 | server/app/schemas/disease.py | 病虫害记录 Schema |
| 16 | server/app/schemas/command.py | 命令控制 Schema |
| 17 | server/app/api/__init__.py | 空 init 文件 |
| 18 | server/app/api/v1/__init__.py | 空 init 文件 |
| 19 | server/app/services/__init__.py | 空 init 文件 |
| 20 | server/app/main.py | FastAPI 应用入口，含健康检查和生命周期事件 |
| 21 | server/alembic/env.py（更新已有文件） | 修改 target_metadata 指向 models.Base.metadata |

### 文件详细要求

#### server/app/config.py
- 继承 Pydantic `BaseSettings`，使用 `model_config = SettingsConfigDict(env_file=".env")`
- 配置字段（从环境变量读取）：
  - `DATABASE_URL: str`（默认：`postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db`）
  - `IOTDA_ENDPOINT: str`
  - `IOTDA_PROJECT_ID: str`
  - `ADVISORY_WINDOW_MINUTES: int`（默认 60）
  - `DATA_RETENTION_SENSOR_DAYS: int`（默认 30）
  - `DATA_RETENTION_CONTROL_DAYS: int`（默认 90）
  - `IMAGE_STORAGE_PATH: str`（默认 `"./images"`）
  - `API_KEYS: str`（默认空字符串）
  - `LOG_LEVEL: str`（默认 `"INFO"`）
  - `API_V1_PREFIX: str`（默认 `"/api/v1"`）
  - `PROJECT_NAME: str`（默认 `"FarmEye Guard API"`）
  - `VERSION: str`（默认 `"v1.0.0"`）
- 提供全局单例 `settings = Settings()`

#### server/app/db/base.py
- 使用 `from sqlalchemy.orm import DeclarativeBase`
- 声明 `class Base(DeclarativeBase): pass`
- 配套 MetaData 命名约定（可选但推荐）

#### server/app/db/session.py
- 配置 SQLAlchemy `create_engine`（`DATABASE_URL` 从 config 读取）
- 创建 `SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)`
- 实现异步生成器函数 `def get_db()` 用于 FastAPI 依赖注入（yield SessionLocal 实例，finally 中 close）

#### server/app/core/logging_config.py
- 定义 `setup_logging()` 函数
- 使用标准 logging 模块配置控制台日志
- 格式：`%(asctime)s - %(name)s - %(levelname)s - %(message)s`
- 日志级别从 `settings.LOG_LEVEL` 读取

#### server/app/models/
- 严格按照 `docs/2_vps-deployment.md` §2.5 的五张表定义实现
- **models/sensor.py**：SensorSnapshot 和 SensorDailyAggregation
  - SensorSnapshot 映射 `sensor_snapshot` 表（字段: id, device_id, mac_addr, timestamp, temperature, humidity, light, co2, soil_n, soil_p, soil_k, distance, rssi, ip_addr, alarm_flag, created_at）
  - SensorDailyAggregation 映射 `sensor_daily_aggregation` 表（字段: id, device_id, agg_date, avg_temperature, max_temperature, min_temperature, avg_humidity, max_humidity, min_humidity, avg_light, max_light, min_light, avg_co2, max_co2, min_co2, record_count, created_at）
- **models/disease.py**：DiseaseRecord 映射 `disease_records` 表（字段: id, device_id, timestamp, crop_type, disease_type, confidence, severity, severity_code, linkage_risk_level, linkage_detail, image_path, action_taken, created_at）
- **models/control.py**：ControlLog 映射 `control_logs` 表（字段: id, device_id, command_id, timestamp, command, source, operator, result_code, result_msg, created_at）+ Device 映射 `devices` 表（字段: id, device_id, device_name, mac_addr, ip_addr, registered_at, last_seen, online, created_at）
- **models/__init__.py** 从各模块导入所有模型类
- 所有模型使用 `from app.db.base import Base` 继承
- 所有字段类型、精度、约束与设计文档中的 DDL 完全一致

#### server/app/schemas/
- **schemas/common.py**：
  - `class ResponseModel(GenericModel, TypeVar("T")):` 含 `code: int`, `message: str`, `data: T | None`
  - `class PaginationParams:` 作为查询参数依赖（page: int = 1, page_size: int = 20）
  - `class PaginationMeta:` 含 total, page, page_size
- **schemas/sensor.py**：SensorSnapshotRead（含全部字段）、SensorHistoryResponse（含 PaginationMeta + records 列表）
- **schemas/disease.py**：DiseaseRecordRead（含全部字段）、DiseaseStatsResponse（total_detections, by_crop, by_severity, by_disease）
- **schemas/command.py**：CommandCreate（device_id, command, source, operator 可选）、CommandRead（含全部字段）、CommandResponse（command_id, device_id, command, status）
- **schemas/__init__.py** 导出所有 Schema 类

#### server/app/main.py
- 创建 `app = FastAPI(title=settings.PROJECT_NAME, version=settings.VERSION)`
- 注册启动事件（`@app.on_event("startup")`）：调用 `setup_logging()`，可选打印启动信息
- 注册关闭事件（`@app.on_event("shutdown")`）：清理资源（如果有）
- 实现 `/api/v1/health` GET 端点：
  - 返回 `{"code": 0, "message": "success", "data": {"status": "healthy", "uptime_seconds": <float>, "db_connected": <bool>, "version": "v1.0.0"}}`
  - `db_connected` 通过 `from sqlalchemy import text; db.execute(text("SELECT 1"))` 检测
  - 超时时间 2 秒，连接失败时 `status="degraded"`, HTTP 状态码 503
  - 启动时间戳存为模块级变量 `START_TIME`
- 默认根路径返回 `{"message": "FarmEye Guard API"}`
- 引入 CORS 中间件（允许所有来源，后续可收窄）
- 引入 `API_V1_PREFIX` 配置变量

#### server/alembic/env.py（更新）
- 在文件顶部添加：`from app.db.base import Base` 和 `target_metadata = Base.metadata`
- 保持原有的动态 DATABASE_URL 读取逻辑

## 选择理由
这是 FastAPI 应用的基础骨架层。config、DB session、ORM 模型、Pydantic Schema 是所有业务逻辑和 API 端点的前置依赖。在实现任何具体 API 端点或服务之前，必须先完成这一层。codebase 中已有 T1 的依赖文件和 T2 的数据库 DDL/Alembic 框架，本任务将两者通过 ORM 模型和 env.py 关联起来。

## 任务上下文
- 参考 `docs/2_vps-deployment.md`：
  - §2.5 表1-表5（五张表的字段定义）
  - §4.10 健康检查接口
  - §5.1 server/ 目录结构（app/ 子目录）
- 参考 `docs/0_system_specification.md`：系统整体定位
- 已有产出：
  - server/requirements.txt（含 fastapi、sqlalchemy、alembic 等依赖）
  - server/init/01_create_tables.sql（DDL 建表脚本）
  - server/alembic.ini + server/alembic/env.py + server/alembic/script.py.mako（Alembic 迁移框架）
- 所有新文件创建在 `server/app/` 下及其子目录
