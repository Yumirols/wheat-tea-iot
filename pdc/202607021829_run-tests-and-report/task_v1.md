# 任务指令（v1）

## 动作
NEW

## 任务描述

### 前置步骤：安装依赖
在 `server/` 目录执行：
```
pip install -r requirements.txt -r requirements-dev.txt
```

### 执行测试
在 `server/` 项目根目录执行单元测试，具体要求：

1. **执行命令**：`cd server && pytest -v`
2. **验证标准**：
   - 所有非标记（非 integration/docker/e2e/performance）的测试用例全部 PASS
   - 集成测试目录 `tests/integration/` 下的用例被正确跳过（skip），原因是未传 `--run-integration` 选项
   - 无报错或异常退出
3. **产出物**：
   - 将完整的终端输出保存到工作目录 `pdc/202607021829_run-tests-and-report/ut_output.txt`
   - 在报告中记录：总用例数、通过数、跳过数、失败数
   - 如有失败，记录详细的失败信息和堆栈

## 选择理由

单元测试是整个测试工作链的第一步，也是最快的一步（无外部依赖）。先确认基础功能正确，再逐步引入数据库和容器依赖的测试。如果单元测试失败，后续测试无意义。运行测试前先确保依赖完整安装。

## 任务上下文

- 工作根目录：`E:\dev\wheat-tea-iot`
- 测试根目录：`E:\dev\wheat-tea-iot\server`（pytest 在此执行）
- 测试配置：
  - `server/pytest.ini`：asyncio_default_fixture_loop_scope = function，testpaths = tests
  - `server/tests/conftest.py`：自动跳过标记类测试（integration/docker/e2e/performance），默认覆盖 `get_db` 为 Mock 会话、跳过 API Key 认证
- 单元测试文件列表（8 个）：
  - `server/tests/test_advisory.py`
  - `server/tests/test_command.py`
  - `server/tests/test_device.py`
  - `server/tests/test_disease.py`
  - `server/tests/test_health.py`
  - `server/tests/test_image.py`
  - `server/tests/test_iotda_webhook.py`
  - `server/tests/test_sensor.py`
- 集成测试目录（3 个文件，预期被跳过）：
  - `server/tests/integration/test_db_ddl.py`
  - `server/tests/integration/test_db_crud.py`
  - `server/tests/integration/test_api_integration.py`
- 依赖安装：`pip install -r requirements.txt -r requirements-dev.txt`（在 server/ 目录下执行）
- 开发环境：Windows 11，Python 应当已安装（使用 venv 或系统 Python）
- **约束**：不要修改任何源代码文件

## 已有产出上下文

工作目录当前仅包含任务描述文件 `task.md`，尚无任何测试产出。

