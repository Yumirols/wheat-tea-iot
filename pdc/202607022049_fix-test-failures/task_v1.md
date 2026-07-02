# 任务指令（v1）

## 动作
RETRY

## 任务描述
修复 FarmEye Guard 所有测试失败问题，包括两个独立缺陷：ORM DDL 生成 Bug 和设备注册业务逻辑缺陷。

### 问题1：ORM DDL 生成 Bug（数据库集成测试 38 ERROR at setup）

共 **3 个模型文件、9 处 `server_default` 字段定义、3 处 import 行** 需修改：

#### 1. server\app\models\sensor.py
- 第 8 行：在 `from sqlalchemy import` 行追加 `text`
- 第 21 行：`server_default="CURRENT_TIMESTAMP"` → `server_default=text("CURRENT_TIMESTAMP")`
- 第 36 行：同上
- 第 74 行：同上

#### 2. server\app\models\disease.py
- 第 6 行：在 `from sqlalchemy import` 行追加 `text`
- 第 18 行：`server_default="CURRENT_TIMESTAMP"` → `server_default=text("CURRENT_TIMESTAMP")`
- 第 35 行：同上

#### 3. server\app\models\control.py
- 第 8 行：在 `from sqlalchemy import` 行追加 `text`
- 第 21 行：`server_default="CURRENT_TIMESTAMP"` → `server_default=text("CURRENT_TIMESTAMP")`
- 第 29 行：同上
- 第 42 行：同上
- 第 46 行：同上

### 问题2：设备注册业务逻辑缺陷（E2E 步骤6-7 FAIL）

修改 `server\app\services\sensor_service.py` 中的 `ensure_device_exists()` 函数：

1. 第 69 行 docstring：`online=False` → `online=True`（更新注释以反映正确行为）
2. 第 78 行新建设备分支：`online=False` → `online=True`
3. 第 86 行 else 分支：在 `device.last_seen = datetime.utcnow()` 后增加 `device.online = True`

## RETRY 说明
初审（plan_review_v1_r1）指出：
1. 原 v1 计划缺少问题2，现已合并纳入本轮
2. 原计数"10 处"有误，实际为 9 处（已修正）
3. 补充验证环节：修改后执行 Python 语法检查和相关测试

## 选择理由
两个问题均为测试失败根因：
- 问题1 导致数据库集成测试 38 ERROR at setup：SQLAlchemy 将字符串字面量作为 `server_default` 时会在 DDL 中生成带单引号的 `DEFAULT 'CURRENT_TIMESTAMP'`，数据库拒绝执行。使用 `text("CURRENT_TIMESTAMP")` 可确保生成正确的 `DEFAULT CURRENT_TIMESTAMP`
- 问题2 导致 E2E 测试步骤6-7 FAIL：设备上报数据时 `online` 状态未被正确设为 `True`，此外 docstring 描述与实际行为不一致

两个问题修改量均较小（问题1: 9 处 server_default + 3 处 import；问题2: 1 个文件 3 处小修改），合并一轮处理避免碎片化。

## 任务上下文
- 问题1 中 `text` 函数来自 `sqlalchemy` 包，需要在各文件 import 语句中追加
- 问题1 变更模式高度重复，所有 `server_default="CURRENT_TIMESTAMP"` 都应统一替换
- 问题2 涉及 `sensor_service.py` 中 `ensure_device_exists()` 函数的三个位置：docstring、新建设备分支（line 78）、已有设备分支（line 86）
- `server_default` 计数：sensor.py 共 3 处（第21/36/74行）、disease.py 共 2 处（第18/35行）、control.py 共 4 处（第21/29/42/46行），合计 9 处

## 已有产出上下文
- `task.md`：任务描述文件，包含问题定位和具体的修改清单
- `plan.md`：已更新为 R2 RETRY 状态
- 源文件处于原始状态，尚未做任何修改

## 验证方法
1. 修改后执行 Python 语法检查：`python -m py_compile <each_modified_file>`
2. 确认 import 完整性：每个文件能正确导入 `text` 且无 `ModuleNotFoundError`
3. 代码审查确认 9 处 `server_default` 全部替换、3 处 import 追加完成、3 处 online 修正到位
4. 后续由集成测试和 E2E 测试运行确认（独立执行）
