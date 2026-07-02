# 执行审查报告（v3 r1）

## 审查结果
REJECTED

## 发现

### [一般] 健康检查端点缺少 2 秒查询超时

**文件**: `server/app/main.py:83-92`

**问题**: task_v3.md 第 99 行明确要求健康检查的数据库查询必须设置 2 秒超时（"超时时间 2 秒，连接失败时 status='degraded', HTTP 状态码 503"）。当前实现仅使用了 try/except 捕获调用异常，但未对 `db.execute(text("SELECT 1"))` 设置任何超时控制。当数据库 TCP 连接挂起（如 PostgreSQL 进程僵死或网络分区）时，健康检查端点会卡住直到底层 TCP 超时（通常 30-120 秒），使健康检查失去快速检测服务降级的意义。

**修正方向**: 在执行数据库查询前设置超时。推荐方式：
- 在 `create_engine()` 中添加 `connect_args={"connect_timeout": 2}` 作为引擎级连接超时，或
- 在健康检查的 `db.execute()` 前执行 `db.execute(text("SET statement_timeout TO 2000"))` 设置语句级超时，或
- 使用 `SessionLocal().execute(text("SELECT 1"), execution_options={"timeout": 2})`

### [轻微] 日志文件路径硬编码为 Docker 容器路径

**文件**: `server/app/core/logging_config.py:14`

**问题**: `LOG_DIR = Path("/app/logs")` 硬编码为 Docker 容器内的绝对路径。task_v3.md 只要求控制台日志，文件日志是额外实现，但路径不可配置。在本地 Windows 开发环境（非 Docker）中，程序启动时尝试创建 `/app/logs` 目录会触发 `PermissionError`（需要管理员权限在根目录创建目录），导致 `setup_logging()` 抛出异常，进而使整个应用启动失败。

**修正方向**:
- 将日志文件路径改为可配置项，通过 `settings` 注入（如新增 `LOG_FILE_PATH: str = "./logs/app.log"`），或
- 移除文件日志落到仅控制台日志（满足任务核心要求），或
- 将默认路径改为相对路径 `./logs`，使其在容器内外均可用

### [轻微] base.py 中命名约定字典定义了但未实际使用

**文件**: `server/app/db/base.py:9-15`

**问题**: `convention` 字典定义了表名和列名的命名约定（如外键命名 `fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s`），但 `class Base(DeclarativeBase)` 没有将这个约定应用到 `Base.metadata`，使得该字典成为死代码。task_v3.md 提到 MetaData 命名约定"可选但推荐"，当前虽定义了但未生效，推荐的做法是：要么移除该未使用的字典，要么将其正确注入 MetaData。

**修正方向**:
```python
from sqlalchemy import MetaData

convention = { ... }
metadata = MetaData(naming_convention=convention)

class Base(DeclarativeBase):
    metadata = metadata
```

## 修改要求

1. **[一般]** `server/app/main.py` — 健康检查端点的数据库查询必须设置 2 秒超时，确保在数据库无响应时健康检查能在 2 秒内返回 `status="degraded"` 和 HTTP 503。
2. **[轻微]** `server/app/core/logging_config.py` — 日志文件路径改为可配置或使用相对路径，确保非 Docker 环境不因目录创建失败而崩溃。
3. **[轻微]** `server/app/db/base.py` — 将 `convention` 字典实际应用于 `Base.metadata`，或移除该字典。
