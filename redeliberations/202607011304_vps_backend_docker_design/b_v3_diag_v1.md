# 质量审查报告 — v3 迭代（v9 文档）

审查范围：a_v3_copy_from_v2.md  
审查视角：执行模式 — 审查通用执行产出的可用性  
审查重点：第二轮 6 项问题修复验证 + 新增质量问题

---

## 一、前轮问题修复验证

### 1. S1（严重）：entrypoint.sh 首次迁移失败后静默继续

**结论：已修复。**

§5.4.4 entrypoint.sh 代码实现了两阶段判断：
- 阶段一：执行 `alembic current` 检测 `alembic_version` 表是否存在版本号，输出 12 位十六进制散列值时设 `STRICT_MIGRATION=true`
- 阶段二：`alembic upgrade head` 失败时，`STRICT_MIGRATION=true` 则 `exit 1` 阻塞启动；`false` 时警告后继续（首次部署预期行为）

§5.4.7 的说明文档与代码逻辑一致。

### 2. M1（一般）：datetime.utcnow() 弃用警告

**结论：已修复。**

§2.4 代码中：
- `from datetime import datetime, timedelta` 改为 `from datetime import datetime, timedelta, timezone`
- `datetime.utcnow()` 替换为 `datetime.now(timezone.utc)`
- 传入数据库前通过 `.replace(tzinfo=None)` 去除时区信息，与时区 naive 的 `TIMESTAMP` 列保持一致

### 3. M2（一般）：API 端口仍暴露绕过 Nginx

**结论：已修复。**

§1.5.1 docker-compose.yml 中 `api` 服务的端口映射从 `"8000:8000"` 改为 `"127.0.0.1:8000:8000"`，仅监听 localhost。Nginx 通过 Docker 内部网络 `farmeye-net` 以 `http://api:8000` 访问。`api-dev` 保留原 `"8000:8000"` 不变（开发模式无 Nginx）。

### 4. M3（一般）：Nginx 与 API 端口文档矛盾

**结论：已修复。**

§3.1.1 UFW 规则中 `sudo ufw allow 8000/tcp` 已注释，标注"仅在无 Nginx 时开放"。结合端口映射改为 `127.0.0.1:8000:8000`，三处配置（UFW、端口映射、Nginx 反向代理）逻辑协调一致：UFW 不开放 8000、端口仅监听 localhost、Nginx 为唯一外部入口。

### 5. L1（轻微）：重复的 "## 6. 附录" 二级标题

**结论：已修复。**

文档中仅存一处 `## 6. 附录` 标题（第 2421 行）。

### 6. L2（轻微）：本地开发缺少 psycopg2 编译依赖说明

**结论：已修复。**

§1.1.1 中 `pip install` 步骤后增加了 blockquote，说明 `psycopg2~=2.9.0` 需要宿主机安装 `libpq-dev`、`build-essential`、`python3-dev`；Windows/macOS 开发者可使用 `psycopg2-binary` 替代（仅本地开发）；生产环境在 Docker base 阶段预装编译依赖。

---

## 二、新增质量问题

### N1（一般）：Docker 测试用例中 `docker compose up -d api` 缺少 `--profile production` 参数

**所在位置**：§4.4.2 Docker 测试用例表，第 1908 行（测试用例 #1）

**问题描述**：自 v6 迭代引入 profile 机制后，`api` 服务在 docker-compose.yml 中具有 `profiles: ["production"]` 属性（§1.5.1 第 373 行）。不带 `--profile production` 参数的 `docker compose up -d api` 命令在当前 Docker Compose v2 语义下**不会启动**具有 `production` profile 的 `api` 服务。这导致 Docker 测试用例 #1 的启动命令不可执行。

**影响范围**：测试用例 #1（API 容器启动）失败后，依赖 API 容器的 #2（健康检查）、#5（容器间通信）、#6（数据库访问）、#7（端口映射）将级联失败。整组 Docker 测试（§4.4.2）除 #3、#4、#8、#9、#10 外均受影响。

**严重程度评估**：一般（M2）。不影响生产部署（所有部署命令已正确使用 `--profile production`），但会在测试环节造成困惑——测试人员按照文档操作将看到 API 容器未启动的错误，且错误原因不直观。

**修复建议**：将 §4.4.2 中所有涉及启动 `api` 服务的命令从 `docker compose up -d api` 更新为 `docker compose up -d --profile production api`；或补充说明 Docker 测试要求使用 production profile，建议在执行 Docker 测试前先执行完整的生产部署命令（参考 §3.2.2 的 `-f docker-compose.yml -f docker-compose.prod.yml --profile production --compatibility up -d --build`）。
如果需要保持测试命令简洁，也可以将测试环境的 Docker 启动命令单独提炼为一条前置命令并在测试用例表中引用该命令。

### N2（轻微）：§5.4.5 env.py 使用已弃用的 set_main_option API

**所在位置**：§5.4.5，第 2337-2338 行

**问题描述**：`config.set_main_option("sqlalchemy.url", database_url)` 在 Alembic 1.13+ 中属于遗留 API。虽然功能正常且当前无运行期警告，但社区主流实践中已推荐 `config.set_section_option("alembic", "sqlalchemy.url", database_url)`。

**严重程度评估**：轻微（L1）。不影响功能，仅技术债务。

**修复建议**：将 `config.set_main_option("sqlalchemy.url", database_url)` 替换为 `config.set_section_option("alembic", "sqlalchemy.url", database_url)`。

---

## 三、整体评价

第二轮审查报告的 6 项问题已全部修复，修复质量符合预期：

| 原问题 | 严重度 | 修复状态 | 验证依据 |
|--------|--------|---------|---------|
| entrypoint.sh 迁移失败静默继续 | S1 | 已修复 | §5.4.4 两阶段判断 + exit 1 |
| datetime.utcnow() 弃用 | M1 | 已修复 | §2.4 timezone.utc |
| API 端口暴露绕过 Nginx | M2 | 已修复 | §1.5.1 127.0.0.1:8000 |
| Nginx/API 端口矛盾 | M3 | 已修复 | §3.1.1 注释 8000 规则 |
| 重复附录标题 | L1 | 已修复 | 唯一标题 |
| psycopg2 依赖说明 | L2 | 已修复 | §1.1.1 blockquote |

新增质量问题 2 项：1 项一般（Docker 测试 profile 遗漏）、1 项轻微（deprecated API）。其中 N1 属于 v6 profile 机制引入后的连锁遗漏，建议在下次迭代中优先修复。
