# 再审议判定报告（v1）

## 判定结果

RETRY

## 判定理由

组件B的诊断报告（b_v1_diag_v2.md）经2轮内部循环迭代后，对组件A产出（a_v1_output_v6.md）进行了全面审查，识别出 **3项严重问题** 和 **4项一般问题**。质询报告（b_v1_challenge_v2.md）逐条核实后确认：全部问题证据充分（行级引用确凿）、逻辑自洽、覆盖完备（五个任务维度无遗漏）。

依据判定标准——"审查报告包含严重或一般等级的问题"——应判定为 RETRY，要求组件A重新运行以修复已识别的问题。

## 需要解决的问题

### 严重问题

- **问题描述**：Dockerfile prod stage 使用 `COPY . .`，但项目缺少 `.dockerignore` 文件，导致 `.env.prod` 等生产凭证可能被复制进 Docker 镜像，造成凭据泄露风险。
- **所在位置**：§1.4 Dockerfile / §5.3.4 .gitignore / 附录§6.1 文件清单
- **严重程度**：严重
- **改进建议**：在 `server/` 目录下创建 `.dockerignore`，至少排除 `.env*`（除 .env.*.example）、`__pycache__/`、`*.pyc`、`.git/`、`.venv/`、`logs/`、`backups/`、`.gitignore`、`README.md`；在 §6.1 文件清单中添加 `.dockerignore`；在文档中增加安全说明。

- **问题描述**：`requirements.txt` 中数据库驱动为 `psycopg2-binary~=2.9.0`，官方明确声明不推荐用于生产环境。二进制包链接特定版本 libpq，存在运行时兼容性风险和安全隐患。
- **所在位置**：§1.2.1 `server/requirements.txt` 第104行；§1.4 Dockerfile base 阶段
- **严重程度**：严重
- **改进建议**：将 `psycopg2-binary` 替换为 `psycopg2~=2.9.0`；在 Dockerfile base 阶段 apt-get install 中添加 `build-essential`、`python3-dev`、`libpq-dev` 三项编译依赖（缺一不可，已验证）。

- **问题描述**：系统同时存在两套 Schema 初始化机制（`init/01_create_tables.sql` 通过 `/docker-entrypoint-initdb.d/` 执行，`entrypoint.sh` 调用 `alembic upgrade head`），但文档未给出任何调和策略。首次部署时 `alembic upgrade head` 很可能会失败，导致 API 容器进入崩溃重启循环。
- **所在位置**：§2.2.1 (init/01_create_tables.sql) / §5.4 (数据迁移策略)
- **严重程度**：严重
- **改进建议**：在 §5.4 中增加"初始基准迁移"子章节，说明如何在首次部署后执行 `alembic stamp head` 或生成兼容的初始迁移；明确区分 init SQL 脚本（首次初始化基线）和 Alembic 迁移（增量变更）的关系；修改 `entrypoint.sh` 增加重试逻辑或日志输出以便诊断。

### 一般问题

- **问题描述**：`cleanup_expired_data()` 定义为 `async def`，但内部使用同步 SQLAlchemy 调用（`SessionLocal()`、`db.execute()`、`db.commit()`），阻塞事件循环，影响 API 响应和 30s 离线判定定时任务。
- **所在位置**：§2.4 `data_retention.py`
- **严重程度**：一般
- **改进建议**：将函数改为普通同步 `def` 并在 APScheduler 中配置为线程池执行，或使用 `asyncio.to_thread()` 包装同步操作。

- **问题描述**：测试用例 #40 的预期结果同时列为 `"200，status=degraded, HTTP 503"`，200 与 503 矛盾。架构文档规定 degraded 状态返回 503。
- **所在位置**：§4.2.6 测试用例 #40
- **严重程度**：一般
- **改进建议**：将预期结果修正为 `HTTP 503，status=degraded`。

- **问题描述**：docker-compose.prod.yml 映射端口 443，UFW 开放 443/tcp，但 Nginx 配置仅有 `listen 80`，无 SSL 证书配置和 `listen 443 ssl`，HTTPS 请求会被拒绝或超时。
- **所在位置**：§1.5.2 (docker-compose.prod.yml) / §3.3.1 (nginx/farmeye.conf)
- **严重程度**：一般
- **改进建议**：补充 Nginx SSL 配置 + Certbot/Let's Encrypt 方案；或移除 `"443:443"` 映射和 UFW 规则并注明 HTTPS 不在 v1.0 范围内。

- **问题描述**：方案依赖 `docker compose --compatibility` 将 `deploy.resources.limits.memory` 转换为 cgroup 限制，但该模式在不同 Docker Compose v2 版本间行为不一致，文档未提及此依赖风险，也无部署后验证步骤。
- **所在位置**：§3.2.2、§3.5、§5.1.3
- **严重程度**：一般
- **改进建议**：增加 `--compatibility` 限制说明；在验证部署步骤中添加 `docker inspect` 确认资源限制已生效；考虑使用 Compose v2 原生 `mem_limit`/`mem_reservation` 替代方案。

### 轻微问题

剩余 L1-L4 四项低优先级问题（Docker 守护进程内存预算、Uvicorn 参数硬编码、测试连接串硬编码、备份脚本缺少容器状态检查）建议在编码过程中逐步解决，不影响本轮 RETRY 判定。
