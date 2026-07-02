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

## 整体轮次规划
- R1 [T1]: 集成测试基础设施 (__init__.py + conftest.py) ← 已完成 PASSED
- R2 [T2]: test_db_ddl.py DDL/索引验证测试 ← 当前轮次
- R3 [T3]: test_db_crud.py CRUD操作+数据保留+并发测试
- R4 [T4]: test_api_integration.py API全链路测试
- R5 [T5]: integration_run.py 端到端联调脚本
