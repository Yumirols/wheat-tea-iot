# 任务计划

任务描述：执行 server/ 项目全部测试并产出测试报告（test_report.md）
工作目录：E:\dev\wheat-tea-iot\pdc\202607021829_run-tests-and-report

---

## R1 NEW 运行单元测试 [ID: T1]
任务：安装依赖后执行 `pytest -v` 运行单元测试，验证全部通过、集成测试被跳过。

选择理由：
- 单元测试是第一步且最快（无外部依赖），先确认基础正确性
- 包含必要的依赖安装前置操作

上下文：
- 工作目录：server/
- 测试配置：server/pytest.ini — asyncio_default_fixture_loop_scope = function, testpaths = tests
- 全局 conftest 自动跳过 integration/docker/e2e/performance 标记
- 8 个单元测试文件，3 个集成测试文件（预期被跳过）
- 前置条件：pip install -r requirements.txt -r requirements-dev.txt
- 产出保存到工作目录 ut_output.txt

## 后续轮次规划
- R2 [T2]: 启动 PostgreSQL 容器并运行集成测试（pytest --run-integration）
- R3 [T3]: 启动完整 Docker 组并运行端到端联调脚本
- R4 [T4]: 综合三部分测试结果产出 test_report.md
