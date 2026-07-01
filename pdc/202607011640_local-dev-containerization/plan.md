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
