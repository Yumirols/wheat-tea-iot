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

## R2 PASSED 启动 PostgreSQL 容器并运行集成测试 [ID: T2]
结果：PostgreSQL 容器启动成功（farmeye-db healthy）。38 个集成测试全部 ERROR at setup，根因是 ORM 模型 `server_default="CURRENT_TIMESTAMP"` 字符串语法问题（SQLAlchemy 将字符串加引号渲染导致 PostgreSQL 拒绝 DDL）。Doer 如实记录了失败结果和根因分析。
检查：PASSED — 7 项检查全部通过（输出文件存在、38 ERROR 统计、InvalidDatetimeFormat 确认、容器运行正常、根因分析准确、修正方案正确、未修改源代码）。

---

## R3 NEW 启动完整 Docker 组并运行端到端联调脚本 [ID: T3]
任务：
  1. 清理环境：`docker compose --profile dev down`（移除之前的容器残留）
  2. 启动完整 Docker 组：`docker compose --profile dev up -d`（启动 api-dev + db 两个服务）
  3. 启动后先确认 api-dev 容器日志，等待服务就绪（可通过 `docker compose logs api-dev` 或等待一段时间后直接运行联调脚本）
  4. 执行端到端联调脚本：`python tests/integration_run.py`（在 server/ 目录下执行）
  5. 将完整终端输出保存到工作目录 `pdc/202607021829_run-tests-and-report/e2e_output.txt`
  6. 编写 `do_v3.md` 执行报告，包含执行过程、逐步骤结果、根因分析（如有失败）

选择理由：R2 已确认数据库容器可正常启动但 ORM schema 存在 bug 导致集成测试全部失败。R3 启动完整 Docker 组（api-dev + db）运行独立于 pytest 的端到端联调脚本。该脚本从外部黑盒视角通过真实 HTTP 请求验证七步闭环流程。预期 health check 步骤可能通过（因为 FastAPI 启动不依赖 schema 验证），但后续步骤（如数据写入、查询）可能因 `server_default` 问题失败。如实记录每一步骤结果即可。

上下文：
- 工作根目录：`E:\dev\wheat-tea-iot`
- Docker Compose 文件：`E:\dev\wheat-tea-iot\server\docker-compose.yml`
- 端到端脚本：`E:\dev\wheat-tea-iot\server\tests\integration_run.py`
- docker-compose.yml 已定义 api-dev（开发模式，热重载）和 db（postgres:16-alpine）两个服务
- 根因已知：ORM 模型的 server_default 字符串语法问题，对应 3 个模型文件（sensor.py、disease.py、control.py）共 9 处
- 联调脚本七步流程：健康检查 → 上报环境数据 → 校验最新快照 → 触发病虫害决策 → 查询防治建议 → 模拟下发控制指令 → 控制状态闭环校验
- **约束**：不要修改任何源代码文件
