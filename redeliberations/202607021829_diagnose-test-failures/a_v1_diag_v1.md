# 诊断报告：FarmEye Guard 测试失败根因分析

## 概述

本报告针对 FarmEye Guard 项目中两类测试失败进行根因诊断：

| 问题 | 测试类型 | 失败统计 | 根因类型 |
|------|---------|---------|---------|
| 问题1 | 数据库集成测试 | 38 ERROR at setup | ORM DDL 生成 Bug |
| 问题2 | 端到端联调测试 | 步骤6-7 FAIL | 设备注册业务逻辑缺陷 |

---

## 问题1：数据库集成测试 38 ERROR at setup

### 现象

执行 `pytest tests/integration/ --run-integration -v` 后，38 个测试用例全部在 session-scoped fixture `test_engine` 的 `Base.metadata.create_all(bind=engine)` 阶段报错，无一进入测试逻辑。

### 根因

SQLAlchemy ORM 模型中有 9 处字段使用了字符串形式的 `server_default="CURRENT_TIMESTAMP"`。SQLAlchemy 将字符串值作为字面量渲染到 DDL 中，生成带引号的 SQL：

```sql
timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT 'CURRENT_TIMESTAMP'
```

PostgreSQL 将 `'CURRENT_TIMESTAMP'` 解析为字符串常量而非 SQL 函数调用，抛出：

```
psycopg2.errors.InvalidDatetimeFormat: invalid input syntax for type timestamp: "CURRENT_TIMESTAMP"
LINE 6:  timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT 'CURRENT_TIME...
```

### 证据链

1. **错误输出的 SQL 语句**（`it_output.txt` 第184行）：生成的 DDL 中明确包含 `DEFAULT 'CURRENT_TIMESTAMP'`（带单引号），已在工具的 Read 输出中确认。

2. **生成的 CREATE TABLE 语句片段**（`it_output.txt` 第184行原文）：
   ```
   timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT 'CURRENT_TIMESTAMP'
   ```

3. **PostgreSQL 报错**（`it_output.txt` 第190-192行）：
   ```
   psycopg2.errors.InvalidDatetimeFormat: invalid input syntax for type timestamp: "CURRENT_TIMESTAMP"
   ```

### 受影响的具体位置

共 **3 个模型文件、9 处字段定义**：

| 文件 | 模型类 | 行号 | 字段 | 定义 |
|------|--------|------|------|------|
| `server\app\models\sensor.py` | SensorSnapshot | 21 | `timestamp` | `server_default="CURRENT_TIMESTAMP"` |
| `server\app\models\sensor.py` | SensorSnapshot | 36 | `created_at` | `server_default="CURRENT_TIMESTAMP"` |
| `server\app\models\sensor.py` | SensorDailyAggregation | 74 | `created_at` | `server_default="CURRENT_TIMESTAMP"` |
| `server\app\models\disease.py` | DiseaseRecord | 18 | `timestamp` | `server_default="CURRENT_TIMESTAMP"` |
| `server\app\models\disease.py` | DiseaseRecord | 35 | `created_at` | `server_default="CURRENT_TIMESTAMP"` |
| `server\app\models\control.py` | ControlLog | 21 | `timestamp` | `server_default="CURRENT_TIMESTAMP"` |
| `server\app\models\control.py` | ControlLog | 29 | `created_at` | `server_default="CURRENT_TIMESTAMP"` |
| `server\app\models\control.py` | Device | 42 | `registered_at` | `server_default="CURRENT_TIMESTAMP"` |
| `server\app\models\control.py` | Device | 46 | `created_at` | `server_default="CURRENT_TIMESTAMP"` |

### 为什么 `server_default` 字符串值会被加引号？

SQLAlchemy 对 `server_default` 参数的处理逻辑：
- 传入 **字符串**：SQLAlchemy 将其视为字面值（literal value），在 DDL 中渲染为带单引号的字符串常量
- 传入 **`text("...")` 对象**：SQLAlchemy 将其视为 SQL 表达式（text clause），在 DDL 中渲染为不带引号的裸文本

当前所有 9 处均使用字符串形式，因此产生 `DEFAULT 'CURRENT_TIMESTAMP'`，而非期望的 `DEFAULT CURRENT_TIMESTAMP`。

### 集成测试 Fixture 触发路径

集成测试的 `test_engine` fixture（`server\tests\integration\conftest.py` 第139行）调用了 `Base.metadata.create_all(bind=engine)`。该方法从 ORM 模型定义生成 DDL 语句并执行，从而触发上述 bug。

### 为什么 E2E 测试未受此影响

Docker E2E 环境使用 `server\init\01_create_tables.sql` 进行数据库 schema 初始化。该 SQL 文件中的定义均为正确形式：

```sql
timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
```

不带引号，PostgreSQL 正确识别为函数调用。因此 E2E 测试的数据库操作（Step 2-5）全部通过。这说明 **E2E 环境通过 SQL 初始化绕过了 ORM DDL 生成路径**，并非该 bug 不存在。

---

## 问题2：端到端联调测试 步骤6-7 FAIL

### 现象

E2E 测试 `python tests/integration_run.py`：
- 步骤6 `POST /api/v1/command/send` 返回 `{"status": "offline", "code": 1003}`
- 步骤7 因步骤6失败而跳过

步骤 1-5 全部通过。

### 根因

**直接原因**：设备 `farmeye_guard_ws63` 在自动注册时 `online` 被设置为 `False`，命令下发前的在线状态检查拒绝了下发。

**完整因果链**：

1. **Step 2（上报环境数据）触发设备自动注册**：`POST /api/v1/iotda/properties/report` → `sensor_service.py` 的 `create_snapshot()` → `ensure_device_exists()`

2. **`ensure_device_exists()` 创建 Device 记录**（`server\app\services\sensor_service.py` 第74-84行）：
   ```python
   device = Device(
       device_id=device_id,
       mac_addr=mac_addr,
       online=False,      # <-- 硬编码为 False
       last_seen=datetime.utcnow(),
   )
   ```
   此处在创建新设备时 **硬编码** `online=False`。同时，Device 模型的 Column 定义（`server\app\models\control.py` 第44行）的 Python 侧 `default=False` 也默认新创建对象为离线。

3. **Step 6（模拟下发控制指令）检查在线状态**：`POST /api/v1/command/send` → `command_service.py` 的 `create_command()`（第36-40行）：
   ```python
   device = db.query(Device).filter(Device.device_id == device_id).first()
   if not device or not device.online:
       return {"status": "offline", "code": 1003}
   ```
   由于 `device.online` 为 `False`，`not device.online` 为 `True`，条件成立，返回 offline 错误。

4. **系统中不存在将设备设为在线的逻辑**：遍历所有代码，`online` 字段仅在三处被写入：
   - `server\app\models\control.py` 第44行：ORM 模型定义 `default=False`
   - `server\app\services\sensor_service.py` 第78行：自动注册时设为 `False`
   - SQL 初始化脚本 `server\init\01_create_tables.sql` 第88行：列默认值 `DEFAULT FALSE`
   
   没有任何 API 端点或服务函数在设备上报数据时将 `online` 更新为 `True`，也没有独立的设备上线心跳逻辑。

### 证据链

1. **设备自动注册的代码位置**：`server\app\services\sensor_service.py` 第74-84行 —— `ensure_device_exists()` 创建设备时设置 `online=False`。

2. **命令下发的在线检查代码位置**：`server\app\services\command_service.py` 第36-40行 —— `create_command()` 检查 `not device.online`。

3. **E2E 测试的输出确认**（`e2e_output.txt` 第18-25行）：步骤6返回 `{"status": "offline", "code": 1003}`。

4. **集成测试同名用例被阻塞**：有一个专门的测试用例 `test_online_default_false`（`tests/integration/test_db_crud.py` 中）——该测试本身旨在验证 `online` 默认值为 `false`，但因问题1被阻塞。

### 影响范围

- **阻塞的 E2E 步骤**：步骤6（下发控制指令）、步骤7（控制状态闭环校验）
- **设计意图 vs 实际行为**：设备上报环境数据意味设备已在线运作，但注册时 `online` 被设为 `False` 且后续未更新，造成实际在线与数据库状态不一致
- **系统中无其他上线机制**：无心跳检测、无设备上线事件处理、无 IoTDA 设备状态同步逻辑

---

## 交叉影响分析

| 维度 | 说明 |
|------|------|
| 两个问题的独立性 | **相互独立**。问题1是 ORM DDL 语法错误，问题2是设备注册业务逻辑缺陷。修复和验证可以并行进行。 |
| 集成测试对验证的影响 | 问题1阻塞了全部集成测试，包括 `test_online_default_false` 等与问题2相关的测试。修正问题1后可在集成测试中补充设备在线状态的验证。 |
| E2E 环境对问题1的掩盖 | E2E 使用 SQL 初始化脚本建表，绕过了 ORM DDL bug，导致该 bug 在早期未被发现，直到专门运行集成测试时才暴露。 |

---

## 诊断结论

### 问题1 修复者须知

**改哪里**：`server\app\models\sensor.py`、`server\app\models\disease.py`、`server\app\models\control.py` 共 9 处 `server_default="CURRENT_TIMESTAMP"` 改为 `server_default=text("CURRENT_TIMESTAMP")`。

**为什么**：字符串值被 SQLAlchemy 作为字面量加引号渲染，PostgreSQL 无法将带引号的字符串解析为时间戳函数。

### 问题2 修复者须知

**改哪里**：`server\app\services\sensor_service.py` 第78行或其调用链。

**需要决策**：
- 方案A：设备自动注册时将 `online` 设为 `True`（简单，但失去区分"已注册但从未在线"设备的能力）
- 方案B：在设备上报属性数据时更新 `online=True`（语义更准确，上报行为本身证明设备在线）
- 方案C：保持 `online=False` 注册，但要求在 E2E 测试中额外添加上线步骤或 API（保持安全设计）

**无论哪种方案**，建议补充一个 `test_db_crud.py` 中 `test_online_default_false` 测试用例通过后的验收条件，确保该测试在修复后能正确验证 `online` 的预期行为。
