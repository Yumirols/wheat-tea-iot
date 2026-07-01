# 质量审查报告 — a_v2_output_v2.md （迭代 v2 第 2 轮）

> **审查视角**：执行模式 — 审查通用执行产出的可用性  
> **审查范围**：a_v2_output_v2.md 中 7 项历史问题的修复状态 + 新增质量问题  
> **历史问题列表**：H1(.dockerignore)、H2(psycopg2-binary)、H3(Init SQL vs Alembic)、M1(async cleanup)、M2(healthcheck #40)、M3(443 SSL)、M4(--compatibility)  
> **审查日期**：2026-07-01

---

## 一、历史问题修复状态

### H1 (严重): 缺失 .dockerignore — 已修复

**位置**：§1.4.1 .dockerignore 配置（第 310-337 行）

**修复内容**：新增独立章节，提供完整的 `.dockerignore` 规则，包含环境变量排除（`.env*` → `!.env.*.example`）、Python 缓存、Git 目录、文档、日志、备份的排除规则。

**验证**：
- `.env*` + `!.env.*.example` 模式可正确排除敏感 env 文件同时保留示例模板；
- 模式语法符合 Docker `.dockerignore` 语义（文件级匹配，无目录前缀冲突）；
- 文件清单 §6.1 同步新增 `.dockerignore` 条目；
- §1.4 末尾补充了 `docker build --check .` 的安全验证建议。

**结论**：已修复，可关闭。

---

### H2 (严重): psycopg2-binary 生产部署问题 — 已修复

**位置**：§1.2.1 requirements.txt（第 115 行）；Dockerfile base 阶段（第 240-249 行）

**修复内容**：
- `requirements.txt` 中 `psycopg2-binary` 替换为 `psycopg2~=2.9.0`，注释标注"从源码编译，生产环境推荐；非 psycopg2-binary"；
- Dockerfile base 阶段新增 `build-essential`、`python3-dev`、`libpq-dev` 三项编译依赖；
- 增加镜像体积影响注释（约 150-200 MB）。

**验证**：三处修改一致，编译工具链完整（`build-essential` 提供 gcc 等基础工具集，`python3-dev` 提供 Python C API 头文件，`libpq-dev` 提供 PostgreSQL 客户端库和头文件）。编译依赖链完整。

**结论**：已修复，可关闭。

---

### H3 (严重): Init SQL 与 Alembic 无调和策略 — 已修复

**位置**：§5.4.6 初始基准迁移（第 2350-2376 行）；§5.4.7 entrypoint.sh 首次运行边界处理（第 2378-2386 行）

**修复内容**：
- 明确 init SQL 和 Alembic 的职责边界（init SQL = 首次部署基线，Alembic = 增量 Schema 变更管理）；
- 推荐方案 A（`alembic stamp head`）并给出首次部署后的完整操作命令；
- 方案 B 作为备选保留；
- §5.4.7 说明首次部署边界处理逻辑，entrypoint.sh 优雅处理未 stamp 场景。

**验证**：
- entrypoint.sh（第 2269-2290 行）中 `alembic upgrade head` 失败时不阻塞启动，输出明确警告并指导运维操作；
- 调和策略覆盖了"已有初始迁移脚本"和"尚无初始迁移脚本"两种场景。

**结论**：已修复，可关闭。

---

### M1 (一般): async def 清理函数中使用同步 SQLAlchemy — 已修复

**位置**：§2.4 data_retention.py（第 843-855 行）

**修复内容**：函数定义从 `async def cleanup_expired_data()` 改为普通同步 `def cleanup_expired_data()`。docstring 完整说明设计决策：函数为纯 I/O 密集数据库操作，同步模型更简洁，在 APScheduler ThreadPoolExecutor 中运行不影响 API 事件循环。

**验证**：函数签名确认已改为 `def`（第 843 行），内部调用（`SessionLocal()`、`db.execute()`、`db.commit()`、`db.rollback()`、`db.close()`）均为同步调用，与函数签名一致。修订说明（v8）也明确记录了此修改。

**结论**：已修复，可关闭。

---

### M2 (一般): 健康检查用例 #40 自相矛盾 — 已修复

**位置**：§4.2.6 测试用例 #40（第 1850 行）

**修复内容**：预期结果从"200，`status=degraded`, HTTP 503"统一为"HTTP 503，`status=degraded`"。

**验证**：当前文本为"HTTP 503，`status=degraded`"，与架构文档 §4.10.1 规定的健康检查失败返回 503 一致。

**结论**：已修复，可关闭。

---

### M3 (一般): Nginx 443 端口无 SSL 配置 — 已修复

**位置**：§3.3.1 farmeye.conf（第 1220-1288 行）；§3.3.3 SSL 证书管理（第 1300-1348 行）；docker-compose.prod.yml（第 493-514 行）

**修复内容**：
- Nginx 配置新增 SSL server block：`listen 443 ssl http2`、`ssl_certificate`、`ssl_certificate_key`、`ssl_protocols TLSv1.2 TLSv1.3`、加密套件配置等；
- 新增 §3.3.3 完整章节，包含 Certbot 首次申请步骤、自动续期 hook 脚本、证书文件复制与权限管理、验证命令；
- docker-compose.prod.yml 增加 SSL 证书 volume 挂载；
- UFW 防火墙规则已包含 443 端口。

**验证**：SSL 配置完整（证书路径、协议、加密套件、session cache），续期机制完整（deploy hook 脚本、cp + chmod + nginx -s reload 链）。容器名已从 v8 修订中修正（`farmeye-ginx` → `farmeye-nginx`，第 1336 行）。

**结论**：已修复，可关闭。

---

### M4 (一般): --compatibility 模式资源限制无风险说明 — 已修复

**位置**：§3.5 容器资源限制配置说明（第 1428-1436 行）

**修复内容**：
- 补充 `--compatibility` 在不同 Docker Compose 版本间的行为差异说明（v1 与 v2 的实现细节不同）；
- 增加资源限制验证命令（`docker inspect + jq`）及预期输出；
- 提及 `0` 返回值表示限制未生效时的排查方向和替代方案（原生 `mem_limit`/`mem_reservation` 参数）；
- §3.2.2 部署验证步骤中新增资源限制确认。

**验证**：说明覆盖了风险描述、验证方法和回退路径，修复者可按此操作确认 `--compatibility` 是否生效。

**结论**：已修复，可关闭。

---

## 二、新增质量问题

### 新增 H1 — [严重] entrypoint.sh 迁移失败后静默继续，不区分首次部署与真实迁移错误

**位置**：§5.4.4 entrypoint.sh（第 2278-2286 行）

**问题描述**：
```bash
if alembic upgrade head 2>&1; then
    echo "[FarmEye] 数据库迁移成功"
else
    echo "[FarmEye] 警告: 数据库迁移未完成 - 可能是首次部署，..."
fi
# 无论迁移是否成功，均继续启动 API 服务
exec "$@"
```

`alembic upgrade head` 的退出码仅有"成功(0)"和"失败(非0)"两种，无法区分的失败原因至少包括：
1. **首次部署未 stamp** — 预期行为，不阻塞启动是合理的；
2. **迁移脚本存在 SQL 语法错误**（如错误的 ALTER TABLE 语句）— 真实错误，应阻塞启动；
3. **数据库连接中断** — 应阻塞启动或至少发出高优先级告警；
4. **迁移版本历史冲突**（如多人生成冲突的迁移脚本）— 应阻塞启动。

当前实现将所有失败都等同处理为"可能是首次部署"，会掩盖第 2-4 类真实错误，导致 API 服务在不一致的 Schema 状态下运行，可能造成数据写入错误或查询异常。

**改进建议（至少选一）**：
- **路径 A**：在 entrypoint.sh 中先检查 `alembic current` 的输出。如果 `alembic_version` 表存在且有版本号（说明不是首次部署），则 `alembic upgrade head` 失败时应中止启动并输出详细错误日志；仅当 `alembic current` 明确表明无版本记录（首次部署）时，才允许静默继续；
- **路径 B**：引入环境变量 `FARMEYE_STRICT_MIGRATION=true/false`，生产环境设置 `true` 时迁移失败即中止启动，开发环境可设置为 `false` 容忍首次部署未 stamp 场景。

---

### 新增 M1 — [中] datetime.utcnow() 在 Python 3.13 中已弃用

**位置**：§2.4 data_retention.py（第 859 行）

**问题描述**：
```python
now = datetime.utcnow()
```

Python 3.12 已将 `datetime.utcnow()` 标记为 deprecated（PEP 623），项目目标运行环境为 Ubuntu 25.04 搭载的 **Python 3.13**。运行时会产生 `DeprecationWarning`，且 Python 3.14+ 将正式移除该函数。

**影响**：
- 运行时：日志出现 deprecation warning，不影响当前功能；
- 长期兼容性：Python 3.14 发布后该函数将不存在，代码在升级 Python 版本时会直接报错。

**改进建议**：
将 `datetime.utcnow()` 替换为 `datetime.now(datetime.timezone.utc)` 并调整相关的时间比较逻辑。注意当前数据库字段使用 `DEFAULT CURRENT_TIMESTAMP`（返回时区 naive 的 timestamp），替换后需确保 UTC 时间比较的一致性。具体修改模式：
```python
from datetime import datetime, timezone, timedelta
now = datetime.now(timezone.utc)
# 数据库比较时可能需要使用 now.replace(tzinfo=None) 去除时区信息
```

---

### 新增 M2 — [中] 生产环境 API 端口暴露绕过 Nginx 安全层

**位置**：§1.5.1 docker-compose.yml api 服务（第 352 行）

**问题描述**：
```yaml
api:
  ports:
    - "8000:8000"    # 暴露到宿主机所有网络接口
```

当生产环境使用 Nginx 反向代理时（docker-compose.prod.yml 中的 nginx 服务），API 服务通过 `"8000:8000"` 暴露到宿主机的所有网络接口上。这意味着：
- API 可直接通过 `http://<VPS_PUBLIC_IP>:8000/` 访问，完全绕过 Nginx 的 SSL 终止；
- 失去 Nginx 的请求过滤、速率限制、日志审计等安全能力；
- SSL 证书配置仅在 Nginx 层面生效，直接访问 8000 端口使用明文 HTTP。

**改进建议**：
生产部署中，Nginx 可通过 Docker 内部网络 (`farmeye-net`) 直接以 `http://api:8000` 访问 API 服务。API 容器无需将 8000 端口暴露到宿主机。建议修改为主从模式：

```yaml
# docker-compose.yml（生产配置）：
# 方案 A：监听 localhost 仅（Nginx 在宿主机转发的场景）
# ports:
#   - "127.0.0.1:8000:8000"
# 方案 B：不对外暴露端口，仅由 Nginx 通过 Docker 网络转发（推荐）
# 移除 ports 块，仅通过 networks 暴露
```

考虑到 `start.sh` 的验证步骤（第 1470 行）通过 `localhost:8000` 检查健康状态，方案 A（`127.0.0.1:8000:8000`）可在不破坏验证流程的前提下修复此问题。

---

### 新增 M3 — [中] Nginx 反向代理与 API 端口暴露的文档内部矛盾

**位置**：§3.1.1 UFW 规则（第 1078 行） vs §1.5.1 端口映射（第 352 行） vs §3.3 Nginx 方案

**问题描述**：
文档三处对端口 8000 的处理存在目标冲突：

| 位置 | 配置 | 意图 |
|------|------|------|
| §3.1.1 UFW | `sudo ufw allow 8000/tcp` | 注释"如无 Nginx 时" |
| §1.5.1 docker-compose.yml | `"8000:8000"` | 始终对外暴露 |
| §3.3 Nginx | 全部流量走 Nginx（80/443） | Nginx 为反向代理入口 |

当三份配置同时应用于生产环境时，API 既可通过 Nginx（443/80）访问，也可通过直接请求 8000 端口访问。UFW 规则的注释"如无 Nginx 时"暗示了配置的条件性，但并没有脚本或文档说明如何在不同模式间切换。

**改进建议**：
- 在部署脚本（`deploy/scripts/`）中增加条件判断：当启用 Nginx 时，自动注解 UFW 的 8000 规则或移除 port mapping；
- 或者提供两组明确的生产部署模板（"有 Nginx" / "无 Nginx"），并通过注释/文档提示运维人员按需调整。

---

### 新增 M4 — [低] 重复的"## 6. 附录"二级标题

**位置**：§6（第 2391-2392 行）

**问题描述**：文件中连续出现两个 `## 6. 附录` 标题，为 Markdown 渲染时的格式异常。

```markdown
## 6. 附录

## 6. 附录
```

**影响**：仅影响 Markdown 渲染的目录结构和视觉展示，不影响文档可读性和实质内容。

**改进建议**：删除其中一个重复标题。

---

### 新增 M5 — [低] 本地开发路径缺少 psycopg2 编译依赖说明

**位置**：§1.1.1 本地开发环境配置（第 84 行）

**问题描述**：
§1.1.1 推荐本地开发者执行 `pip install -r server/requirements.txt`，但该文件中的 `psycopg2~=2.9.0`（非 binary 版本）需要在宿主机安装 `libpq-dev` 和编译工具链才能正常安装。文档未就此给出提示。

开发者按文档步骤操作可能遇到 `Error: pg_config executable not found.` 等编译错误。

**改进建议**：
- 在 §1.1.1 的 pip 安装步骤后增加注释，说明 `psycopg2` 需要本地 PostgreSQL C 库头文件；
- 对于 Linux 用户给出 `sudo apt-get install libpq-dev build-essential python3-dev` 的安装命令；
- 对于无法安装编译依赖的开发者（Windows/macOS），提示可临时使用 `pip install psycopg2-binary` 替代开发（仅限本地开发环境）。

---

## 三、汇总

| 严重程度 | 编号 | 问题 | 位置 | 状态 |
|---------|------|------|------|------|
| 严重 | H1 | entrypoint.sh 迁移失败静默继续，不区分首次部署与真实迁移错误 | §5.4.4 L2278-2286 | 新增 |
| 中 | M1 | `datetime.utcnow()` Python 3.13 已弃用 | §2.4 L859 | 新增 |
| 中 | M2 | 生产环境 API 端口暴露绕过 Nginx 安全层 | §1.5.1 L352 | 新增 |
| 中 | M3 | Nginx + API 端口矛盾的文档内部矛盾 | §3.1.1 L1078 / §1.5.1 L352 / §3.3 | 新增 |
| 低 | M4 | 重复的"## 6. 附录"标题 | §6 L2391-2392 | 新增 |
| 低 | M5 | 本地开发缺少 psycopg2 编译依赖说明 | §1.1.1 L84 | 新增 |

**历史问题修复总结**：7 项历史问题（H1-H3, M1-M4）全部已修复，修复验证通过。
**本轮新增问题**：1 项严重 + 3 项中等 + 2 项低，共计 6 项。
