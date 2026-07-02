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

## 整体轮次规划
- R1 [T1]: 集成测试基础设施 (__init__.py + conftest.py) ← 当前轮次
- R2 [T2]: test_db_ddl.py DDL/索引验证测试
- R3 [T3]: test_db_crud.py CRUD操作+数据保留+并发测试
- R4 [T4]: test_api_integration.py API全链路测试
- R5 [T5]: integration_run.py 端到端联调脚本
