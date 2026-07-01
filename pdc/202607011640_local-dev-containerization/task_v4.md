# 任务指令（v4）

## 动作
NEW

## 任务描述
直接修复 T3（FastAPI 应用基础框架）遗留的 3 个技术性问题，完成 T3 的有效产出。T3 在 Do 审议中达到 6 轮上限被 BLOCKED，审查共发现 3 个问题，但产出代码主体正确，仅需精准修复。

### 预期产出

1. **修复 `server/app/models/sensor.py`**
   - 为 `SensorDailyAggregation` 添加 `UniqueConstraint('device_id', 'agg_date')` 表级约束
   - 需在文件顶部增加 `from sqlalchemy import UniqueConstraint` 导入
   - 名称使用 `uq_sensor_daily_agg_device_date`

2. **修复 `server/app/main.py`**
   - 删除第 9 行 `from contextlib import suppress` 未使用的导入

3. **修复执行报告 `do_v3.md`**
   - `sensor_daily_aggregation` 字段计数：18 → 17（DDL 和模型实际均为 17 个字段）
   - `devices` 字段计数：8 → 9（DDL 和模型实际均为 9 个字段）
   - 维持报告其余内容不变

4. **Python 导入验证**
   - 在 `server/` 目录下执行 `python -c "from app.db.base import Base; from app.models import *; print('OK')"` 确认所有模块可正常导入
   - 注意：需将 `server/` 添加到 PYTHONPATH，或从 `server/` 目录运行

## 选择理由
T3 的审议已超限但产出代码基础基本正确，仅剩 3 个具体问题需要修复。创建新的直接修复任务（T4）绕过卡住的审议循环，以最小的变更完成 T3 目标。T4 不需要复杂的设计审议或重做，而是直接应用已知的修复方案。

## 任务上下文
- 所有修复目标文件均已被审议确认存在且内容正确，仅在细节上存在问题
- 修复不改变架构设计，不添加新功能，仅修正约束完整性、代码整洁度和报告准确性
- 修复后的代码需与 `server/init/01_create_tables.sql` 的 DDL 保持一致

### 具体修复背景

**问题 1：UniqueConstraint 缺失**
`SensorDailyAggregation` ORM 模型缺少 `UNIQUE (device_id, agg_date)` 约束，该约束在 `01_create_tables.sql` 第 119 行定义。缺少该约束会导致 Alembic autogenerate 可能生成错误迁移来删除数据库中的该约束，造成数据完整性风险。

**问题 2：未使用的 import**
`main.py` 第 9 行 `from contextlib import suppress` 在整个文件中未被引用，属于死代码。

**问题 3：报告字段计数**
`do_v3.md` 第 55 行的产出清单中：
- `sensor_daily_aggregation` 标注 18 字段，实际 DDL 和模型均为 17 字段
- `devices` 标注 8 字段，实际 DDL 和模型均为 9 字段

## 已有产出上下文
### 当前代码状态

以下文件已被 T3 创建且内容正确（无需修改）：

| 路径 | 说明 |
|------|------|
| `server/app/__init__.py` | 空 init |
| `server/app/config.py` | Pydantic Settings 配置，13 个配置字段 |
| `server/app/db/__init__.py` | 空 init |
| `server/app/db/base.py` | SQLAlchemy DeclarativeBase + MetaData 命名约定 |
| `server/app/db/session.py` | 数据库会话管理，pool_size=2, max_overflow=2 |
| `server/app/core/__init__.py` | 空 init |
| `server/app/core/logging_config.py` | 日志配置，控制台+文件轮转 |
| `server/app/models/__init__.py` | 导出所有 5 个模型类 |
| `server/app/models/sensor.py` | **需修复**：SensorSnapshot + SensorDailyAggregation |
| `server/app/models/disease.py` | DiseaseRecord（13 字段，完整） |
| `server/app/models/control.py` | ControlLog + Device（完整） |
| `server/app/schemas/__init__.py` | 导出所有 8 个 Schema 类 |
| `server/app/schemas/common.py` | ResponseModel(Generic[T]), PaginationParams, PaginationMeta |
| `server/app/schemas/sensor.py` | SensorSnapshotRead, SensorHistoryResponse |
| `server/app/schemas/disease.py` | DiseaseRecordRead, DiseaseStatsResponse |
| `server/app/schemas/command.py` | CommandCreate, CommandRead, CommandResponse |
| `server/app/api/__init__.py` | 空 init |
| `server/app/api/v1/__init__.py` | 空 init |
| `server/app/services/__init__.py` | 空 init |
| `server/app/main.py` | **需修复**：FastAPI 入口 + 健康检查 |
| `server/alembic/env.py` | 已更新 target_metadata |

### 工作目录路径
`E:\dev\wheat-tea-iot\pdc\202607011640_local-dev-containerization`
