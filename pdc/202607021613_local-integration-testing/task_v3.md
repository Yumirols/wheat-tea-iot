# 任务指令（v3）

## 动作
NEW

## 任务描述
依据 `docs/local-integration-testing.md` SS7.4（行 1109-1630）的完整代码，在 `server/tests/integration/test_db_crud.py` 创建 CRUD 操作、数据保留清理和并发写入集成测试文件。

预期产出：`server/tests/integration/test_db_crud.py`，包含 SS7.4 全部代码，逐字符匹配设计文档。

## 选择理由
- test_db_crud.py 是集成测试中按依赖顺序的第三个文件，依赖 conftest 提供的 `db_session` fixture，不依赖其他测试文件
- 独立性好，可单独运行和验证
- 内容在设计中已完整定义，只需按文档复制实现
- R1（基础设施）和 R2（DDL 验证）均已 PASSED，具备继续推进条件

## 任务上下文
- 代码已完整定义在 `docs/local-integration-testing.md` SS7.4（行 1109-1630），约 520 行
- 文件包含 7 个测试类，每个类标记 `@pytest.mark.integration`：

  | 测试类 | 测试方法 | 说明 |
  |--------|---------|------|
  | TestSensorSnapshotCRUD | test_insert_and_read, test_insert_with_nulls, test_query_latest_per_device | 传感器快照 CRUD |
  | TestDiseaseRecordCRUD | test_insert_and_read, test_linkage_fields | 病虫害记录 CRUD |
  | TestControlLogCRUD | test_insert_and_update | 控制日志插入与更新 |
  | TestDeviceCRUD | test_insert_and_unique, test_online_default_false | 设备注册唯一性 |
  | TestDataRetention | test_cleanup_sensor_expired(slow), test_cleanup_aggregation_integrity(slow), test_cleanup_control_logs(slow) | 数据保留清理 |
  | TestConcurrentWrites | test_concurrent_duplicate_sensor_insert(slow) | 并发写入模拟 |
  | TestDailyAggregation | test_daily_aggregation_calculation | 日聚合查询验证 |

- 共约 13 个测试方法，其中 4 个标记 `@pytest.mark.slow`
- 所有函数签名使用 `db_session: Session` 类型标注，依赖 conftest 的 `db_session` fixture
- 顶层导入：`pytest`, `text`(from sqlalchemy), `IntegrityError`(from sqlalchemy.exc), `Session`(from sqlalchemy.orm), `datetime`/`timedelta`/`timezone`(from datetime)
- 顶层模型导入：`SensorSnapshot`, `SensorDailyAggregation`(from app.models.sensor), `DiseaseRecord`(from app.models.disease), `ControlLog`, `Device`(from app.models.control)
- TestDataRetention 类需局部导入 `cleanup_expired_data`(from app.services.data_retention)
- TestConcurrentWrites 测试需要从 `app.db.session` 导入 `SessionLocal`（但实际用`create_engine`创建额外 Session）
- 注意 `test_cleanup_control_logs` 方法内局部 re-import `datetime`，需保留

## 已有产出上下文
工作目录中已有文件：
- `server/tests/integration/__init__.py` — 空包标记文件
- `server/tests/integration/conftest.py` — 集成测试 fixture：test_engine、db_session（事务回滚）、override_get_db、override_verify_api_key、async_client、sample_sensor_payload、sample_ai_payload_low、sample_ai_payload_high、test_device_id
- `server/tests/integration/test_db_ddl.py` — DDL/索引验证测试（已 PASSED）

依赖关系：
- test_db_crud.py 依赖 conftest.py 的 `db_session`，不依赖 test_db_ddl.py
- `docs/local-integration-testing.md` SS7.4 提供了完整可复制的代码
