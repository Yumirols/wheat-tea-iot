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

---

## 四、质询回应与报告修订

### 质询项 CH1 — N1 的 Docker Compose v2 profile 行为证据支撑

**质询结论：部分接受。** 原报告对 `docker compose up -d api` 在 profile 机制下行为的断言确实在证据充分性上存在不足，需修订 N1 的表述。

**对质询的逐项分析**：

1. **未引用 Docker Compose 官方文档或规范版本号** — 成立。原报告仅以「当前 Docker Compose v2 语义」概括，未指定版本区间。Docker Compose v2 中显式命名服务 (`docker compose up <service>`) 与 profile 过滤的交互行为在各子版本间确实存在差异：部分早期 v2 版本（v2.0.x–v2.22.x）中，显式指定服务名会绕过 profile 过滤，导致 `docker compose up api` 无论 profile 设置如何均启动服务；较新版本（v2.23.0+）则统一行为，显式命名服务也不再绕过 profile。原报告未明确此版本依赖，削弱了断言的确定性。

2. **未提供实测结果** — 成立。原报告未说明测试环境或实测结果。

3. **未检查被审查文档中的版本约束** — 成立。被审查文档 `a_v3_copy_from_v2.md` 中未指定 Docker Compose 版本号，在 §1.5 的 docker-compose.yml 中使用了 `version: "3.9"`（compose 文件格式版本，非 Docker Compose 工具版本）。原报告也未主动确认此信息。

**修订处理**：

N1 的断言强度下调。修改如下：

- **问题描述**：从「**不会启动**」的确定性表述改为「**可能不会启动**，具体行为取决于 Docker Compose v2 子版本」，并补充版本依赖说明。
- **影响范围**：从「5 个测试用例级联失败」的确定性判断改为「在较新 Docker Compose v2 (v2.23.0+) 下会导致 5 个测试用例级联失败；在早期版本下该问题不存在，但依赖未文档化的行为」。
- **严重程度评估**：从 M2（一般）**下调至 L1（轻微）**。原因：问题仅在特定版本范围内真实存在；且即使不修复，用户按照文档操作在早期版本下仍能正常工作。
- **修复建议**：保留建议（添加 `--profile production`），但补充为「最佳实践，确保在所有 Docker Compose v2 子版本下行为一致，而非仅在特定版本中依赖隐式行为」。

修订后的 N1 如下：

---

#### N1（修订后）：Docker 测试命令未显式指定 profile，在不同 Docker Compose v2 版本下行为不一致

**所在位置**：§4.4.2 Docker 测试用例表，第 1908 行（测试用例 #1）

**问题描述**：自 v6 迭代引入 profile 机制后，`api` 服务具有 `profiles: ["production"]` 属性（§1.5.1 第 373 行）。`docker compose up -d api` 命令在 Docker Compose v2 不同子版本下的行为存在差异：
- v2.23.0+：显式命名服务不再绕过 profile 过滤，不带 `--profile production` 时 `api` 服务**不会启动**
- v2.0.x–v2.22.x：显式命名服务可能绕过 profile 过滤，`api` 服务仍可启动

被审查文档未指定 Docker Compose 工具版本，因此无法确定用户在目标环境中会遭遇哪种行为。依赖未文档化的隐式行为增加了部署风险。

**影响范围**：在 v2.23.0+ 下，测试用例 #1 失败后，依赖 API 容器的 #2、#5、#6、#7 将级联失败。在早期版本下无此问题。

**严重程度评估**：轻微（L1）。问题范围受限于特定 Docker Compose 版本，且不影响生产部署。但属于未文档化的隐式依赖。

**修复建议**：将测试命令明确添加 `--profile production`：`docker compose up -d --profile production api`。此修改确保在所有 Docker Compose v2 子版本下行为一致，属于最佳实践。

---

### 质询项 CH2 — N2 的 `set_section_option` 修复建议未验证文档上下文

**质询结论：不接受。** 原报告的修复建议在被审查文档的上下文中是有效的，但质询指出的验证过程缺失是有道理的，需要补充上下文确认说明。

**对质询的逐项分析**：

1. **质疑 `config` 对象来源** — 不成立。被审查文档 §5.4.5 第 2333 行代码明确为 `config = context.config`，其中 `context` 来自 `from alembic import context`（第 2332 行）。这是 Alembic 的标准用法，`context.config` 返回标准的 `alembic.config.Config` 实例。

2. **质疑 `alembic` section 是否存在** — 不成立。被审查文档 §5.4.2 第 2202 行明确使用 `[alembic]` 作为 ini 文件 section 标题，这是 Alembic 的默认 section 名称。`config.set_section_option("alembic", ...)` 在标准 Alembic 配置中始终有效。

**但质询在方法层面有合理之处**：原报告未在被审查文档中明确引用以上两处确认代码的所在行，增强了读者对上下文准确性的疑虑。

**修订处理**：

N2 的问题判定和修复建议保持不变。在问题描述中补充上下文确认代码引用：
- `config = context.config`（§5.4.5 第 2333 行）— 标准 Alembic Config 对象
- `[alembic]`（§5.4.2 第 2202 行）— 标准 section 名称
- 修复建议 `config.set_section_option("alembic", "sqlalchemy.url", database_url)` 在确认的上下文中有效

---

### 质询后报告修订摘要

| 问题 | 原判定 | 质询后判定 | 变更内容 |
|------|--------|-----------|---------|
| N1 (profile 遗漏) | M2 证据不足 | L1 降低严重度，软化断言 | 严重度 M2→L1；从确定性断言改为版本范围限定的条件性判断；去除级联失败绝对化表述；修复建议升级为最佳实践 |
| N2 (deprecated API) | L1 建议可行 | L1 判定不变，补充确认引用 | 增补上下文代码行引用以增强建议可信度 |

前轮 6 项修复验证结论不受质询影响，全部维持。
