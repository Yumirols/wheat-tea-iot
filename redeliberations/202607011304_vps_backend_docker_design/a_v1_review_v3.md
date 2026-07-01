# 产出审查报告（v3）

## 审查结果

REJECTED

## 逐维度审查

### 1. 任务完备性

**[通过]** 覆盖了任务要求的所有五大模块：Python API 后端容器化、KingbaseES 数据库适配、VPS 部署方案、测试方案、开发工作流。

**[通过]** 测试方案覆盖了单元测试、API 接口测试、数据库集成测试、Docker 容器测试、端到端测试、性能压力测试六大类别，测试用例列表提供了具体的输入和预期结果。

**[通过]** 配置文件示例完整，包含 Dockerfile、docker-compose.yml、nginx.conf、环境变量模板、启动停止脚本等。

**[通过]** 1GB RAM 资源约束的计算分配表清晰，性能优化建议具体可行。

### 2. 质量达标性

**[通过]** 方案结构清晰，按模块分节组织，便于查阅和使用。附录提供了完整文件清单和快速部署命令汇总。

**[通过]** 内存分配计算（1GB RAM 总量）逻辑自洽，各组件资源配置有明确依据。

**[问题-一般]** Dockerfile（§1.4）与 entrypoint.sh 迁移策略（§5.4.4）不一致。§1.4 的 Dockerfile prod stage 以 `CMD` 结尾，未包含 `COPY entrypoint.sh` 和 `ENTRYPOINT` 指令；§5.4.4 描述了 entrypoint 方案但未在 Dockerfile 中体现。按照 §1.4 构建的镜像不会自动执行数据库迁移，容器首次启动时 schema 不完整，API 在缺少必要表结构的情况下运行将导致 500 错误。阻碍依据：运维人员按照文档中的 Dockerfile 构建部署，迁移不会自动执行，数据写入失败。

**[问题-一般]** `alembic.ini`（§5.4.2）中 `sqlalchemy.url` 硬编码为 `localhost:5432`，但 entrypoint.sh 在 Docker 容器内执行迁移时数据库服务的主机名为 `db`（由 docker-compose 网络 `farmeye-net` 决定）。迁移命令 `alembic upgrade head` 会因无法连接数据库而失败，容器启动进程（entrypoint.sh 使用 `set -e`）将直接退出，导致 API 服务无法启动。阻碍依据：严格按照文档部署时，容器首次启动会因数据库连接失败而退出，服务不可用。

### 3. 正确性

**[通过]** 数据库 DDL 与架构文档（§2.5）定义的表结构一致，字段类型、索引定义匹配。

**[通过]** API 接口测试用例覆盖了架构文档 §4 定义的所有端点（IoTDA webhook、sensor、disease、command、advisory、image、device、health），测试场景设计合理（正常、异常、边界、安全）。

**[通过]** pytest 钩子函数已正确移至 `conftest.py`（v3 修订），marker 注册和条件跳转逻辑正确。

**[问题-一般]** KingbaseES Docker 镜像 `kingbase/kb_v8:V008R006C008B0020`（§2.1.1 方案 A）的**公开可获取性未经验证且未提供获取途径**。KingbaseES V8 是人大金仓的商业化数据库产品，其 Docker 镜像需要商业授权并通过特定渠道获取，并非公开托管在 Docker Hub 上可直接 pull 的公共镜像。部署者按照文档执行 `docker compose up -d` 时会在 `db` 服务的镜像拉取步骤失败，导致整套方案无法部署。尽管文档提供了方案 B（PostgreSQL 16）作为备选，但方案 A 被标记为"推荐"，且整个方案的设计（连接串、ksql 健康检查、KingbaseES 专用参数调优）均围绕方案 A 展开，方案 B 缺乏同等级别的配置和验证细节。阻碍依据：VPS 上直接执行文档中的部署命令会因镜像拉取失败而终止。

**[问题-轻微]** `docker-compose.yml` 中数据库健康检查命令 `${DB_USER}` 和 `${DB_NAME}`（§1.5.1）在 `.env.prod` 模板（§1.3.2）中未定义。这会导致健康检查的 `ksql` 分支使用空值执行，虽然 `|| nc -z` 回退仍能检测 TCP 连通性，但无法验证数据库是否就绪。影响：数据库就绪检测精度降低，API 可能在数据库尚未完全初始化时启动。

## 修改要求（存在严重或一般问题时）

### 问题 1：Dockerfile 未整合 entrypoint.sh

- **问题**：§1.4 的 Dockerfile prod stage 以 `CMD` 结尾，未包含 `COPY entrypoint.sh .` 和 `ENTRYPOINT ["./entrypoint.sh"]`，与 §5.4.4 描述的自动迁移策略不一致。
- **原因**：按照 §1.4 构建的生产镜像不会自动执行 `alembic upgrade head`，首次部署时数据库 schema 不完整，API 在缺少必要表的情况下运行会产生 500 错误。
- **建议方向**：在 §1.4 的 Dockerfile prod stage 中补充 ENTRYPOINT 指令和 entrypoint.sh 的 COPY 步骤，使 Dockerfile、entrypoint.sh、迁移流程三者一致。

### 问题 2：alembic.ini 数据库连接地址不适用于 Docker 环境

- **问题**：`alembic.ini`（§5.4.2）中 `sqlalchemy.url` 使用 `localhost:5432`，而 entrypoint.sh 在容器内运行时数据库服务地址为 `db:5432`。
- **原因**：entrypoint.sh 使用 `set -e` 且 `alembic upgrade head` 是容器启动的第一步，连接失败会导致进程退出、容器无法启动。
- **建议方向**：移除 `alembic.ini` 中的硬编码连接字符串，改为使用 `env.py` 从环境变量 `DATABASE_URL` 读取；或直接将 `alembic.ini` 的连接地址改为 `db:5432`。

### 问题 3：KingbaseES Docker 镜像可获取性未处理

- **问题**：推荐使用的 `kingbase/kb_v8:V008R006C008B0020` 镜像并非公共可用镜像，需要商业授权。
- **原因**：部署者无法通过 `docker compose up` 拉取该镜像，部署方案不可执行。
- **建议方向**：（1）明确标注该镜像的获取方式（如需要向人大金仓申请授权、从特定内网 registry 拉取、或手动加载镜像 tar）；或（2）将方案 B（PostgreSQL 16）升级为主要推荐方案并提供完整的 PostgreSQL 配置细节（连接串、psql 健康检查、对应参数调优等），将 KingbaseES 方案降级为"有商业授权时的可选方案"。
