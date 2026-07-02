# 任务指令（v2）

## 动作
NEW

## 任务描述
在 `server/` 目录下创建数据库初始化脚本和 Alembic 迁移框架，具体产出物如下：

### 1. server/init/01_create_tables.sql
根据 `docs/2_vps-deployment.md` §2.2.1 的设计，创建 DDL 建表脚本，包含以下 5 张表及其索引：
- **sensor_snapshot**：环境数据快照（device_id, mac_addr, timestamp, temperature, humidity, light, co2, soil_n/p/k, distance, rssi, ip_addr, alarm_flag），含 `idx_sensor_device_time` 唯一索引
- **disease_records**：病虫害识别记录（device_id, timestamp, crop_type, disease_type, confidence, severity, severity_code, linkage_risk_level, linkage_detail, image_path, action_taken），含 `idx_disease_device_time` 唯一索引
- **control_logs**：设备控制日志（device_id, command_id, timestamp, command, source, operator, result_code, result_msg），含 `idx_control_command_id` 部分索引（WHERE command_id IS NOT NULL）+ `idx_control_device_time` 普通索引
- **devices**：设备注册信息（device_id UNIQUE, device_name, mac_addr, ip_addr, registered_at, last_seen, online），含 `idx_devices_device_id` 索引
- **sensor_daily_aggregation**：环境数据日聚合（device_id, agg_date UNIQUE, avg/max/min temperature/humidity/light/co2, record_count），含 `idx_agg_device_date` 索引

所有表和索引使用 `CREATE TABLE IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS` / `CREATE UNIQUE INDEX IF NOT EXISTS` 以确保幂等性。文件头部需包含注释标明 FarmEye Guard v1.0、目标数据库 PostgreSQL 16（兼容 KingbaseES V8）。

### 2. server/init/02_seed_data.sql
根据 `docs/2_vps-deployment.md` §2.2.2 的设计，插入初始设备 `farmeye_guard_ws63`，使用 `ON CONFLICT (device_id) DO NOTHING` 确保幂等性。

### 3. server/alembic.ini
根据 `docs/2_vps-deployment.md` §5.4.2 的设计，创建 Alembic 配置文件：
- `script_location = alembic`
- `sqlalchemy.url` 不在此硬编码（由 env.py 从环境变量动态读取）
- 日志配置使用 StreamHandler，日志级别：root=WARN, sqlalchemy=WARN, alembic=INFO
- 注释注明连接地址由环境变量 DATABASE_URL 动态提供

### 4. server/alembic/env.py
根据 `docs/2_vps-deployment.md` §5.4.5 的设计：
- 从 `os.getenv("DATABASE_URL")` 动态读取数据库连接地址
- 支持离线模式（`run_migrations_offline`）和在线模式（`run_migrations_online`）
- 日志配置从 `alembic.ini` 读取（`fileConfig`）
- `target_metadata` 暂时设为 `None`（后续 ORM 模型实现后更新）
- 包含完整的文件注释说明跨环境支持设计

### 5. server/alembic/script.py.mako
Alembic 迁移脚本模板，使用 Alembic 默认 mako 模板内容（被 `alembic init` 自动生成），标准格式即可。

### 6. server/alembic/versions/.gitkeep
创建空的 `.gitkeep` 文件以保留版本目录在 Git 中。

## 选择理由
数据库初始化和 Alembic 迁移框架是应用持久化层的基础。T1 完成了环境脚手架（依赖和环境变量），T2 接着建立数据库结构层——这是数据流的核心。DDL 建表脚本定义了所有业务表（传感器、病虫害、控制、设备、聚合），Alembic 框架为后续 Schema 版本管理提供基础设施。两者共同构成数据层基石，完成后即可开始 FastAPI 的业务代码开发。

## 任务上下文
- 所有文件根据 `docs/2_vps-deployment.md` 中的设计规格创建，逐行对应
- 数据库选型为 PostgreSQL 16，DDL 同时兼容 KingbaseES V8（使用标准 PostgreSQL DDL 语法）
- 5 张表的字段类型、精度、约束条件严格按照 §2.2.1 的设计定义
- Alembic 配置严格按照 §5.4.2 和 §5.4.5 的设计，env.py 从环境变量 DATABASE_URL 读取连接串
- server/init/ 和 server/alembic/ 目录不存在，需从零创建
- 所有 SQL 脚本需保证幂等性（IF NOT EXISTS / ON CONFLICT DO NOTHING）

## 已有产出上下文
- `server/requirements.txt`：包含 alembic~=1.13.0 依赖
- `server/requirements-dev.txt`：包含测试相关依赖
- `server/.env.dev.example`：DEV 模式 DATABASE_URL 使用 `localhost:5432`
- `server/.env.prod.example`：PROD 模式 DATABASE_URL 使用 `db:5432`
- `server/.gitignore`：已配置 Python、IDE、日志等忽略规则
- `server/.dockerignore`：已配置 Docker 构建上下文排除规则

## 预期产出清单
| 文件路径 | 版本 | 来源 |
|---------|------|------|
| server/init/01_create_tables.sql | v1 | 设计文档 §2.2.1 |
| server/init/02_seed_data.sql | v1 | 设计文档 §2.2.2 |
| server/alembic.ini | v1 | 设计文档 §5.4.2 |
| server/alembic/env.py | v1 | 设计文档 §5.4.5 |
| server/alembic/script.py.mako | v1 | Alembic init 默认 |
| server/alembic/versions/.gitkeep | v1 | 目录占位 |
