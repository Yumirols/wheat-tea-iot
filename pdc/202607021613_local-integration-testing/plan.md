# 任务计划

任务描述：依据 docs/local-integration-testing.md 实现集成测试与端到端联调测试代码
工作目录：pdc/202607021613_local-integration-testing

---

## R1 NEW 集成测试基础设施 [ID: T1]
任务：创建 server/tests/integration/__init__.py 包标记文件和 conftest.py 测试基础设施。

选择理由：
- `conftest.py` 是所有集成测试的核心依赖（test_engine、db_session、override_deps、async_client、测试数据 fixture）
- `test_db_ddl.py`、`test_db_crud.py`、`test_api_integration.py` 均依赖 conftest 提供的基础设施
- 应从最基础的依赖层开始实现，后续测试文件可以基于此增量构建
- `__init__.py` 仅作包标记，trivial，可以和 conftest 同属一个子任务（高内聚合并）

上下文：
- 代码已完整定义在 docs/local-integration-testing.md SS7 中
- 全局 tests/conftest.py 已注册 --run-integration 选项和 integration 标记
- tests/integration/ 目录已存在但无 .py 文件
- conftest.py 需实现：数据库自动创建、ORM 建表、SQL 级索引、事务回滚隔离、FastAPI 依赖覆盖
- 集成 conftest 需覆盖全局 conftest 的 get_db 覆盖（从 mock 变为真实 Session）

---

## R1 PASSED 集成测试基础设施 [ID: T1]
结果：`server/tests/integration/__init__.py`（包标记文件）和 `conftest.py`（集成测试核心 fixture 基础设施）已创建。
检查：PASSED — 两个文件与设计文档 SS7.1-SS7.2 逐字符匹配，Python 语法编译通过。包含数据库自动创建、ORM 建表、SQL 级索引创建、事务回滚隔离、FastAPI 依赖覆盖、async_client、5 个共享 fixture。

---

## R2 NEW test_db_ddl.py DDL/索引验证测试 [ID: T2]
任务：依据 docs/local-integration-testing.md SS7.3 的完整代码实现，在 `server/tests/integration/test_db_ddl.py` 创建 DDL/索引验证测试文件。

选择理由：
- test_db_ddl.py 是集成测试中按依赖顺序的第二个文件，依赖 conftest 提供的 `db_session` fixture，不依赖其他测试文件
- 独立性好，可以单独运行和验证
- 内容在设计中已完整定义（SS7.3 约 340 行），只需按文档复制实现

上下文：
- 设计文档 SS7.3 已完整定义 test_db_ddl.py 的全部代码
- 文件包含 4 个测试类：TestTableExistence（表存在性和列结构）、TestIndexExistence（索引验证）、TestConstraintEnforcement（约束执行验证）、TestColumnTypes（列数据类型验证）
- 共约 17 个测试用例，其中 3 个标记为 @pytest.mark.slow
- 所有用例标记 @pytest.mark.integration
- 依赖 conftest.py 的 db_session fixture

## R2 PASSED DDL/索引验证测试 [ID: T2]
结果：`server/tests/integration/test_db_ddl.py` 已创建，含 4 个测试类（TestTableExistence、TestIndexExistence、TestConstraintEnforcement、TestColumnTypes），共 19 个测试函数，3 个标记 @pytest.mark.slow。
检查：PASSED — 19 项检查全部通过，与设计文档 SS7.3 逐字符一致，Python 编译通过，AST 结构完整。

---

## R3 NEW CRUD 操作与数据保留测试 [ID: T3]
任务：依据 docs/local-integration-testing.md SS7.4 的完整代码，在 `server/tests/integration/test_db_crud.py` 创建 CRUD 操作、数据保留清理和并发写入集成测试文件。

选择理由：
- test_db_crud.py 是集成测试中按依赖顺序的第三个文件，依赖 conftest 提供的 `db_session` fixture，不依赖其他测试文件
- 独立性好，可以单独运行和验证
- 内容在设计中已完整定义（SS7.4 约 520 行），只需按文档复制实现

上下文：
- 设计文档 SS7.4（行 1109-1630）已完整定义 test_db_crud.py 的全部代码
- 文件包含 7 个测试类：TestSensorSnapshotCRUD、TestDiseaseRecordCRUD、TestControlLogCRUD、TestDeviceCRUD、TestDataRetention、TestConcurrentWrites、TestDailyAggregation
- 共约 13 个测试方法，其中 4 个标记为 @pytest.mark.slow（3 个 cleanup + 1 个并发）
- 所有类标记 @pytest.mark.integration
- 依赖 conftest.py 的 db_session fixture
- 需要导入：SensorSnapshot, SensorDailyAggregation, DiseaseRecord, ControlLog, Device
- TestDataRetention 类需局部导入 cleanup_expired_data（但实际使用 SQL DELETE 模拟清理）
- TestConcurrentWrites 需用 engine 创建额外独立 Session 模拟并发

---

## R3 PASSED CRUD 操作与数据保留测试 [ID: T3]
结果：`server/tests/integration/test_db_crud.py` 已创建，含 7 个测试类（TestSensorSnapshotCRUD、TestDiseaseRecordCRUD、TestControlLogCRUD、TestDeviceCRUD、TestDataRetention、TestConcurrentWrites、TestDailyAggregation），共 13 个测试方法，4 个标记 @pytest.mark.slow。
检查：PASSED — 11 项检查全部通过，Python 编译无语法错误，与设计文档 SS7.4 逐字符完全一致（共 518 行）。

## R4 NEW API 全链路集成测试 [ID: T4]
任务：依据 docs/local-integration-testing.md SS7.5 的完整代码，在 `server/tests/integration/test_api_integration.py` 创建 FastAPI 全链路集成测试文件。

选择理由：
- test_api_integration.py 是集成测试中按依赖顺序的第四个文件，依赖 conftest 提供的 async_client、db_session、sample_sensor_payload、sample_ai_payload_high、test_device_id 等 fixture
- 内容在设计中已完整定义（SS7.5 约 430 行），只需按文档复制实现
- T1（conftest 基础设施）已提供所有必需 fixture：async_client、override_deps、test_device_id、sample_sensor_payload、sample_ai_payload_high
- T2（DDL 验证）和 T3（CRUD 测试）均已 PASSED

上下文：
- 设计文档 SS7.5（行 1632-2057）已完整定义 test_api_integration.py 的全部代码，约 430 行
- 文件包含 4 个测试类，每个类标记 @pytest.mark.integration：

  | 测试类 | 测试方法 | 说明 |
  |--------|---------|------|
  | TestPropertiesReportFlow | test_properties_report_persists, test_idempotent_properties_report | 传感器上报全链路 + 幂等性 |
  | TestAiReportAdvisoryFlow | test_severe_ai_triggers_spray, test_ai_idempotent | AI 识别 + 决策 + 防治建议 + 幂等性 |
  | TestCommandFlow | test_command_send_and_response | 命令下发 + 应答闭环 |
  | TestAdvisoryEnvLinkage | test_moderate_disease_with_env_linkage | 环境-病虫害联动分析 |

- 共 5 个测试方法，全部标记 @pytest.mark.asyncio
- 函数签名依赖：async_client: AsyncClient、db_session: Session、sample_sensor_payload、sample_ai_payload_high、test_device_id
- conftest.py 已提供所有必需的 fixture，包括 async_client 和 sample_* payload fixture
- 需导入：httpx.AsyncClient、sqlalchemy.orm.Session、app.models.sensor.SensorSnapshot、app.models.disease.DiseaseRecord、app.models.control.ControlLog、Device

---

## R4 PASSED API 全链路集成测试 [ID: T4]
结果：`server/tests/integration/test_api_integration.py` 已创建，含 4 个测试类（TestPropertiesReportFlow、TestAiReportAdvisoryFlow、TestCommandFlow、TestAdvisoryEnvLinkage），共 6 个测试方法（含 1 个 helper `_seed_device_online`），全部标记 @pytest.mark.integration 和 @pytest.mark.asyncio。
检查：PASSED -- 402 行与设计文档 SS7.5 逐字符一致，Python 编译通过，所有导入路径有效，7 项检查全部通过。

---

## R5 PASSED 端到端联调脚本 [ID: T5]
结果：`server/tests/integration_run.py` 已创建，含独立端到端联调脚本，448 行代码，七步联调流程（健康检查→上报环境数据→校验快照→AI上报→查询建议→下发命令→闭环校验），完整退出码 0/1 逻辑。
检查：PASSED — 7 项检查全部通过，与设计文档 SS7.6 逐字符一致，Python 编译通过，httpx 可用。

---

## R5 NEW 端到端联调脚本 [ID: T5]
任务：依据 docs/local-integration-testing.md SS7.6 的完整代码，在 `server/tests/integration_run.py` 创建独立端到端联调脚本。

选择理由：
- 独立于 pytest 的 httpx 黑盒测试脚本，不依赖 conftest fixture
- 可在 Docker 容器启动后独立运行，退出码 0/1 区分通过/失败
- 最后完成的文件，因为它是上线前的最后一道防线

上下文：
- 设计文档 SS7.6（行 2059-2509）已完整定义 integration_run.py 的全部代码，约 450 行
- 使用 httpx 库，不使用 pytest
- 七步联调流程：健康检查→上报环境数据→校验快照→AI上报→查询建议→下发命令→闭环校验
- 环境变量配置：BASE_URL、API_KEY、DEVICE_ID
