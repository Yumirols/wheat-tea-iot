# 诊断报告：FarmEye Guard 测试失败根因分析 (v2)

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

设备 `farmeye_guard_ws63` 的 `online` 字段为 `False`，命令下发前的在线状态检查拒绝了下发。导致 `online=False` 存在两条独立路径，各自独立产生相同的故障结果。

#### 路径A（E2E 场景 — seed data 预置离线）

Docker Compose 启动时，PostgreSQL 按字母序执行 `server/init/` 目录下的 SQL 文件。`02_seed_data.sql:7-8` 在应用启动前将 `farmeye_guard_ws63` 设备写入 `devices` 表，且 `online` 显式设为 `FALSE`：

```sql
INSERT INTO devices (device_id, device_name, mac_addr, online)
VALUES ('farmeye_guard_ws63', 'FarmEye Guard WS63 #1', 'A1:B2:C3:D4:E5:F6', FALSE)
ON CONFLICT (device_id) DO NOTHING;
```

Step 2（上报环境数据）调用 `ensure_device_exists()`（`server\app\services\sensor_service.py:72`）：

```python
device = db.query(Device).filter(Device.device_id == device_id).first()
```

由于设备已由 seed data 创建，查询返回非空，代码进入 `else` 分支（第85-88行）：

```python
else:
    device.last_seen = datetime.utcnow()
    db.commit()
    db.refresh(device)
```

此处**仅更新 `last_seen`，不触及 `online` 字段**。因此设备注册时被 seed data 设置的 `online=FALSE` 在整个 E2E 流程中被原样保留。

**因果链**：`02_seed_data.sql` 预植 `online=FALSE` → `ensure_device_exists()` 的 `else` 分支不更新 `online` → Step 6 `create_command()` 检查 `not device.online` 返回 `{"status": "offline", "code": 1003}`。

#### 路径B（集成测试场景 — 自动注册新设备硬编码离线）

在集成测试或使用新设备 ID 上报数据的场景下，设备不存在于 `devices` 表中。`ensure_device_exists()` 进入 `if` 分支（第74-84行）：

```python
if not device:
    device = Device(
        device_id=device_id,
        mac_addr=mac_addr,
        online=False,          # <-- 硬编码为 False
        last_seen=datetime.utcnow(),
    )
```

此处 `online=False` 是**硬编码**的，且 `Device` 模型的 Python 侧 `default=False`（`server\app\models\control.py:44`）在两个层面确保新建设备记录为离线：

```python
online = Column(Boolean, default=False)  # 仅 Python 侧默认值，非 DDL 约束
```

**因果链**：新设备 ID → `ensure_device_exists()` 新建记录 → `online=False` 硬编码 → `create_command()` 检查 `not device.online` 返回离线错误。

---

### `online=False` 设定点汇总

`online` 字段在代码中被设定为 `False` 的位置共 **4 处**，按性质分为"数据层写入"和"定义层默认值"两类：

| # | 位置 | 类别 | 说明 |
|---|------|------|------|
| 1 | `server\init\02_seed_data.sql:8` | **数据层写入** | 显式 INSERT `VALUES (..., FALSE)`，是 E2E 故障的直接数据来源 |
| 2 | `server\app\services\sensor_service.py:78` | **数据层写入** | 自动注册新设备时硬编码 `online=False`，是集成测试路径的故障来源 |
| 3 | `server\app\models\control.py:44` | **定义层默认值** | Python 侧 `default=False`，仅当创建 `Device()` 对象未指定 `online` 时生效（sensor_service.py:78 已显式指定，此默认值实际未被触发） |
| 4 | `server\init\01_create_tables.sql:88` | **定义层默认值** | DDL 列默认约束 `DEFAULT FALSE`，仅在 INSERT 未指定 `online` 列时生效（seed data 已显式指定，此默认值实际未被触发） |

**关键结论**：实际导致 `online=False` 的数据层写入只有 #1（seed data）和 #2（auto-registration）两处。#3 和 #4 属于"在最外层确保不会出现意外的 `online=True`"的安全垫，但并非 root cause 的直接写入来源。

---

### 证据链

1. **E2E 执行路径**：seed data 文件 `server\init\02_seed_data.sql:7-8` 预植 `farmeye_guard_ws63` 且 `online=FALSE`；`ensure_device_exists()` 第72行查询到已存在设备 → 第85-88行仅更新 `last_seen`，不更新 `online`。

2. **自动注册路径**：`server\app\services\sensor_service.py:74-84` —— `ensure_device_exists()` 新建设备时硬编码 `online=False`，同时 `control.py:44` 的 `default=False` 提供第二层保障。

3. **命令下发的在线检查**：`server\app\services\command_service.py:36-40` —— `create_command()` 检查 `not device.online`，返回 `{"status": "offline", "code": 1003}`。

4. **E2E 测试输出确认**（`e2e_output.txt` 第18-25行）：步骤6返回 `{"status": "offline", "code": 1003}`。

5. **被阻塞的相关集成测试**：有一个专门验证 `online` 默认值的测试 `test_online_default_false`（`tests/integration/test_db_crud.py` 中），但因问题1（ORM DDL）被阻塞从未执行过。

---

### 影响范围

- **阻塞的 E2E 步骤**：步骤6（下发控制指令）、步骤7（控制状态闭环校验）
- **设计意图 vs 实际行为**：设备上报环境数据证明设备已在线运作，但数据库中 `online` 始终为 `False`，造成实际在线状态与数据库状态不一致
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

#### 修复范围

`ensure_device_exists()`（`server\app\services\sensor_service.py:59-90`）的**两个分支**均需确保设备 `online=True`：

1. **`if not device:` 分支（第74-84行）**：新建设备时应设置 `online=True`（而非当前硬编码的 `online=False`）
2. **`else:` 分支（第85-88行）**：已存在设备应更新 `online=True`（除更新 `last_seen` 外，增加 `online=True` 的赋值）

仅修改第78行（新建设备分支）无法修复 E2E 场景的故障，因为 E2E 场景下设备已由 seed data 预植，代码执行的是 `else` 分支，第78行不会被触发。

#### 关于 `02_seed_data.sql` 的处理

`02_seed_data.sql:8` 中 `online=FALSE` 是否需要修改，取决于所选的修复方案：

- 如果修复方案确保 `ensure_device_exists()` 的两分支均将 `online` 更新为 `True`，则 seed data 的 `online=FALSE` 将在 Step 2 上报数据时被 `else` 分支覆盖，无需单独修改。
- 如果仅修改 seed data 中的 `online=FALSE` 为 `TRUE`（而不修改 `ensure_device_exists()`），则仅修复路径A（E2E 场景），路径B（新设备自动注册）仍会失败。**不推荐仅修改 seed data。**

#### 方案推荐

基于诊断证据，推荐 **方案B（在设备上报属性数据时更新 `online=True`）** 的变体，理由如下：

- **方案C（保持离线 + 增加上线步骤）不应入选**。E2E 测试无额外的设备上线步骤 API，seed data 已预植离线，方案C需要新增 API 端点 + 修改测试脚本，工程成本高且对集成测试和自动注册路径无效。
- **方案A（注册时直接设 True）** 的语义缺陷：`ensure_device_exists()` 被 `create_snapshot()` 调用，创建快照时设备可能首次出现（注册）或已存在（后续上报）。两种情况下设备出现都说明设备至少曾在线，设 `True` 合理。但该方案仅覆盖新建设备分支。
- **方案B（上报数据时更新 `online=True`）的语义最准确**：设备上报环境数据本身证明其在线运作。推荐在 `ensure_device_exists()` 函数的 `else` 分支中增加 `device.online = True`，同时将 `if` 分支的 `online=False` 改为 `online=True`。这样两条路径均被覆盖。

**推荐的具体修改位置**：

| 修改位置 | 当前代码 | 修改为 |
|---------|---------|--------|
| `sensor_service.py:78` | `online=False` | `online=True` |
| `sensor_service.py:85-88`（else 分支） | 仅 `device.last_seen = datetime.utcnow()` | 增加 `device.online = True` |

如果希望实现更精细的控制（例如仅在确实收到遥测数据时才标记在线），也可以将 `online=True` 的更新放在调用方 `create_snapshot()` 中（第33行调用 `ensure_device_exists()` 之后）。两种做法在 E2E 和集成测试场景下等价，均能确保两条路径都被覆盖。

#### 验收建议

修复后验证：
1. **路径A（E2E）**：重新运行 `python tests/integration_run.py`，确认步骤6返回 `{"status": "sent"}` 而非 `{"status": "offline", "code": 1003}`
2. **路径B（自动注册）**：待问题1修复后，运行集成测试确认 `test_online_default_false` 测试用例按预期通过（该测试预期 `online` 为 `True`，需确认测试本身与修复后的行为一致）
