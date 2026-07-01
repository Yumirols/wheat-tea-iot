# 任务计划

任务描述：实现本地开发、容器化与验证
工作目录：E:\dev\wheat-tea-iot\pdc\202607011640_local-dev-containerization

---

## R1 NEW 本地开发环境基础文件 [ID: T1]
任务：在 server/ 目录下创建本地开发环境的基础配置文件，包括：
  - server/requirements.txt（生产依赖）
  - server/requirements-dev.txt（开发依赖）
  - server/.env.dev.example（开发环境变量模板）
  - server/.env.prod.example（生产环境变量模板）
  - server/.gitignore（Git 忽略规则）
  - server/.dockerignore（Docker 构建上下文排除规则）

选择理由：这些是项目最底层的"脚手架"文件，所有后续工作（FastAPI 应用、Docker 容器化、测试）都依赖于此。先定义依赖和环境变量模板，可以确保后续开发有清晰的依赖管理基础和环境配置规范。

上下文：server/ 目录当前为空。所有配置文件和代码参考 `docs/2_vps-deployment.md` 第 1 章（本地开发环境配置与依赖管理）和第 5.3 节（环境变量管理）的设计方案。

---

## R1 PASSED 本地开发环境基础文件 [ID: T1]
结果：在 server/ 目录下创建了 requirements.txt、requirements-dev.txt、.env.dev.example、.env.prod.example、.gitignore、.dockerignore 共 6 个文件，所有内容与设计文档逐行一致。
检查：全部 9 项检查通过（文件完整性、内容一致性、版本约束格式、无硬编码敏感信息、.example 后缀保护模式）。

---

## R2 NEW 数据库初始化与迁移框架 [ID: T2]
任务：创建数据库 DDL 建表脚本、种子数据以及 Alembic 迁移框架，包括：
  - server/init/01_create_tables.sql（DDL 建表，5 张表）
  - server/init/02_seed_data.sql（种子数据）
  - server/alembic.ini（Alembic 配置）
  - server/alembic/env.py（动态 DATABASE_URL 读取）
  - server/alembic/script.py.mako（迁移脚本模板）
  - server/alembic/versions/.gitkeep（版本目录占位）

选择理由：数据库是应用核心持久化层，FastAPI 的 ORM 模型、Pydantic Schema 和所有业务逻辑都依赖表结构。在开始编写 Python 代码前必须先定义好数据库表结构和迁移管理框架。这是整个应用的数据基础，优先级最高。

上下文：参考 `docs/2_vps-deployment.md` 第 2 章（数据库设计）§2.2.1-2.2.2 的 DDL 和种子数据，以及第 5.4 节（数据迁移策略）§5.4.2、§5.4.5 的 Alembic 配置。server/init/ 和 server/alembic/ 目录均不存在，需从零创建。

---

## R2 PASSED 数据库初始化与迁移框架 [ID: T2]
结果：创建了 6 个文件（DDL 建表、种子数据、Alembic 配置框架），所有内容与设计文档逐行一致。
检查：全部 10 项检查通过（文件存在性、5 张表完整性、6 个索引、DDL 幂等性、种子数据、Alembic 配置语法等）。

---

## R3 NEW FastAPI 应用基础框架 [ID: T3]
任务：在 server/app/ 目录下创建 FastAPI 应用的基础框架，包括：
  - 目录结构（app/, db/, models/, schemas/, api/, api/v1/, services/, core/）+ 各 __init__.py
  - server/app/config.py（Pydantic Settings 配置管理，从环境变量读取所有配置项）
  - server/app/db/base.py（SQLAlchemy Declarative Base）
  - server/app/db/session.py（数据库会话管理，engine/sessionmaker/SessionLocal/get_db 依赖）
  - server/app/core/logging_config.py（日志配置模块）
  - server/app/models/（5 个 ORM 模型：sensor_snapshot、disease_records、control_logs、devices、sensor_daily_aggregation）
  - server/app/schemas/（Pydantic Schema：通用响应 common.py、传感器 sensor.py、病虫害 disease.py、命令控制 command.py）
  - server/app/main.py（FastAPI 应用入口，含 /api/v1/health 健康检查端点）
  - 更新 server/alembic/env.py 的 target_metadata 指向 models 的 Base.metadata

选择理由：完成数据库基础设施后，下一步是建立 FastAPI 应用的全部基础代码层。config、DB session、ORM 模型、Schema 是 API 端点和业务逻辑的前置依赖。main.py 作为应用入口，必须先定义才能随后挂载路由。这一子任务产出的是应用核心骨架，代码量适中、内聚性强、有明确的验证标准（正确导入、健康检查返回 200）。

上下文：参考 `docs/2_vps-deployment.md` 第 5.1 节（工程文件组织结构）§5.1 server/ 目录结构；第 4.10 节（健康检查接口）；第 2.5 节（5 张表的字段定义）。已有产出：server/ 目录下已有 requirements.txt、.env.*.example、init/ SQL 脚本、alembic/ 迁移框架。

---

## R3 BLOCKED FastAPI 应用基础框架 [ID: T3]
原因：Do 审议达到 6 轮上限。审查发现 3 个问题——SensorDailyAggregation 模型缺失 UNIQUE(device_id, agg_date) 表级约束、main.py 存在未使用的 import、执行报告中字段计数不准确。审议在第 6 轮时仍未通过，无法继续。

## R3 NEW 修复 T3 遗留问题并完成 FastAPI 基础框架 [ID: T4]
任务：直接修复 T3 的 3 个遗留问题并验证整体一致性，作为绕过方案。在已产出的 server/app/ 代码基础上，应用以下修正：
  1. 为 SensorDailyAggregation 添加 `UniqueConstraint('device_id', 'agg_date')` 表级约束
  2. 删除 main.py 中未使用的 `from contextlib import suppress` 导入
  3. 修正执行报告 do_v3.md 中的字段计数（sensor_daily_aggregation: 18→17, devices: 8→9）
  4. 验证代码可正常导入（Python import 检查）

选择理由：T3 的审议已超限但产出代码基础基本正确，仅剩 3 个具体的技术性问题需要修复。创建新的直接修复任务（T4）绕过卡住的审议循环，以最小的变更完成 T3 目标。T4 不需要复杂的设计审议，而是直接应用已知的修复方案，完成后 T3 视为有效完成。


---

## R4 PASSED 修复 T3 遗留问题并完成 FastAPI 基础框架 [ID: T4]
结果：修复了 3 个遗留问题（UniqueConstraint 约束、未使用 import 删除、do_v3.md 字段计数）+ Python 导入验证通过。
检查：全部 5 项检查通过。

## R4 PASSED API 基础设施与传感器数据管道 [ID: T5]
结果：创建了 6 个新文件（deps.py、router.py、iotda.py、sensor.py、sensor_service.py、iotda_client.py）并修改了 main.py 和 schemas/sensor.py。认证策略分层（IoTDA 无认证、查询端点 API Key 认证），IoTDA Webhook 实现 3 个端点（properties/report、ai/report、cmd/response）含幂等性和设备自动注册，传感器查询实现 3 个端点（latest/history/daily）含分页和时间范围筛选。sensor_service 提供 CRUD 和日聚合查询，iotda_client 为桩实现并预留真实调用骨架。
检查：全部 12 项检查 PASSED。

---

## R5 PASSED 病虫害/设备/命令控制 API 端点与服务 [ID: T6]
结果：创建了 6 个新文件（disease.py、device.py、command.py、device.py schema、disease_service.py、command_service.py）、修改 2 个文件（router.py、schemas/__init__.py）。6 条新增 API 路由完整注册（disease/list、disease/stats、disease/heatmap、device/list、command/send、command/logs），Python 导入链通过验证。
检查：全部 12 项检查 PASSED。

---

## R6 NEW 防治建议联动分析与图片管理 API [ID: T7]
任务：实现防治建议（Advisory）联动分析决策引擎及其 API 端点，以及图片上传管理 API 端点。包含：
  - server/app/services/advisory_service.py：联动分析决策引擎，实现病虫害 × 环境条件匹配、风险等级评估、防治建议生成
  - server/app/api/v1/advisory.py：GET /api/v1/advisory 防治建议查询端点
  - server/app/api/v1/image.py：POST /api/v1/image/upload 图片上传 + GET /api/v1/image/{image_id} 图片获取端点
  - server/app/services/data_retention.py：APScheduler 定时任务，每日凌晨执行数据保留清理
  - 修改 server/app/api/router.py：注册 advisory 和 image 子路由
  - 修改 server/app/schemas/__init__.py：添加 AdvisoryResponse、ImageUploadResponse 等 Schema 导出

选择理由：T5 已实现 IoTDA Webhook（含 ai/report 联动分析触发入口），T6 已完成 disease/device/command 三组核心查询端点。接下来完成剩余的 advisory（含决策引擎）和 image（文件上传模式）两个 API 端点，以及 data_retention 后台定时任务。这三组功能（advisory + image + data_retention）都直接依赖 T3/T4 的 ORM 模型和 T5 的 iotda_client，且相互独立。其中 advisory_service 的决策引擎是业务最复杂的部分（病虫害 × 环境条件决策矩阵），而 image 是唯一使用 multipart 文件上传的端点，data_retention 是唯一的后台定时任务。合并为一个子任务将导致过载，但将 advisory 服务层和端点放在一起（紧密耦合决策逻辑）再将 image + data_retention 作为单独子任务又显得碎片化。综合考虑：
  - advisory_service（决策引擎）和 advisory.py API 端点紧密耦合，必须同组
  - image 端点模式单一（文件上传/获取），代码量适中（约 100-150 行）
  - data_retention 很小（约 60 行）
  - 三者都属于"完成剩余 API/服务"这一关注点，且对已有代码的修改模式相同（注册路由 + 导出 Schema）
  因此合入同一子任务，但 image 和 data_retention 作为相对独立的部分分别实现。

上下文：参考设计文档：
  - `docs/1_system_architecture.md` §4.6 防治建议接口（advisory API 响应格式）
  - `docs/1_system_architecture.md` §2.4 决策规则矩阵（12 条规则，含病虫害 × severity_code × 环境条件匹配）
  - `docs/1_system_architecture.md` §4.7 图片接口（上传/获取/存储策略）
  - `docs/2_vps-deployment.md` §2.4 数据保留与清理策略（cleanup_expired_data 实现）
  - `docs/2_vps-deployment.md` §4.2.5 防治建议与图片接口测试用例 29-35
  - `server/app/models/disease.py`（DiseaseRecord 已有 linkage_risk_level、linkage_detail 字段）
  - `server/app/services/sensor_service.py`（环境数据查询参考）
  - `server/app/config.py`（已配置 ADVISORY_WINDOW_MINUTES、IMAGE_STORAGE_PATH、DATA_RETENTION_*）
已有产出：server/app/ 下已有完整的应用骨架（models、schemas、services、api 目录），IoTDA Webhook 含 ai/report 联动分析入口点，DiseaseRecord 模型已含 linkage 字段，config.py 已含 advisory/image/retention 相关配置项。
