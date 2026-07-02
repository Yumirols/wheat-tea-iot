# FarmEye Guard 测试执行报告

- **执行时间**：2026-07-02
- **操作系统**：Windows 11
- **Python 版本**：3.11.4
- **数据库**：PostgreSQL 16（Docker 容器）
- **项目根目录**：`E:\dev\wheat-tea-iot\server`

---

## 1. 单元测试

- **命令**：`pytest -v`
- **结果**：37 passed, 38 skipped, 0 failed, 5 warnings
- **输出文件**：`ut_output.txt`

### 逐文件结果

| 测试文件 | 通过 | 跳过 | 失败 |
|---------|------|------|------|
| test_advisory.py | 3 | 0 | 0 |
| test_command.py | 6 | 0 | 0 |
| test_device.py | 1 | 0 | 0 |
| test_disease.py | 5 | 0 | 0 |
| test_health.py | 2 | 0 | 0 |
| test_image.py | 4 | 0 | 0 |
| test_iotda_webhook.py | 9 | 0 | 0 |
| test_sensor.py | 7 | 0 | 0 |
| tests/integration/ (ddl + crud + api) | 0 | 38 | 0 |
| **合计** | **37** | **38** | **0** |

### 结论

单元测试全部通过。38 个集成测试用例因 `@pytest.mark.integration` 标记被全局 conftest 自动跳过（需 `--run-integration` 参数启用），符合设计预期。

---

## 2. 数据库集成测试

- **命令**：`pytest tests/integration/ --run-integration -v`
- **结果**：0 passed, 0 skipped, 38 ERROR at setup
- **输出文件**：`it_output.txt`

### 逐文件结果

| 测试文件 | 通过 | 错误 |
|---------|------|------|
| test_db_ddl.py (19 用例) | 0 | 19 |
| test_db_crud.py (13 用例) | 0 | 13 |
| test_api_integration.py (6 用例) | 0 | 6 |
| **合计** | **0** | **38** |

全部 38 个测试用例在 session-scoped fixture `test_engine` 的 `Base.metadata.create_all(bind=engine)` 阶段报错，未进入任何测试逻辑。

### 根因分析

**问题**：SQLAlchemy ORM 模型中使用 `server_default="CURRENT_TIMESTAMP"` 字符串作为默认值。

SQLAlchemy 将字符串值作为字面量渲染到 DDL 中，生成如下 SQL：

```sql
created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT 'CURRENT_TIMESTAMP'
```

PostgreSQL 将 `'CURRENT_TIMESTAMP'` 解析为字符串常量而非 SQL 函数调用，导致 `InvalidDatetimeFormat` 错误。

**影响范围**：3 个模型文件共 9 处

| 模型 | 文件 | 受影响字段 |
|------|------|-----------|
| SensorSnapshot | app/models/sensor.py | `timestamp`, `created_at` |
| SensorDailyAggregation | app/models/sensor.py | `created_at` |
| DiseaseRecord | app/models/disease.py | `timestamp`, `created_at` |
| ControlLog | app/models/control.py | `timestamp`, `created_at` |
| Device | app/models/control.py | `registered_at`, `created_at` |

**修正方案**：将 `server_default="CURRENT_TIMESTAMP"` 替换为 `server_default=text("CURRENT_TIMESTAMP")`（需添加 `from sqlalchemy import text` 导入）。这会使 SQLAlchemy 生成 `DEFAULT CURRENT_TIMESTAMP`（无引号），PostgreSQL 正确识别为函数调用。

---

## 3. 端到端联调测试

- **命令**：`python tests/integration_run.py`（完整 Docker 容器组）
- **结果**：5/7 PASS，2 FAIL
- **输出文件**：`e2e_output.txt`

### 逐步骤结果

| 步骤 | 端点 | 结果 | 说明 |
|------|------|------|------|
| 1/7 | GET /api/v1/health | PASS | status=healthy, db_connected=True |
| 2/7 | POST /api/v1/iotda/properties/report | PASS | snapshot_id=11 |
| 3/7 | GET /api/v1/sensor/latest | PASS | temperature=28.5, humidity=75.0 |
| 4/7 | POST /api/v1/iotda/ai/report | PASS | disease_record_id=3 |
| 5/7 | GET /api/v1/advisory | PASS | auto_action=spray ON, risk_level=low |
| 6/7 | POST /api/v1/command/send | FAIL | status=offline (code=1003) |
| 7/7 | 控制状态闭环校验 | FAIL | 步骤 6 失败导致跳过 |

### 根因分析

步骤 6 返回 `status=offline`，原因：
- 设备 `farmeye_guard_ws63` 在步骤 2/7 自动注册时 `online` 默认值为 `false`
- 步骤 6 下发控制指令前检查设备在线状态，发现离线后拒接下发
- 此行为符合设计（离线设备不应接收控制指令）

**修正方案**：
1. 在自动设备注册逻辑中设置 `online=True`
2. 或在 E2E 脚本 step_send_command 之前添加设备在线前置步骤

### 注意

与集成测试不同，E2E 测试前 5 步成功通过数据写入和查询。原因：Docker 容器使用 `init/01_create_tables.sql` 初始化数据库 schema，该 SQL 脚本正确使用 `DEFAULT CURRENT_TIMESTAMP`（无引号），绕过 ORM `server_default` 语法问题。集成测试的 `Base.metadata.create_all()` 使用的是 ORM 模型定义，故触发该 bug。

---

## 4. 测试结论

| 测试类型 | 结果 | 阻塞项 |
|---------|------|--------|
| 单元测试 | **PASSED** | 无 |
| 数据库集成测试 | **BLOCKED** | ORM 模型 `server_default` 语法问题（9 处） |
| 端到端联调测试 | **PASSED WITH FAILURES** | 设备离线状态（步骤 6-7） |

**整体结论：NOT ALL PASSED**

- 健康检查、数据上报、查询等核心链路功能正常（E2E 前 5 步全部 PASS）
- 单元测试全部通过，基础业务逻辑正确
- 集成测试因 ORM schema 问题全部阻塞，需修复 `server_default` 语法后重验
- 控制下发链路因设备注册时 `online` 默认为 `false` 受阻，需调整
