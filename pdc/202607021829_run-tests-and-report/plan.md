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

---

## R1 PASSED 运行单元测试 [ID: T1]
结果：37 passed, 38 skipped, 0 failed。所有非标记单元测试全部 PASS，集成测试被正确跳过（38 个）。依赖安装解决了 Windows GBK 编码问题。
检查：PASSED — 7 项检查全部通过，实际测试数据与执行报告一致，未修改源代码文件。

---

## R2 NEW 启动 PostgreSQL 容器并运行集成测试 [ID: T2]
任务：启动 `docker compose --profile dev up -d db`，然后执行 `pytest tests/integration/ --run-integration -v`，验证 DDL、CRUD、数据保留、并发写入和 API 全链路集成测试全部通过。
选择理由：R1 单元测试验证基础正确性后，R2 引入真实数据库依赖进行集成测试。先单独启动数据库容器而非完整 Docker 组，可隔离数据库相关问题。
