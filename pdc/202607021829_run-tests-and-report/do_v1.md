# 执行报告（v1）

## 概述

完成了 task_v1.md 指定的两项任务：在 `server/` 目录安装测试依赖，以及执行单元测试。所有非标记测试用例全部 PASS，集成测试用例被正确跳过（38 个），无失败。

## 产出清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | `pdc/202607021829_run-tests-and-report/ut_output.txt` | pytest 完整终端输出 |
| 新建 | `pdc/202607021829_run-tests-and-report/do_v1.md` | 执行报告 |

## 执行过程

### 步骤一：安装测试依赖

在 `server/` 目录执行 `pip install -r requirements.txt -r requirements-dev.txt`。首次执行时遇到 `UnicodeDecodeError: 'gbk' codec can't decode byte 0xaf` 错误，原因是 Windows 环境下 pip 默认使用 GBK 编码读取 UTF-8 编码的 requirements 文件。通过设置环境变量 `PYTHONUTF8=1` 解决，重新执行后全部依赖安装成功。

### 步骤二：执行单元测试

在 `server/` 目录使用 `pytest -v` 执行测试，同样使用 `PYTHONUTF8=1` 避免编码问题。

**测试结果汇总：**
- 总用例数：75
- 通过数：37
- 跳过数：38
- 失败数：0
- 告警数：5（均为 deprecation warning，不影响功能）
- 耗时：0.46s

**详细通过用例（37 个）：**
- `test_advisory.py`：3 个（test_advisory_with_detection, test_advisory_no_detection, test_advisory_with_env_linkage）
- `test_command.py`：6 个（test_send_command_online, test_send_command_offline, test_send_command_missing_field, test_logs_source_filter, test_logs_time_range, test_logs_pagination）
- `test_device.py`：1 个（test_device_list）
- `test_disease.py`：5 个（test_list_with_filters, test_list_time_range, test_statistics, test_heatmap, test_empty_result）
- `test_health.py`：2 个（test_health_healthy, test_health_degraded）
- `test_image.py`：4 个（test_upload_image, test_upload_image_too_large, test_get_image, test_get_image_not_found）
- `test_iotda_webhook.py`：9 个（test_properties_report, test_ai_report, test_command_response, test_properties_idempotent, test_ai_idempotent, test_invalid_payload, test_unknown_service_id, test_db_write_failure, test_device_auto_register）
- `test_sensor.py`：7 个（test_latest_with_device_id, test_latest_all, test_history_pagination, test_history_time_range, test_page_size_cap, test_page_out_of_range, test_daily_aggregation）

**详细跳过用例（38 个，全部来自集成测试目录 `tests/integration/`）：**
- `tests/integration/test_api_integration.py`：6 个跳过（TestPropertiesReportFlow 2 个, TestAiReportAdvisoryFlow 2 个, TestCommandFlow 1 个, TestAdvisoryEnvLinkage 1 个）
- `tests/integration/test_db_crud.py`：11 个跳过（TestSensorSnapshotCRUD 3 个, TestDiseaseRecordCRUD 2 个, TestControlLogCRUD 1 个, TestDeviceCRUD 2 个, TestDataRetention 3 个, TestConcurrentWrites 1 个, TestDailyAggregation 1 个）
- `tests/integration/test_db_ddl.py`：21 个跳过（TestTableExistence 6 个, TestIndexExistence 8 个, TestConstraintEnforcement 3 个, TestColumnTypes 2 个）

**告警说明（5 个，均无功能影响）：**
1. `app/main.py:49` - `on_event` 被弃用，建议使用 lifespan 事件处理器（FastAPI 启动事件）
2. `fastapi/applications.py:4495` - 同上（FastAPI 内部路由层）
3. `app/main.py:60` - `on_event` 被弃用（FastAPI 关闭事件）
4. `tests/conftest.py:84` - 自定义 `event_loop` fixture 被弃用

### 步骤三：保存输出

将 pytest 完整输出保存到 `pdc/202607021829_run-tests-and-report/ut_output.txt`。

## 偏差说明

无。所有测试按预期运行：
- 37 个单元测试全部 PASS
- 38 个集成测试因未传 `--run-integration` 选项被正确跳过
- 无报错或异常退出
- 未修改任何源代码文件
