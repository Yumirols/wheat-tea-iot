# 执行报告（v1）

## 概述

修复 FarmEye Guard 两个测试失败根因：ORM DDL 生成 Bug（3 个模型文件共 9 处 server_default + 3 处 import）和设备注册业务逻辑缺陷（1 个服务文件 3 处修改）。所有文件已通过 Python 语法检查。

## 产出清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 修改 | `server\app\models\sensor.py` | 追加 `text` import + 3 处 `server_default=text(...)` |
| 修改 | `server\app\models\disease.py` | 追加 `text` import + 2 处 `server_default=text(...)` |
| 修改 | `server\app\models\control.py` | 追加 `text` import + 4 处 `server_default=text(...)` |
| 修改 | `server\app\services\sensor_service.py` | docstring 修正 + 新建设备 `online=True` + else 分支追加 `device.online = True` |

## 执行过程

### 问题1：ORM DDL 生成 Bug

**根因**：SQLAlchemy 将字符串字面量传给 `server_default` 时，DDL 中生成为 `DEFAULT 'CURRENT_TIMESTAMP'`（带单引号），数据库拒绝执行。使用 `text("CURRENT_TIMESTAMP")` 可生成正确的 `DEFAULT CURRENT_TIMESTAMP`。

**修改策略**：
1. 在 `sensor.py` 第 8 行、`disease.py` 第 6 行、`control.py` 第 8 行的 `from sqlalchemy import` 中追加 `text`
2. 将所有 `server_default="CURRENT_TIMESTAMP"` 替换为 `server_default=text("CURRENT_TIMESTAMP")`，共 9 处：
   - `sensor.py`：第 21、36、74 行（3 处）
   - `disease.py`：第 18、35 行（2 处）
   - `control.py`：第 21、29、42、46 行（4 处）

### 问题2：设备注册业务逻辑缺陷

**根因**：新建设备时 `online=False` 导致设备上报数据后 `online` 状态未正确设为 `True`，此外 docstring 描述与实际行为不一致。

**修改内容**：
1. docstring 第 68 行：`online=False` 改为 `online=True`
2. 新建设备分支第 78 行：`online=False` 改为 `online=True`
3. else 分支（已有设备）第 86 行：在 `device.last_seen = datetime.utcnow()` 后增加 `device.online = True`

**验证**：所有 4 个修改文件均通过 `python -m py_compile` 语法检查，import 完整性确认无误。

## 偏差说明

无
