# 执行审查报告（v3 r1）

## 审查结果
REJECTED

## 发现

### [一般] SensorDailyAggregation 模型缺失 UNIQUE(device_id, agg_date) 约束

**问题描述**: `server/app/models/sensor.py` 中的 `SensorDailyAggregation` 模型没有定义 `__table_args__` 来包含 DDL 中的 `UNIQUE (device_id, agg_date)` 表级约束。对比 `server/init/01_create_tables.sql` 第 119 行：
```sql
UNIQUE (device_id, agg_date)
```
该约束在 DDL 中存在，但 ORM 模型中缺失。

**为什么是问题**: task_v3.md 明确要求"所有字段类型、精度、约束与设计文档中的 DDL 完全一致"。此外，Alembic 的 `autogenerate` 模式会对比数据库实际 schema 与模型 `metadata`。如果约束存在于数据库中（由 DDL 创建）但不在模型 `metadata` 中，Alembic 可能生成错误的迁移脚本来删除该约束，导致数据完整性风险。

**期望修正方向**: 在 `SensorDailyAggregation` 模型中添加 `__table_args__`:
```python
__table_args__ = (
    UniqueConstraint('device_id', 'agg_date', name='uq_sensor_daily_agg_device_date'),
)
```
并在文件顶部增加 `from sqlalchemy import UniqueConstraint` 导入。

---

### [轻微] main.py 中存在未使用的 import

**问题描述**: `server/app/main.py` 第 9 行：
```python
from contextlib import suppress
```
该导入在整个文件中未被使用。

**为什么是问题**: 无实际影响的死代码，但增加了不必要的导入，降低代码整洁度。

**期望修正方向**: 删除 `from contextlib import suppress` 这一行。

---

### [轻微] 执行报告中字段数量不准确

**问题描述**: 执行报告（do_v3.md）第 55 行的产出清单表格中：
- `sensor_daily_aggregation` 标注为 18 个字段，实际 DDL 和模型均为 17 个字段
- `devices` 标注为 8 个字段，实际 DDL 和模型均为 9 个字段

**为什么是问题**: 报告数据与实现不一致，降低报告可信度。不影响产出本身的正确性。

**期望修正方向**: 更新执行报告中的字段计数，使之与实际文件一致。

## 修改要求

1. **SensorDailyAggregation 模型**: 添加 `UniqueConstraint('device_id', 'agg_date')` 表级约束，保持与 DDL 一致。
2. **main.py**: 删除未使用的 `from contextlib import suppress` 导入。
3. **执行报告**: 修正 `sensor_daily_aggregation` 和 `devices` 表的字段计数。
