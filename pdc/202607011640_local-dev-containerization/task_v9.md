# 任务指令（v9）

## 动作
RETRY

## 任务描述

在 `server/tests/` 目录下创建测试基础设施和所有 API 单元测试文件。根据设计文档 `docs/2_vps-deployment.md` 第 4 章（测试方案）的规格，输出以下 10 个文件：

### 文件清单

1. **server/tests/__init__.py** — 空包标识文件

2. **server/tests/conftest.py** — 全局测试配置，包含：
   - pytest 钩子：`pytest_addoption`（注册 `--run-e2e`、`--run-docker`、`--run-integration`、`--run-performance` 四个自定义选项）、`pytest_configure`（注册 e2e/docker/integration/performance/slow 标记）、`pytest_collection_modifyitems`（根据命令行选项条件性跳过标记的测试）
   - `event_loop` fixture（session 级，复用事件循环）
   - `async_client` fixture（使用 `httpx.AsyncClient` + `ASGITransport` 包装 FastAPI app，对 `get_db` 和 `verify_api_key` 使用 `app.dependency_overrides` 注入 Mock，使所有 API 测试无需真实数据库）
   - `mock_db_session` fixture（Mock SQLAlchemy Session 的 query/execute/add/commit/rollback/close 方法，支持链式查询 mock）
   - `sample_sensor_payload` fixture（完整传感器上报 payload，与设计文档 §4.1.3 一致）
   - `sample_ai_payload` fixture（完整 AI 识别上报 payload，与设计文档一致）
   - `sample_command_response_payload` fixture（命令应答上报 payload）

3. **server/tests/test_health.py** — 健康检查测试（用例 39-40）
   - `test_health_healthy`：调用 `GET /api/v1/health`，DB 正常时验证返回 200，JSON body 包含 `"status":"healthy"`
   - `test_health_degraded`：Mock DB 连接失败，验证返回 503，JSON body 包含 `"status":"degraded"`

4. **server/tests/test_iotda_webhook.py** — IoTDA Webhook 测试（用例 1-9）
   - `test_properties_report`：POST 传感器属性上报到 `POST /api/v1/iotda/properties/report`，验证 200 + `code=0`
   - `test_ai_report`：POST AI 识别结果到 `POST /api/v1/iotda/ai/report`，验证 200 + `code=0`
   - `test_command_response`：POST 命令应答到 `POST /api/v1/iotda/cmd/response`，验证 200 + `code=0`
   - `test_properties_idempotent`：两次相同传感器 payload，验证 200 + 数据库仅一条记录
   - `test_ai_idempotent`：两次相同 AI payload，验证幂等性
   - `test_invalid_payload`：缺少 `notify_data` 的 payload，验证 422
   - `test_unknown_service_id`：`service_id=unknown`，验证 200 但不写入 DB（mock 断言 add 未调用）
   - `test_db_write_failure`：Mock session.add 抛出异常，验证 500
   - `test_device_auto_register`：新 device_id 首次上报，验证自动创建设备记录

5. **server/tests/test_sensor.py** — 传感器查询测试（用例 10-16）
   - `test_latest_with_device_id`：指定 `device_id` 查询最新传感器数据，验证返回单条记录
   - `test_latest_all`：不指定 device_id，验证返回所有设备最新记录
   - `test_history_pagination`：`page=1, page_size=10`，验证返回 10 条 + total 字段
   - `test_history_time_range`：带 `start`/`end` 参数，验证仅返回范围内记录
   - `test_page_size_cap`：`page_size=200`，验证实际 page_size 被截断至 100
   - `test_page_out_of_range`：`page=9999`，验证返回空 records 列表
   - `test_daily_aggregation`：带日期范围查询日聚合数据，验证返回聚合记录

6. **server/tests/test_disease.py** — 病虫害查询测试（用例 18-22）
   - `test_list_with_filters`：带 `crop_type=wheat, severity=Moderate` 筛选，验证返回筛选后记录
   - `test_list_time_range`：仅带时间范围参数，验证返回范围内记录
   - `test_statistics`：调用统计接口，验证返回按作物/严重度/类型的统计数据
   - `test_heatmap`：调用热力图接口，验证返回 heatmap_points + summary 结构
   - `test_empty_result`：无匹配条件的查询，验证返回空 records 列表

7. **server/tests/test_command.py** — 控制接口测试（用例 23-28）
   - `test_send_command_online`：设备在线时下发命令，验证 200 + `status=sent` + 含 command_id
   - `test_send_command_offline`：设备离线时下发命令，验证 200 + `code=1003` 设备离线
   - `test_send_command_missing_field`：缺少 `command` 字段，验证 422
   - `test_logs_source_filter`：带 `source=auto` 参数查询控制日志，验证仅返回自动触发的命令
   - `test_logs_time_range`：带 `start`/`end` 参数查询控制日志
   - `test_logs_pagination`：带 `page=1, page_size=20` 查询控制日志

8. **server/tests/test_advisory.py** — 防治建议测试（用例 29-31）
   - `test_advisory_with_detection`：时间窗口内有最新 AI 识别记录，验证响应含 `latest_detection` 和 `advisory`
   - `test_advisory_no_detection`：时间窗口内无识别记录，验证 `advisory` 为 null
   - `test_advisory_with_env_linkage`：有检测记录且有环境数据，验证响应含 `env_disease_linkage`

9. **server/tests/test_image.py** — 图片管理测试（用例 32-35）
   - `test_upload_image`：上传图片（multipart 格式）关联疾病记录，验证 200 + 返回 image_id
   - `test_upload_image_too_large`：超过 10MB 的文件，验证 422/413
   - `test_get_image`：有效 image_id，验证返回 200 + 二进制流
   - `test_get_image_not_found`：无效 image_id，验证返回 200 + `code=1002`

10. **server/tests/test_device.py** — 设备列表测试（用例 17）
    - `test_device_list`：调用设备列表接口，验证 200 + 返回设备列表含在线状态

## 选择理由

T9 是自动化测试体系的基础子任务。conftest.py 是所有测试文件的公共依赖（pytest 钩子、全局 fixture、Mock 注入），必须先完成。API 单元测试覆盖 T3-T7 创建的全部 7 个 API 端点模块（health、iotda、sensor、disease、command、advisory、image、device），共 37 个 API 单元测试用例（覆盖设计文档 §4.2 中 #1-#35 和 #39-#40），与设计文档的单元测试规格对齐。

所有测试均使用 `httpx.AsyncClient` + `ASGITransport` + `dependency_overrides`（Mock 数据库会话和 API Key 认证），无需真实 PostgreSQL 或 Docker 环境即可独立运行。这是质量验证的第一个和最关键层（单元测试层，<30s 执行）。

建议实现顺序：conftest.py → test_health.py + test_device.py（依赖最少，优先验证）→ 其余 API 测试文件。

## 任务上下文

- **设计文档参考**：`docs/2_vps-deployment.md`
  - §4.1.2 测试目录结构（tests/ 下的子目录划分）
  - §4.1.3 conftest.py 完整代码（含 pytest 钩子、event_loop 和 async_client fixture、sample_sensor_payload/sample_ai_payload 示例 payload）
  - §4.2 API 接口测试表格（48 个测试用例，含输入、预期结果、类型）
  - §4.2.1-4.2.6 每个接口模块的测试用例详细规格（#1-#48）

- **已有代码依赖**：
  - `server/app/main.py` — FastAPI app 实例，可通过 `from app.main import app` 导入
  - `server/app/api/deps.py` — 定义了 `get_db` 和 `verify_api_key` 依赖函数，通过 `app.dependency_overrides` 注入 Mock
  - `server/app/db/session.py` — `SessionLocal` 和 `get_db` 生成器
  - `server/app/config.py` — `Settings` 配置类，测试中可通过环境变量覆盖
  - `server/app/api/v1/` — 全部 7 个端点模块
  - `server/app/services/` — 全部 6 个 Service 层模块
  - `server/app/schemas/` — Pydantic Schema 定义
  - `server/requirements-dev.txt` — 已包含 `pytest~=8.3.0`、`pytest-asyncio~=0.24.0`、`httpx~=0.27.0`

- **API Key 认证跳过**：在 conftest.py 的 async_client fixture 中，通过 `app.dependency_overrides[verify_api_key] = lambda: None` 跳过 API Key 认证，使所有测试无需提供真实 API Key。如需测试认证逻辑，可在 test_iotda_webhook.py 中单独覆盖此行为（因为 IoTDA Webhook 端点本就不需要认证）。

- **DB Session Mock 模式**：使用 `unittest.mock.MagicMock` 创建 `mock_session`，覆盖 `app.dependency_overrides[get_db]` 使其返回该 mock。mock_session 的 `query().filter().order_by().offset().limit().all()` 等链式调用通过 `MagicMock` 的自动链式 mock 支持。对需要控制返回值的测试，通过 `mock_session.query.return_value.filter.return_value.all.return_value = [...]` 设置预定义返回值。

- **目录状态**：`server/tests/` 目录当前不存在，需从零创建。

- **测试文件命名与发现**：文件命名遵循 pytest 的默认发现规则（`test_*.py`），无需额外的配置文件。测试函数也使用 `test_*` 前缀。异步测试函数需要 `@pytest.mark.asyncio` 标记。

## 预期产出

- 10 个测试文件位于 `server/tests/` 目录下
- 所有测试可使用 `pytest tests/ -v` 命令执行（无需 `--run-integration` 等额外参数）
- 通过 Mock 实现纯代码级测试，不依赖外部服务
- test_health.py 和 test_device.py 应首先可运行验证（依赖最少）

## RETRY 说明

本次 RETRY 修正 Plan Review (plan_review_v9_r1.md) 发现的 3 个问题：

1. **测试用例数量声称不精确**：原 task_v9.md 第 78 行声称"48 个测试用例"，已修正为"37 个 API 单元测试用例（覆盖设计文档 §4.2 中 #1-#35 和 #39-#40），与设计文档的单元测试规格对齐"。集成测试、Docker 测试、E2E 测试等不在 T9 范围内，后续子任务处理。
2. **async_client 描述不精确**：原 task_v9.md 第 80 行"TestClient"已修正为"`httpx.AsyncClient` + `ASGITransport`"。conftest.py 中使用异步客户端而非同步 TestClient，与设计文档 §4.1.3 一致。
3. **补充推荐执行顺序**：在选择理由末尾增加了明确的实现顺序建议（conftest.py → test_health.py + test_device.py → 其余文件），与预期产出中"test_health.py 和 test_device.py 应首先可运行验证"对齐。
