# 迭代 v3 指令 — 基于组件B诊断报告

> **生成方式**：再审议框架输入解析Agent（parser.md）
> **迭代轮次**：3
> **上一轮产出**：a_v2_output_v2.md（v8，2578 行）
> **评审依据**：b_v2_diag_v1.md（质量审查报告）

---

## 模式

MODE:execution

## 编辑模式

EDIT_MODE:COPY_AND_EDIT

上一轮产出文件共计 2578 行，超过 1000 行阈值。建议基于 a_v2_output_v2.md 建立副本，在副本基础上进行针对性编辑，避免从头重写。

---

## 需要修复的问题

以下问题来自组件B诊断报告（b_v2_diag_v1.md），按严重程度排列。所有问题均需在本轮迭代中得到修复。

### 一、严重问题

#### 问题 1（新增 H1）：entrypoint.sh 迁移失败后静默继续，不区分首次部署与真实迁移错误

**位置**：§5.4.4 entrypoint.sh（第 2278-2286 行）

**问题描述**：
entrypoint.sh 中 `alembic upgrade head` 的退出码仅有"成功(0)"和"失败(非0)"两种，但无法区分的失败原因至少包括：
1. 首次部署未 stamp — 预期行为，不阻塞启动是合理的；
2. 迁移脚本存在 SQL 语法错误（如错误的 ALTER TABLE 语句）— 真实错误，应阻塞启动；
3. 数据库连接中断 — 应阻塞启动或至少发出高优先级告警；
4. 迁移版本历史冲突（如多人生成冲突的迁移脚本）— 应阻塞启动。

当前实现将所有失败都等同处理为"可能是首次部署"，会掩盖第 2-4 类真实错误。

**修复要求**：
至少选择以下路径之一进行修复：

- **路径 A（推荐）**：在 entrypoint.sh 中先检查 `alembic current` 的输出。如果 `alembic_version` 表存在且有版本号（说明不是首次部署），则 `alembic upgrade head` 失败时应中止启动并输出详细错误日志；仅当 `alembic current` 明确表明无版本记录（首次部署）时，才允许静默继续。
- **路径 B**：引入环境变量 `FARMEYE_STRICT_MIGRATION=true/false`，生产环境设置 `true` 时迁移失败即中止启动，开发环境可设置为 `false` 容忍首次部署未 stamp 场景。

---

### 二、中等问题

#### 问题 2（新增 M1）：datetime.utcnow() 在 Python 3.13 中已弃用

**位置**：§2.4 data_retention.py（第 859 行）

**问题描述**：
```python
now = datetime.utcnow()
```
Python 3.12 已将 `datetime.utcnow()` 标记为 deprecated（PEP 623），Ubuntu 25.04 搭载 Python 3.13，运行时会产生 `DeprecationWarning`，且 Python 3.14+ 将正式移除该函数。

**修复要求**：
将 `datetime.utcnow()` 替换为 `datetime.now(datetime.timezone.utc)` 并调整相关的时间比较逻辑。注意当前数据库字段使用 `DEFAULT CURRENT_TIMESTAMP`（返回时区 naive 的 timestamp），替换后需确保 UTC 时间比较的一致性。具体修改模式：
```python
from datetime import datetime, timezone, timedelta
now = datetime.now(timezone.utc)
# 数据库比较时可能需要使用 now.replace(tzinfo=None) 去除时区信息
```

#### 问题 3（新增 M2）：生产环境 API 端口暴露绕过 Nginx 安全层

**位置**：§1.5.1 docker-compose.yml api 服务（第 352 行）

**问题描述**：
```yaml
api:
  ports:
    - "8000:8000"    # 暴露到宿主机所有网络接口
```
当生产环境使用 Nginx 反向代理时，API 服务通过 `"8000:8000"` 暴露到宿主机的所有网络接口上，可直接绕过 Nginx 的 SSL 终止、请求过滤等安全层。

**修复要求**：
将端口映射改为 `"127.0.0.1:8000:8000"`（监听 localhost 仅），使 Nginx 可通过 Docker 内部网络以 `http://api:8000` 访问 API 服务，同时保留 `start.sh` 中通过 `localhost:8000` 检查健康状态的验证流程。同时确保 `start.sh` 和 `stop.sh` 脚本中的健康检查继续可用。

#### 问题 4（新增 M3）：文档三处对端口 8000 的处理存在目标冲突

**位置**：§3.1.1 UFW 规则（第 1078 行） vs §1.5.1 端口映射（第 352 行） vs §3.3 Nginx 方案

**问题描述**：
| 位置 | 配置 | 意图 |
|------|------|------|
| §3.1.1 UFW | `sudo ufw allow 8000/tcp` | 注释"如无 Nginx 时" |
| §1.5.1 docker-compose.yml | `"8000:8000"` | 始终对外暴露 |
| §3.3 Nginx | 全部流量走 Nginx（80/443） | Nginx 为反向代理入口 |

当三份配置同时应用于生产环境时，API 既可通过 Nginx（443/80）访问，也可通过直接请求 8000 端口访问。

**修复要求**：
确保三处配置在逻辑上协调一致。推荐做法：
- UFW 规则中注释掉 8000 端口开放（或添加明确条件说明），因为生产环境中 Nginx 处理所有外部流量；
- 如问题 3 的修复要求所示，API 端口映射改为 `127.0.0.1:8000:8000`；
- 在部署脚本或文档中增加模式切换说明（"有 Nginx" / "无 Nginx" 两种场景的差异配置指引）。

---

### 三、轻微问题

#### 问题 5（新增 M4）：重复的"## 6. 附录"二级标题

**位置**：§6（第 2391-2392 行）

**问题描述**：
文件中连续出现两个 `## 6. 附录` 标题，为 Markdown 渲染时的格式异常。

**修复要求**：
删除其中一个重复的 `## 6. 附录` 标题。

#### 问题 6（新增 M5）：本地开发路径缺少 psycopg2 编译依赖说明

**位置**：§1.1.1 本地开发环境配置（第 84 行）

**问题描述**：
§1.1.1 推荐本地开发者执行 `pip install -r server/requirements.txt`，但该文件中的 `psycopg2~=2.9.0`（非 binary 版本）需要在宿主机安装 `libpq-dev` 和编译工具链才能正常安装。文档未就此给出提示。

**修复要求**：
- 在 §1.1.1 的 pip 安装步骤后增加注释，说明 `psycopg2` 需要本地 PostgreSQL C 库头文件；
- 对于 Linux 用户给出 `sudo apt-get install libpq-dev build-essential python3-dev` 的安装命令；
- 对于无法安装编译依赖的开发者（Windows/macOS），提示可临时使用 `pip install psycopg2-binary` 替代开发（仅限本地开发环境）。

---

## 修复基线

以上 6 项问题（1 严重 + 3 中等 + 2 低）均基于 a_v2_output_v2.md（v8）进行修复。

- 历史 v2 轮次（a_v2_output_v2.md 版本）已修复的 7 项历史问题（H1-H3, M1-M4）视为基线，不可回退。
- 新增的修复不得破坏或回退任何已修复的历史问题。
- 修复应遵循"最小改动原则"：仅修改问题涉及的精确位置，不进行无关重构或范围扩展。

## 产出物要求

1. 产出文件应为完整的方案文档（包含所有章节），基于 a_v2_output_v2.md 编辑生成。
2. 修改位置应清晰可追溯；在修订说明（v9）中逐条记录本轮修复内容。
3. 所有配置和脚本示例应与修复后的状态保持一致。
