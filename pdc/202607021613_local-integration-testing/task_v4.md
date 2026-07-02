# 任务指令（v4）

## 动作
NEW

## 任务描述
依据 `docs/local-integration-testing.md` SS7.5（行 1632-2057）的完整代码，在 `server/tests/integration/test_api_integration.py` 创建 FastAPI 全链路集成测试文件。

预期产出：`server/tests/integration/test_api_integration.py`，包含 SS7.5 全部代码，逐字符匹配设计文档。

## 选择理由
- test_api_integration.py 是集成测试中按依赖顺序的第四个文件，依赖 conftest 提供的 async_client、db_session、sample_sensor_payload、sample_ai_payload_high、test_device_id 等 fixture
- 内容在设计中已完整定义（SS7.5 约 430 行），只需按文档复制实现
- T1（conftest 基础设施）已提供所有必需 fixture
- T2（DDL 验证）和 T3（CRUD 测试）均已 PASSED

## 任务上下文
- 设计文档 SS7.5（行 1632-2057）已完整定义 test_api_integration.py 的全部代码，约 430 行
- 文件包含 4 个测试类，每个类标记 `@pytest.mark.integration`：

  | 测试类 | 测试方法 | 说明 |
  |--------|---------|------|
  | TestPropertiesReportFlow | test_properties_report_persists, test_idempotent_properties_report | 传感器上报全链路 + 幂等性 |
  | TestAiReportAdvisoryFlow | test_severe_ai_triggers_spray, test_ai_idempotent | AI 识别 + 决策 + 防治建议 + 幂等性 |
  | TestCommandFlow | test_command_send_and_response | 命令下发 + 应答闭环 |
  | TestAdvisoryEnvLinkage | test_moderate_disease_with_env_linkage | 环境-病虫害联动分析 |

- 共 5 个测试方法，全部标记 `@pytest.mark.asyncio`
- 函数签名依赖：`async_client: AsyncClient`、`db_session: Session`、`sample_sensor_payload`、`sample_ai_payload_high`、`test_device_id`
- conftest.py 已提供所有必需的 fixture，包括 async_client 和 sample_* payload fixture
- 需导入：`httpx.AsyncClient`、`sqlalchemy.orm.Session`、`app.models.sensor.SensorSnapshot`、`app.models.disease.DiseaseRecord`、`app.models.control.ControlLog`、`Device`

## 已有产出上下文
工作目录中已有文件：
- `server/tests/integration/__init__.py` — 空包标记文件
- `server/tests/integration/conftest.py` — 集成测试 fixture 基础设施
- `server/tests/integration/test_db_ddl.py` — DDL/索引验证测试（已 PASSED）
- `server/tests/integration/test_db_crud.py` — CRUD 操作与数据保留测试（已 PASSED）

依赖关系：
- test_api_integration.py 依赖 conftest.py 提供的 async_client、db_session、sample_sensor_payload、sample_ai_payload_high、test_device_id 等 fixture
- 不依赖 test_db_ddl.py 或 test_db_crud.py
- `docs/local-integration-testing.md` SS7.5 提供了完整可复制的代码
