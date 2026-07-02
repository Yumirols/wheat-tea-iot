

## 迭代 v2

### 判定结果

RETRY

### 判定理由

组件B对本轮产出（a_v2_output_v2.md）执行了质量审查，确认7项历史问题全部修复，但同时定位到6项新增问题。其中包含1项严重等级问题和3项中等等级问题，已满足"审查报告包含严重或一般等级的问题"的RETRY条件。

具体问题分布：
- 严重（1项）：entrypoint.sh在alembic迁移失败时不区分首次部署与真实错误，可能导致API在不一致的Schema状态下运行
- 中等（3项）：datetime.utcnow()兼容性问题、API端口绕过Nginx安全层、文档关于端口暴露的内部矛盾
- 轻微（2项）：重复标题、本地开发编译依赖说明缺失

### 需要解决的问题

#### 严重问题

1. **entrypoint.sh中alembic迁移失败后静默继续**
   - **问题描述**：entrypoint.sh中alembic upgrade head失败后静默继续，不区分首次部署（预期行为）与真实迁移错误（如SQL语法错误、连接中断、版本冲突），可能导致API在不一致的Schema状态下运行
   - **所在位置**：§5.4.4 entrypoint.sh（第2278-2286行）
   - **改进建议**：在entrypoint.sh中先检查`alembic current`输出，仅当无版本记录（首次部署）时才允许静默继续；或引入`FARMEYE_STRICT_MIGRATION`环境变量控制行为

#### 一般问题

2. **`datetime.utcnow()`在Python 3.13+中已弃用**
   - **问题描述**：`datetime.utcnow()`在Python 3.13中已弃用，运行时产生DeprecationWarning，Python 3.14+将正式移除
   - **所在位置**：§2.4 data_retention.py（第859行）
   - **改进建议**：替换为`datetime.now(datetime.timezone.utc)`并调整相关时间比较逻辑

3. **生产环境API端口暴露到宿主机所有网络接口**
   - **问题描述**：生产环境API端口`"8000:8000"`暴露到宿主机所有网络接口，可直接绕过Nginx的SSL终止、请求过滤等安全层
   - **所在位置**：§1.5.1 docker-compose.yml api服务（第352行）
   - **改进建议**：改为`"127.0.0.1:8000:8000"`（方案A）或移除ports块由Nginx通过Docker网络转发（方案B，推荐）

4. **文档三处对端口8000的处理存在目标冲突**
   - **问题描述**：文档三处对端口8000的处理存在目标冲突（UFW规则、docker-compose端口映射、Nginx方案），当三份配置同时应用时API可通过多路径访问
   - **所在位置**：§3.1.1 UFW规则（第1078行） vs §1.5.1端口映射（第352行） vs §3.3 Nginx方案
   - **改进建议**：在部署脚本中增加条件判断，或提供两组明确的生产部署模板（"有Nginx"/"无Nginx"）

#### 轻微问题

5. **文档重复标题**
   - **问题描述**：文档中存在重复的章节标题，影响文档可读性和一致性
   - **改进建议**：清理重复标题，确保每个标题唯一

6. **本地开发编译依赖说明缺失**
   - **问题描述**：文档未说明本地开发环境所需的编译依赖（如build-essential、python3-dev、libpq-dev等）
   - **改进建议**：在本地开发环境说明中补充编译依赖安装步骤

### 判定结果

RETRY

### 判定理由

组件B的诊断报告（b_v1_diag_v2.md）经2轮内部循环迭代后，对组件A产出（a_v1_output_v6.md）进行了全面审查，识别出 **3项严重问题** 和 **4项一般问题**。质询报告（b_v1_challenge_v2.md）逐条核实后确认：全部问题证据充分（行级引用确凿）、逻辑自洽、覆盖完备（五个任务维度无遗漏）。

依据判定标准——"审查报告包含严重或一般等级的问题"——应判定为 RETRY，要求组件A重新运行以修复已识别的问题。

### 需要解决的问题

#### 严重问题

1. **Dockerfile 缺少 .dockerignore 导致凭据泄露风险**
   - **问题描述**：Dockerfile prod stage 使用 `COPY . .`，但项目缺少 `.dockerignore` 文件，导致 `.env.prod` 等生产凭证可能被复制进 Docker 镜像，造成凭据泄露风险。
   - **所在位置**：§1.4 Dockerfile / §5.3.4 .gitignore / 附录§6.1 文件清单
   - **改进建议**：在 `server/` 目录下创建 `.dockerignore`，至少排除 `.env*`（除 .env.*.example）、`__pycache__/`、`*.pyc`、`.git/`、`.venv/`、`logs/`、`backups/`、`.gitignore`、`README.md`；在 §6.1 文件清单中添加 `.dockerignore`；在文档中增加安全说明。

2. **psycopg2-binary 不推荐用于生产环境**
   - **问题描述**：`requirements.txt` 中数据库驱动为 `psycopg2-binary~=2.9.0`，官方明确声明不推荐用于生产环境。二进制包链接特定版本 libpq，存在运行时兼容性风险和安全隐患。
   - **所在位置**：§1.2.1 `server/requirements.txt` 第104行；§1.4 Dockerfile base 阶段
   - **改进建议**：将 `psycopg2-binary` 替换为 `psycopg2~=2.9.0`；在 Dockerfile base 阶段 apt-get install 中添加 `build-essential`、`python3-dev`、`libpq-dev` 三项编译依赖（缺一不可，已验证）。

3. **两套 Schema 初始化机制缺乏调和策略**
   - **问题描述**：系统同时存在两套 Schema 初始化机制（`init/01_create_tables.sql` 通过 `/docker-entrypoint-initdb.d/` 执行，`entrypoint.sh` 调用 `alembic upgrade head`），但文档未给出任何调和策略。首次部署时 `alembic upgrade head` 很可能会失败，导致 API 容器进入崩溃重启循环。
   - **所在位置**：§2.2.1 (init/01_create_tables.sql) / §5.4 (数据迁移策略)
   - **改进建议**：在 §5.4 中增加"初始基准迁移"子章节，说明如何在首次部署后执行 `alembic stamp head` 或生成兼容的初始迁移；明确区分 init SQL 脚本（首次初始化基线）和 Alembic 迁移（增量变更）的关系；修改 `entrypoint.sh` 增加重试逻辑或日志输出以便诊断。

#### 一般问题

4. **cleanup_expired_data() 异步定义但内部使用同步 SQLAlchemy 调用**
   - **问题描述**：`cleanup_expired_data()` 定义为 `async def`，但内部使用同步 SQLAlchemy 调用（`SessionLocal()`、`db.execute()`、`db.commit()`），阻塞事件循环，影响 API 响应和 30s 离线判定定时任务。
   - **所在位置**：§2.4 `data_retention.py`
   - **改进建议**：将函数改为普通同步 `def` 并在 APScheduler 中配置为线程池执行，或使用 `asyncio.to_thread()` 包装同步操作。

5. **测试用例 #40 预期结果矛盾**
   - **问题描述**：测试用例 #40 的预期结果同时列为 `"200，status=degraded, HTTP 503"`，200 与 503 矛盾。架构文档规定 degraded 状态返回 503。
   - **所在位置**：§4.2.6 测试用例 #40
   - **改进建议**：将预期结果修正为 `HTTP 503，status=degraded`。

6. **端口映射与 Nginx 配置不匹配**
   - **问题描述**：docker-compose.prod.yml 映射端口 443，UFW 开放 443/tcp，但 Nginx 配置仅有 `listen 80`，无 SSL 证书配置和 `listen 443 ssl`，HTTPS 请求会被拒绝或超时。
   - **所在位置**：§1.5.2 (docker-compose.prod.yml) / §3.3.1 (nginx/farmeye.conf)
   - **改进建议**：补充 Nginx SSL 配置 + Certbot/Let's Encrypt 方案；或移除 `"443:443"` 映射和 UFW 规则并注明 HTTPS 不在 v1.0 范围内。

7. **docker compose --compatibility 依赖风险未文档化**
   - **问题描述**：方案依赖 `docker compose --compatibility` 将 `deploy.resources.limits.memory` 转换为 cgroup 限制，但该模式在不同 Docker Compose v2 版本间行为不一致，文档未提及此依赖风险，也无部署后验证步骤。
   - **所在位置**：§3.2.2、§3.5、§5.1.3
   - **改进建议**：增加 `--compatibility` 限制说明；在验证部署步骤中添加 `docker inspect` 确认资源限制已生效；考虑使用 Compose v2 原生 `mem_limit`/`mem_reservation` 替代方案。

#### 轻微问题

8. **其他低优先级问题**（不影响本轮 RETRY 判定）
    - Docker 守护进程内存预算未优化
    - Uvicorn 参数硬编码
    - 测试连接串硬编码
    - 备份脚本缺少容器状态检查
