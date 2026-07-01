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
