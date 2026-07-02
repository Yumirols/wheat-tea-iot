# 迭代 v2 要求 — 组件A 修改指令

## 来源

本指令基于迭代 v1 判定结果 RETRY 生成。组件B诊断报告（b_v1_diag_v2.md）经质询验证（b_v1_challenge_v2.md）确认全部质量问题证据充分、逻辑自洽、覆盖完备。

## 修改方式

EDIT_MODE:COPY_AND_EDIT — 上一轮产出（a_v1_output_v6.md）共 2357 行。请复制该文件作为新版本起点，在此基础上逐项修改，保留所有未修改的章节。

---

## 必须修改的问题（严重等级）

### 问题 1：Dockerfile 缺少 .dockerignore 导致凭据泄露风险

**位置**: §1.4 Dockerfile / §5.3.4 .gitignore / 附录§6.1 文件清单

**要求**:
1. 在 `server/` 目录的文件清单（§6.1）中新增 `.dockerignore` 文件条目
2. 在文档中（建议在 §1.4 Dockerfile 末尾或 §5.4 数据迁移策略之后）新增 `.dockerignore` 的内容示例，至少排除以下条目：
   - `.env*`（但保留 `.env.*.example`）
   - `__pycache__/`
   - `*.pyc`
   - `.git/`
   - `.venv/`
   - `logs/`
   - `backups/`
   - `.gitignore`
   - `README.md`
3. 在 §1.4 末尾增加安全说明：构建镜像前确保 `.env.prod` 等敏感文件不在构建上下文中

### 问题 2：psycopg2-binary 不推荐用于生产环境

**位置**: §1.2.1 `server/requirements.txt` / §1.4 Dockerfile base 阶段

**要求**:
1. 将 `requirements.txt` 中的 `psycopg2-binary~=2.9.0` 替换为 `psycopg2~=2.9.0`
2. 在 Dockerfile base 阶段的 `apt-get install` 中添加三项编译依赖（缺一不可）：
   - `build-essential` — 提供 C 编译器 gcc
   - `python3-dev` — 提供 Python.h 头文件
   - `libpq-dev` — 提供 pg_config 及 libpq 头文件
3. 在修改处添加注释说明：psycopg2 从源码编译，上述三项编译依赖均为必需。可选补充镜像体积影响说明（base 镜像增加约 150-200 MB）。

### 问题 3：两套 Schema 初始化机制缺乏调和策略

**位置**: §2.2.1 (init/01_create_tables.sql) / §5.4 (数据迁移策略) / entrypoint.sh

**要求**:
1. 在 §5.4 中新增"初始基准迁移"子章节，详细说明首次部署后如何调和 init SQL 脚本与 Alembic 迁移的关系
2. 具体调和策略应采纳以下方案之一（二选一并详细展开）：
   - **方案 A**：首次部署后手动或自动执行 `alembic stamp head`（如初始迁移已存在），将当前数据库 Schema 状态标记为已迁移
   - **方案 B**：生成初始 Alembic 迁移脚本（`alembic revision --autogenerate`），编辑使其使用 `CREATE TABLE IF NOT EXISTS` 以避免与 init SQL 冲突
3. 明确区分 init SQL 脚本（首次初始化基线）和 Alembic 迁移（增量变更管理）的职责边界
4. 修改 `entrypoint.sh` 使 `alembic upgrade head` 能够优雅处理首次运行的边界情况（如增加错误日志、输出当前版本号、在失败时发出警告而非直接退出容器启动流程）

---

## 建议修改的问题（一般等级）

### 问题 4：cleanup_expired_data() 异步定义但内部使用同步 SQLAlchemy 调用

**位置**: §2.4 `data_retention.py` 函数定义（第 790 行附近）

**要求**（择一实现）:
- **路径 A**：将 `cleanup_expired_data` 改为普通同步 `def`，并在 APScheduler 调度配置中说明需使用线程池执行器（ThreadPoolExecutor），避免阻塞事件循环
- **路径 B**：保留 `async def`，但将所有同步数据库操作改为使用 `asyncio.to_thread()` 包装，或在 APScheduler 配置中为该 job 指定 `Executor`（而非 `AsyncExecutor`）
- 无论选择哪个路径，在函数定义处添加注释说明此设计决策

### 问题 5：测试用例 #40 预期结果矛盾（200 与 503 并存）

**位置**: §4.2.6 测试用例 #40

**要求**:
- 将预期结果从 `"200，status=degraded, HTTP 503"` 修正为 `HTTP 503，status=degraded`
- 确保与架构文档 §4.10.1 的规定一致（degraded 状态返回 HTTP 503）

### 问题 6：端口映射与 Nginx 配置不匹配（443 映射但无 SSL 监听）

**位置**: §1.5.2 (docker-compose.prod.yml) / §3.3.1 (nginx/farmeye.conf) / §3.1.1 (UFW 规则)

**要求**（择一实现）:
- **路径 A（推荐）**：补充 Nginx SSL 配置，包括 `listen 443 ssl`、证书路径配置，并在文档中提供 Certbot + Let's Encrypt 的自动化证书申请步骤。更新 UFW 规则注释说明 443/tcp 为 HTTPS 所需
- **路径 B（最低要求）**：移除 docker-compose.prod.yml 中的 `"443:443"` 映射和 UFW 规则中的 443/tcp 开放，并在文档中明确注明"HTTPS 配置不在 v1.0 范围内"

### 问题 7：docker compose --compatibility 依赖风险未文档化

**位置**: §3.2.2、§3.5、§5.1.3（多处 `--compatibility` 参数使用）

**要求**:
1. 在 §3.5 或 §3.2.2 的说明文字中增加注释，说明 `docker compose --compatibility` 模式在不同版本间行为可能不一致，需验证生效
2. 在 §3.2.2 的"验证部署"步骤中新增：`docker inspect farmeye-api | jq '.[0].HostConfig.Memory'` 确认资源限制值是否为 268435456 (256M)
3. （可选）在附录或注释中提及替代方案：使用 Docker Compose v2 原生支持的 `mem_limit` 和 `mem_reservation` 参数（非 `deploy` 子节）

---

## 可选修改的问题（轻微等级）

以下问题建议在修改过程中一并处理，但不作为本轮必须修改项。若时间有限可标注"将在后续迭代处理"：

### 问题 8a：Docker 守护进程内存预算未优化
- **位置**: §2.1.2 内存分配计算表
- **要求**: 在"OS + 缓存"行的备注中补充"含 Docker 守护进程约 50-100 MB"

### 问题 8b：Uvicorn 参数硬编码，HOST/PORT/WORKERS 环境变量未被消费
- **位置**: §1.3.2 (.env.prod) / §1.4 (Dockerfile CMD)
- **要求**: 二选一 — 从 `.env.prod` 移除 HOST/PORT/WORKERS（并添加注释说明为预留字段）；或修改 entrypoint.sh 使其从环境变量读取这些值

### 问题 8c：测试数据库连接串硬编码
- **位置**: §4.3.1 代码片段
- **要求**: 将 `TEST_DATABASE_URL` 的值改为从环境变量 `TEST_DATABASE_URL` 读取（默认使用 `.env.test`）

### 问题 8d：备份脚本缺少容器运行状态前提检查
- **位置**: §2.3.2 backup.sh
- **要求**: 在 `docker exec` 前增加 `docker ps --format '{{.Names}}'` 容器状态检查逻辑

---

## 修改原则

1. 保持文档的整体结构和章节编号不变
2. 所有配置文件示例（Dockerfile、docker-compose.yml、nginx.conf 等）必须与修改后的文字描述一致
3. 新增内容需遵循原文的格式和风格
4. 所有修改完成后，更新文档顶部的版本号字段（如 v5 → v7，v6 → v7）
