# FarmEye Guard 全量测试报告

> 报告生成时间：2026-07-02 13:30 UTC
> 测试范围：单元测试 (37) + 集成测试 (38) + 端到端联调 (7步)
> 执行方式：手动执行验证，基于真实运行结果

---

## 1. 测试环境信息

| 项目 | 值 |
|------|-----|
| Python 版本 | 3.11.4 |
| 操作系统 | Windows 11 24H2 (build 26100, win32) |
| pytest | 8.3.5 |
| pytest-asyncio | 0.24.0 |
| FastAPI | 0.115.14 |
| SQLAlchemy | 2.0.51 |
| httpx | 0.27.2 |
| psycopg2 | 2.9.12 |
| uvicorn | 0.30.6 |
| anyio | 4.14.1 |

### Docker 容器状态

| 容器名 | 镜像 | 状态 | 端口映射 |
|--------|------|------|---------|
| farmeye-db | postgres:16-alpine | Up 3 hours (healthy) | 127.0.0.1:5432 |
| farmeye-api-dev | server-api-dev | Up 3 hours | 0.0.0.0:8000 |

数据库连接：`postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_test`（测试专用数据库，自动创建）

---

## 2. 测试统计汇总

| 测试模块 | 总数 | 通过 | 失败 | 通过率 |
|----------|------|------|------|--------|
| 单元测试 | 37 | 37 | 0 | 100% |
| 集成测试 | 38 | 38 | 0 | 100% |
| 端到端联调 | 7步 | 7 | 0 | 100% |
| **总计** | **82** | **82** | **0** | **100%** |

---

## 3. 单元测试详情

运行命令：`python -m pytest tests/ -v --tb=short`

全部 37 个单元测试通过，38 个集成测试被正确跳过（需要 `--run-integration` 标记）。

### 逐文件结果

| 测试文件 | 状态 | 用例数 | 覆盖模块 |
|----------|------|--------|---------|
| test_health.py | PASSED | 2 | 健康检查 API |
| test_iotda_webhook.py | PASSED | 9 | IoTDA Webhook 上报（属性/AI/命令应答/幂等/异常） |
| test_sensor.py | PASSED | 7 | 传感器数据查询（最新/历史/分页/聚合） |
| test_disease.py | PASSED | 5 | 病虫害记录（筛选/统计/热力图） |
| test_command.py | PASSED | 6 | 命令下发/日志查询 |
| test_advisory.py | PASSED | 3 | 防治建议生成 |
| test_image.py | PASSED | 4 | 图片上传/获取 |
| test_device.py | PASSED | 1 | 设备列表 |

### 测试架构要点

- 单元测试使用 `mock_db_session` 模拟数据库，无需真实数据库连接
- 使用 `pytest-asyncio` 异步支持，`asyncio_mode = "auto"` 自动处理异步 fixture
- 38 个集成测试用例通过 `pytest.mark.integration` 标记 + `--run-integration` 条件跳过

---

## 4. 集成测试详情

运行命令：`python -m pytest tests/integration/ -v --tb=short --run-integration`

全部 38 个集成测试通过，基于真实 PostgreSQL 16 数据库。

### 4.1 DDL 与索引验证（test_db_ddl.py） — 19 tests PASSED

| 测试类 | 测试内容 | 用例数 | 状态 |
|--------|----------|--------|------|
| TestTableExistence | 5 张表的列定义完整性 | 5 | PASSED |
| TestIndexExistence | 全部 UNIQUE 索引和普通索引 | 8 | PASSED |
| TestConstraintEnforcement | UNIQUE 约束执行验证 | 3 | PASSED |
| TestColumnTypes | Numeric/SmallInt 列类型精度验证 | 2 | PASSED |

验证的索引清单：

| 索引名 | 类型 | 表 | 列 |
|--------|------|----|----|
| idx_sensor_device_time | UNIQUE | sensor_snapshot | device_id, timestamp |
| idx_disease_device_time | UNIQUE | disease_records | device_id, timestamp, disease_type |
| idx_control_command_id | UNIQUE partial | control_logs | command_id WHERE command_id IS NOT NULL |
| idx_control_device_time | (普通) | control_logs | device_id, timestamp |
| idx_agg_device_date | (普通) | sensor_daily_aggregation | device_id, agg_date |
| idx_devices_device_id | (普通) | devices | device_id |
| devices_device_id_key | UNIQUE | devices | device_id |
| uq_sensor_daily_agg_device_date | UNIQUE | sensor_daily_aggregation | device_id, agg_date |

### 4.2 CRUD 与数据保留验证（test_db_crud.py） — 13 tests PASSED

| 测试类 | 测试内容 | 状态 |
|--------|----------|------|
| TestSensorSnapshotCRUD | 插入/读取/NULLs/多设备最新记录查询 | PASSED |
| TestDiseaseRecordCRUD | 病虫害记录 CRUD + 联动字段 | PASSED |
| TestControlLogCRUD | 控制日志插入与状态更新 | PASSED |
| TestDeviceCRUD | 设备注册 + device_id 唯一性 + online 默认值 | PASSED |
| TestDataRetention | 过期传感器/聚合/控制日志数据清理 | PASSED |
| TestConcurrentWrites | 并发写入 IntegrityError 正确处理 | PASSED |
| TestDailyAggregation | 日聚合 AVG/MAX/MIN 计算正确性 | PASSED |

### 4.3 API 全链路集成（test_api_integration.py） — 6 tests PASSED

| 测试用例 | 验证内容 | 状态 |
|----------|----------|------|
| test_properties_report_persists | Webhook 环境上报 -> 数据库持久化 -> API 可查询 | PASSED |
| test_idempotent_properties_report | 重复上报幂等（重复 service_id 不会重复插入） | PASSED |
| test_severe_ai_triggers_spray | 重度病害（severity=3）自动触发 spray ON 指令 | PASSED |
| test_ai_idempotent | 重复 AI 上报幂等处理 | PASSED |
| test_command_send_and_response | 命令下发 -> 设备应答 -> 状态闭环 | PASSED |
| test_moderate_disease_with_env_linkage | 中度病害 + 环境联动分析检查 | PASSED |

### 4.4 测试架构说明

集成测试使用 `savepoint` 级事务隔离实现完全测试间隔离：

```
connection = test_engine.connect()
transaction = connection.begin()
session = Session(bind=connection, join_transaction_mode="create_savepoint")
# 测试执行...
session.close()
transaction.rollback()  # 回滚所有变更
connection.close()
```

- `session.commit()` 仅释放 savepoint，不提交外层事务
- `session.rollback()` 仅回滚到 savepoint
- 测试结束后 `transaction.rollback()` 回滚所有变更，实现完全隔离
- 无需手动清理测试数据

---

## 5. 端到端联调结果

运行命令：`python tests/integration_run.py`

全部 7 步通过，退出码 0。验证了完整的 Webhook 上报 -> AI 分析 -> 防治建议 -> 命令下发 -> 状态闭环链路。

| 步骤 | 操作 | API 端点 | 结果 | 关键数据 |
|------|------|----------|------|---------|
| Step 1 | 健康检查 | GET /api/v1/health | PASS | status=healthy, db_connected=True |
| Step 2 | 上报环境数据 | POST /api/v1/iotda/properties/report | PASS | snapshot_id=13 |
| Step 3 | 校验最新快照 | GET /api/v1/sensor/latest | PASS | temperature=28.5, humidity=75.0 |
| Step 4 | 上报 AI 重度病害 | POST /api/v1/iotda/ai/report | PASS | disease_record_id=5 |
| Step 5 | 查询防治建议 | GET /api/v1/advisory | PASS | auto_action=spray ON, risk_level=low |
| Step 6 | 下发控制指令 | POST /api/v1/command/send | PASS | command_id=mock_*, status=sent |
| Step 7a | 查询控制日志 | GET /api/v1/command/logs | PASS | command_id 日志中确认 |
| Step 7b | 模拟设备应答 | POST /api/v1/iotda/command/response | PASS | 应答被接受 |
| Step 7c | 验证状态闭环 | GET /api/v1/command/logs | PASS | status=closed, result_code=0 |

---

## 6. 已知问题/警告

### 6.1 DeprecationWarning 汇总

测试执行中共产生 5 个 DeprecationWarning：

| 来源 | 触发位置 | 说明 | 影响 |
|------|---------|------|------|
| FastAPI `on_event` | `app/main.py:49` (startup) | `@app.on_event("startup")` 已弃用 | 功能正常，建议迁移到 `lifespan` |
| FastAPI `on_event` | `app/main.py:60` (shutdown) | `@app.on_event("shutdown")` 已弃用 | 同上 |
| FastAPI `on_event` | `fastapi/applications.py:4495` (2次) | 内部调用路径触发 | 无影响 |
| pytest-asyncio `event_loop` | `tests/conftest.py:84` | 自定义 event_loop fixture 已弃用 | 无影响 |

### 6.2 SAWarning

集成测试中产生 1 个 SAWarning：

| 来源 | 说明 | 影响 |
|------|------|------|
| `tests/integration/conftest.py:189` | `transaction.rollback()` 时 session 已从 connection 解除关联 | 测试后清理过程中的良性警告，不影响测试正确性 |

### 6.3 潜在改进建议

1. **FastAPI 生命周期迁移**：将 `@app.on_event("startup")` / `("shutdown")` 迁移到 `lifespan` 异步上下文管理器，消除 3 个 DeprecationWarning
2. **pytest-asyncio event_loop 配置**：移除 `tests/conftest.py:84` 的自定义 event_loop fixture，使用 `scope` 参数或 `asyncio_mode = "auto"`，消除 1 个 DeprecationWarning
3. **集成测试 SAWarning**：回顾 `conftest.py` 的 `transaction.rollback()` 在并发测试后的解除关联问题，确认是否需要在 `session.close()` 之前额外清理
4. **avg_light 列类型**：已在本次迭代中将 `avg_light` 从 `Numeric(5,1)` 改为 `Integer`，max_light/min_light 原为 Integer 保持一致。若生产环境光照值存在小数精度需求，可考虑改为 `Numeric(7,1)`

---

## 7. 已修复问题清单

本次测试迭代修复了以下 6 个集成测试失败问题：

| 问题 | 根因 | 修复内容 |
|------|------|---------|
| test_idempotent_properties_report | 幂等回滚破坏事务隔离，handler 的 `db.rollback()` 与 fixture `connection.begin()` 冲突 | conftest.py 改用 `join_transaction_mode="create_savepoint"` |
| test_ai_idempotent | 同上 | 同上 |
| test_severe_ai_triggers_spray | fixture 固定时间戳导致数据落于 advisory 60 分钟窗口之外 | conftest.py payload 改用 `datetime.utcnow()` 动态时间 |
| test_query_latest_per_device | 测试间污染，前一测试脏数据泄露 | savepoint 隔离自动修复 |
| test_cleanup_aggregation_integrity | 测试间污染 + `avg_light=31000` 超出 `Numeric(5,1)` 精度 | savepoint 隔离 + avg_light 改为 Integer |
| test_daily_aggregation_calculation | `avg_light=35000` 超出 `Numeric(5,1)` 最大值 9999.9 | avg_light 改为 Integer |

---

## 8. 结论

全量测试全部通过，总计 82 个测试用例，0 失败：

- **单元测试**：37/37 通过，覆盖所有 8 个 API 模块，使用 mock 数据库
- **集成测试**：38/38 通过，覆盖 DDL 验证、CRUD 操作、数据保留清理、API 全链路、并发写入
- **端到端联调**：7/7 通过，覆盖完整的设备上报 -> 决策分析 -> 控制指令 -> 状态闭环链路

系统功能完整性验证通过，具备上线条件。
