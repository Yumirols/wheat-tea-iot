# 任务指令（v2）

## 动作
NEW

## 任务描述
依据 `docs/local-integration-testing.md` SS7.3 的完整代码实现，在 `server/tests/integration/test_db_ddl.py` 创建 DDL/索引验证测试文件。

文件包含以下 4 个测试类（共约 17 个测试用例）：
1. **TestTableExistence** — 验证 5 个表的存在性和列结构
2. **TestIndexExistence** — 验证所有 UNIQUE 索引和普通索引的存在性
3. **TestConstraintEnforcement** — 验证 UNIQUE 约束在 DB 层面正确执行
4. **TestColumnTypes** — 验证关键列的数据类型精度

## 选择理由
- test_db_ddl.py 是集成测试中按依赖顺序的第二个文件，依赖 conftest 提供的 `db_session` fixture，不依赖其他测试文件
- 独立性好，可以单独运行和验证
- 内容在设计中已完整定义（SS7.3），只需按文档复制实现，无需自行设计逻辑

## 任务上下文
- 设计文档 `docs/local-integration-testing.md` SS7.3 已完整定义 test_db_ddl.py 的全部代码（约 340 行）
- 所有用例标记 `@pytest.mark.integration`
- 部分用例标记 `@pytest.mark.slow`（test_all_tables_exist、test_sensor_unique_violation、test_device_unique_violation）
- 依赖 conftest.py 的 `db_session` fixture
- 文件路径：`server/tests/integration/test_db_ddl.py`
- 需导入模块：`pytest`, `sqlalchemy.inspect`, `sqlalchemy.text`, `sqlalchemy.orm.Session`
- 约束执行验证类中需导入 `app.models.sensor.SensorSnapshot`, `app.models.control.Device`, `app.models.control.ControlLog`

## 已有产出上下文
- `server/tests/integration/__init__.py` — 包标记文件（已存在）
- `server/tests/integration/conftest.py` — 集成测试核心 infrastructure fixture（已存在）
  - 提供 `test_engine` (session-scoped) 引擎、`db_session` (function-scoped) 事务回滚会话
  - 提供 `override_deps` (autouse) 自动覆盖依赖注入
