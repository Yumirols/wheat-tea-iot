# 执行报告（v2）

## 概述
在 `server/` 目录下创建了数据库初始化脚本（DDL 建表和种子数据）和 Alembic 迁移框架，共 6 个文件。所有文件内容严格按照 `docs/2_vps-deployment.md` 中 §2.2.1（DDL 建表）、§2.2.2（种子数据）、§5.4.2（Alembic 配置）、§5.4.5（env.py 环境变量读取）的设计规格逐行实现。

## 产出清单
| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | server/init/01_create_tables.sql | DDL 建表脚本，5 张业务表 + 全部索引，幂等性设计（IF NOT EXISTS） |
| 新建 | server/init/02_seed_data.sql | 种子数据，插入初始设备 farmeye_guard_ws63，使用 ON CONFLICT DO NOTHING |
| 新建 | server/alembic.ini | Alembic 配置文件，sqlalchemy.url 不硬编码，日志级别 root=WARN / sqlalchemy=WARN / alembic=INFO |
| 新建 | server/alembic/env.py | Alembic 环境配置，从 os.getenv("DATABASE_URL") 动态读取连接串，支持离线/在线模式 |
| 新建 | server/alembic/script.py.mako | Alembic 迁移脚本 Mako 模板，标准格式 |
| 新建 | server/alembic/versions/.gitkeep | 空占位文件，保留 versions 目录在 Git 中 |

## 执行过程

### 1. server/init/01_create_tables.sql
- 严格对照设计文档 §2.2.1 创建 5 张表：sensor_snapshot、disease_records、control_logs、devices、sensor_daily_aggregation
- 所有字段类型、精度、约束与文档完全一致
- 索引覆盖：
  - sensor_snapshot: `idx_sensor_device_time` UNIQUE ON (device_id, timestamp)
  - disease_records: `idx_disease_device_time` UNIQUE ON (device_id, timestamp, disease_type)
  - control_logs: `idx_control_command_id` 部分索引 (WHERE command_id IS NOT NULL) + `idx_control_device_time` 普通索引
  - devices: `idx_devices_device_id` 索引
  - sensor_daily_aggregation: `idx_agg_device_date` 索引 + UNIQUE (device_id, agg_date) 表约束
- 所有 DDL 操作使用 CREATE TABLE IF NOT EXISTS / CREATE INDEX IF NOT EXISTS / CREATE UNIQUE INDEX IF NOT EXISTS 确保幂等性
- 文件头部注释标明 FarmEye Guard v1.0、目标数据库 PostgreSQL 16（兼容 KingbaseES V8）

### 2. server/init/02_seed_data.sql
- 严格对照设计文档 §2.2.2 创建，插入 device_id=farmeye_guard_ws63 的初始设备
- 使用 ON CONFLICT (device_id) DO NOTHING 确保幂等性

### 3. server/alembic.ini
- 严格对照设计文档 §5.4.2 创建
- script_location = alembic
- sqlalchemy.url 不在此硬编码，添加注释说明由 env.py 从 DATABASE_URL 环境变量动态读取
- 日志配置：root=WARN, sqlalchemy=WARN, alembic=INFO, 使用 StreamHandler

### 4. server/alembic/env.py
- 严格对照设计文档 §5.4.5 创建
- 通过 os.getenv("DATABASE_URL") 动态读取连接串，若存在则覆盖 config 中的 sqlalchemy.url
- 通过 fileConfig 读取 alembic.ini 的日志配置
- 实现 run_migrations_offline（离线模式，生成 SQL 脚本）和 run_migrations_online（在线模式，连接数据库执行）
- target_metadata 暂设为 None，后续 ORM 模型实现后更新
- 包含完整的跨环境支持设计注释

### 5. server/alembic/script.py.mako
- 标准 Alembic 默认 Mako 模板，包含 revision/down_revision/branch_labels/depends_on 标准头 + upgrade/downgrade 函数

### 6. server/alembic/versions/.gitkeep
- 空文件，占位保留 versions 目录

## 偏差说明
无。所有文件严格对照设计文档及任务指令创建，无偏离。
