# 任务指令（v1）

## 动作
NEW

## 任务描述

依据 `docs/local-integration-testing.md` 第 7 节中的完整代码实现，创建集成测试的基础设施文件：

### 1. `server/tests/integration/__init__.py`
- 包标记文件，写入模块 docstring 标记
- 内容见 design doc SS7.1

### 2. `server/tests/integration/conftest.py`
提供集成测试所需的核心基础设施，包括：

- **test_engine（session-scoped）**：
  - 连接 postgres 库，检查/创建 `farmeye_test` 测试数据库
  - `Base.metadata.create_all()` 物理建表
  - 额外创建 SQL 级别的 UNIQUE 索引（`idx_sensor_device_time`、`idx_disease_device_time`、`idx_control_command_id` 等）

- **db_session（function-scoped）**：
  - 每个测试使用独立连接和 BEGIN 事务
  - 测试结束后 ROLLBACK 事务，实现测试间完全隔离

- **override_deps（autouse）**：
  - 覆盖 FastAPI `get_db` 为真实事务 Session（覆盖全局 conftest 的 mock 覆盖）
  - 覆盖 `verify_api_key` 跳过认证

- **async_client（pytest_asyncio）**：
  - 使用 ASGITransport 包装 FastAPI app
  - 确保依赖覆盖已生效

- **共享测试数据 fixture**：`test_device_id`、`sample_sensor_properties`、`sample_sensor_payload`、`sample_ai_payload_high`、`sample_ai_payload_moderate`

完整代码参见 `docs/local-integration-testing.md` SS7.1 - SS7.2。

## 选择理由

基础设施优先原则。`conftest.py` 是所有集成测试的依赖基石，`test_db_ddl.py`、`test_db_crud.py`、`test_api_integration.py` 均依赖 conftest 提供的事务 Session、依赖覆盖和测试数据 fixture。必须先完成基础设施才能进行后续测试文件的开发与验证。

## 任务上下文

### 关键约束
1. 集成测试代码位于 `server/tests/integration/` 独立目录
2. 所有集成测试用例标记 `@pytest.mark.integration`，默认跳过
3. conftest 使用事务级回滚隔离，测试间互不污染
4. conftest 需要覆盖 `get_db` 为真实数据库 Session，覆盖 `verify_api_key` 跳过认证
5. 不破坏已有单元测试

### 环境配置
- 测试数据库 URL 从 `settings.DATABASE_URL` 推导：将 `farmeye_db` 替换为 `farmeye_test`
- 管理员连接 URL 将 `farmeye_db` 替换为 `postgres`（用于 CREATE DATABASE）
- `settings.DATABASE_URL` 默认值为 `postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db`

### 与全局 conftest.py 的协作
- 全局 conftest 已注册 `--run-integration` 选项，`integration` 标记，以及自动跳过未启用的标记测试
- 全局 conftest 的 `override_dependencies` 将 `get_db` 覆盖为 `mock_db_session`
- 集成 conftest 的 `override_deps` 需在其后执行，覆盖为真实 Session
- `pytest_collection_modifyitems` 由全局 conftest 处理，集成 conftest 无需重复

## 已有产出上下文

- `docs/local-integration-testing.md` — 完整设计方案，SS7 包含完整代码实现
- `server/tests/integration/` — 目录已存在但无 Python 文件
- `server/tests/conftest.py` — 全局测试配置，已包含标记注册和跳过逻辑
- `server/app/config.py` — 配置管理，`DATABASE_URL` 默认值定义
- `server/app/db/base.py` — SQLAlchemy Base 声明
- `server/app/api/deps.py` — `get_db` 和 `verify_api_key` 依赖定义
