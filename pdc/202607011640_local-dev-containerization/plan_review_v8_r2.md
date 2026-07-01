# 计划审查报告（v8 r2）

## 审查结果
REJECTED

## 发现

### [严重] 基础镜像不一致

plan.md 写明 Dockerfile 基于 `python:3.13-slim`，但 task_v8.md 第1节明确要求基于 `ubuntu:25.04`。这两种镜像的构建方式完全不同：
- `python:3.13-slim` 是 Debian-based、已预装 Python，无需创建 venv，直接 `pip install` 即可
- `ubuntu:25.04` 需要手动 `apt-get install python3 python3-venv python3-pip`、创建 `/opt/venv`、配置 `PATH` 环境变量
- 健康检查依赖 `curl`（需 `apt-get install curl`）— 这在 `python:3.13-slim` 中默认不可用

如果执行者跟随 plan 的 `python:3.13-slim` 编写 Dockerfile，将完全偏离 task_v8 的规格，产出文件不可用。

**期望修正方向**：将 plan.md 中 Dockerfile 的基础镜像改为 `ubuntu:25.04`。

### [一般] docker-compose.yml 遗漏 api-dev 服务

plan.md 仅描述"API 服务 + PostgreSQL 16"（2 个服务），但 task_v8.md 第2节定义了 3 个服务：
- `api`（production profile）
- `db`（PostgreSQL 16）
- `api-dev`（dev profile，volumes 挂载源码实现热重载，资源限制 512M/256M，端口直接暴露 8000）

双 profile 设计是 task_v8 的关键架构决策，确保开发和生产环境隔离。plan 缺失对 `api-dev` 服务的描述会导致执行者遗漏该服务。

**期望修正方向**：在 docker-compose.yml 描述中补充 `api-dev` 服务及其 dev profile 信息。

### [一般] docker-compose.prod.yml 遗漏 nginx 服务

plan.md 仅提到"生产环境覆写（资源限制、重启策略、日志驱动）"，但 task_v8.md 第3节要求生产覆写中包含 `nginx` 服务（`nginx:1.27-alpine`，含 80:80/443:443 端口映射、SSL 证书卷挂载、`images_data` 静态文件卷挂载、64M/32M 资源限制）。

**期望修正方向**：在 docker-compose.prod.yml 描述中补充 nginx 服务定义。

### [一般] entrypoint.sh 描述过于简略

plan.md 简化为"Alembic 迁移 + 应用启动"，但 task_v8.md 第4节要求实现复杂的迁移检测逻辑，包括：
1. 运行 `alembic current` 检测已有迁移版本
2. 根据是否检测到版本记录设置 `STRICT_MIGRATION` 标记
3. `alembic upgrade head` 失败时根据该标记决定是 `exit 1`（已有版本时严格失败）还是宽容提示（首次部署时建议手动 `alembic stamp head`）

缺少这些细节可能导致执行者实现一个简单的 `alembic upgrade head && exec "$@"` 脚本，与 task 要求不符。

**期望修正方向**：在 entrypoint.sh 描述中补充两阶段迁移检测和失败处理逻辑的概要。

### [轻微] plan.md R8 段尾残留 T7 任务描述

plan.md 中 R8 的"上下文"部分后面，残留了一整段 T7 的任务描述（"任务：实现防治建议（Advisory）联动分析决策引擎..."——从第118行到第142行）。这段内容与 R8 完全无关，会严重干扰执行者对当前任务范围的理解。

**期望修正方向**：删除 R8 段尾残留的 T7 内容。

### [轻微] 设计文档引用编号不一致

plan.md 引用 `docs/2_vps-deployment.md` 第 4 章 (§4.1-4.4)，而 task_v8.md 引用的是同一文档的 §1.4-1.7、§5.4.4、§3.5。应统一为 task_v8.md 使用的编号体系。

**期望修正方向**：统一引用编号为 task_v8.md 所使用的版本。

## 修改要求

因存在 1 个严重问题和 3 个一般问题，计划被驳回。要求依次修正以下项目：

1. **将基础镜像从 `python:3.13-slim` 改为 `ubuntu:25.04`**——这是最关键的问题，影响整个 Dockerfile 的结构
2. **在 docker-compose.yml 描述中补充 `api-dev` 服务**——明确开发 profile 的设计
3. **在 docker-compose.prod.yml 描述中补充 nginx 服务**——明确生产环境的完整拓扑
4. **在 entrypoint.sh 描述中补充两阶段迁移检测逻辑**——确保容器入口行为正确
5. **删除 R8 段尾残留的 T7 任务描述**——清理残余内容
6. **统一设计文档引用编号**——与 task_v8.md 保持一致
