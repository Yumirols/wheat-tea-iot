# 执行报告（v8）

## 概述

根据 task_v8.md 指令，在 `server/` 目录下创建了完整的 Docker 容器化配置，包含 4 个文件：多阶段 Dockerfile、主编排文件、生产覆写文件和容器入口脚本。

## 产出清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | `server/Dockerfile` | 三阶段多阶段构建（base/dev/prod），基于 ubuntu:25.04 |
| 新建 | `server/docker-compose.yml` | 主编排文件，含 api（production profile）、db、api-dev（dev profile）三个服务 |
| 新建 | `server/docker-compose.prod.yml` | 生产覆写文件，增加 Nginx 服务、日志驱动、重启策略和资源限制覆写 |
| 新建 | `server/entrypoint.sh` | 容器入口脚本，含 Alembic 迁移版本检测和两阶段失败处理逻辑 |

## 执行过程

### 1. 设计依据确认

- 参考 `docs/2_vps-deployment.md` 第 1.4、1.5、1.5.2、1.7、5.4.4 节的设计规格
- 参考 `task_v8.md` 中关于 Dockerfile 构建参数、健康检查命令格式、entrypoint 脚本的具体要求
- 确认健康检查端点的 JSON 返回格式：`{"code": 0, "message": "success", "data": {"status": "healthy", ...}}`，确保 `grep -q '"status":"healthy"'` 可正确匹配
- 确认 `.dockerignore` 已存在且正确配置了 `.env*` 排除规则

### 2. 关键决策

- **Dockerfile 结构**：严格遵循 VPS 文档的三阶段设计（base/dev/prod），与已有的 `.dockerignore`、`requirements.txt`、`requirements-dev.txt` 保持一致
- **健康检查 grep 命令**：Dockerfile 中使用 `grep -q '"status":"healthy"'`（单引号包裹双引号），docker-compose.yml 中使用 YAML 转义 `'\"status\":\"healthy\"'`，两者产生相同的 Shell 命令
- **PostgreSQL 调优参数**：在 db 服务的 `command` 中设置 `shared_buffers=64MB`、`effective_cache_size=256MB`、`work_mem=4MB`、`maintenance_work_mem=16MB`、`max_connections=10`，适配 1GB RAM 环境
- **双 profile 设计**：api 服务归属 `production` profile，api-dev 服务归属 `dev` profile，通过 `docker compose --profile dev up` 选择开发模式
- **网络和卷的跨文件引用**：`docker-compose.prod.yml` 中的 nginx 服务引用 `farmeye-net` 网络和 `images_data` 卷，这些定义在 `docker-compose.yml` 中，Docker Compose 的 `-f` 多文件合并机制会自动解析

### 3. 边界情况处理

- **entrypoint.sh 首次部署**：当无迁移版本记录时，alembic upgrade 失败不会导致容器退出，而是打印警告并继续启动，避免 init SQL 已完成但 Alembic 未 stamp 的场景导致容器 CrashLoopBackOff
- **entrypoint.sh 已有版本记录**：当有迁移版本记录但升级失败时，脚本会以非零退出码终止，防止数据不一致
- **dev 模式 healthcheck 禁用**：api-dev 服务明确设置 `healthcheck: disable: true`，避免 `--reload` 模式下因文件变化重启导致健康检查误报
- **端口绑定安全性**：生产环境的 api 和 db 服务均绑定到 `127.0.0.1`，仅本地可访问，通过 Nginx 对外暴露

## 偏差说明

无
