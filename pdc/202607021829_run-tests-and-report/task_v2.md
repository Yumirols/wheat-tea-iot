# 任务指令（v2）

## 动作
NEW

## 任务描述

### 前置步骤：检查/清理环境
1. 可选：先执行 `docker compose --profile dev down` 确保无残留容器干扰

### 步骤一：启动 PostgreSQL 容器
在 `server/` 目录执行：
```
docker compose --profile dev up -d db
```

**验证标准：**
- 容器 `farmeye-db` 启动成功，状态为 healthy
- PostgreSQL 16 监听 `127.0.0.1:5432`
- 可使用 `docker compose ps` 或 `docker ps` 确认

### 步骤二：运行集成测试
在 `server/` 目录执行：
```
PYTHONUTF8=1 pytest tests/integration/ --run-integration -v
```

**验证标准：**
- 集成测试 conftest 自动创建 `farmeye_test` 数据库并建表
- `test_db_ddl.py` — 表结构、索引、约束、列类型验证全部 PASS
- `test_db_crud.py` — 传感器CRUD、病害CRUD、控制日志CRUD、设备CRUD、数据保留、并发写入、每日聚合全部 PASS
- `test_api_integration.py` — 属性上报-告警全链路、AI识别-告警全链路、命令下发、告警环境联动全部 PASS
- 无 FAILED 用例
- 无报错或异常退出

### 步骤三：保存输出
将完整的终端输出保存到工作目录 `pdc/202607021829_run-tests-and-report/it_output.txt`。

### 步骤四：编写执行报告
编写 `do_v2.md` 执行报告，包含：
- 执行过程描述
- 测试结果汇总（总用例数、通过数、跳过数、失败数）
- 详细通过/跳过用例清单
- 如有失败，记录详细错误信息和初步根因分析
- 偏差说明（如有）

## 选择理由

R2 是任务链条第二步，在 R1 单元测试验证通过后，引入 PostgreSQL 数据库依赖执行集成测试。集成测试验证的是真实数据库操作的正确性（DDL、CRUD、数据保留、并发写入、API 全链路），覆盖了 Mock 无法验证的数据库交互行为。先独立启动数据库容器而不是完整 Docker 组，可以隔离数据库相关的问题。

## 任务上下文

- 工作根目录：`E:\dev\wheat-tea-iot`
- 测试根目录：`E:\dev\wheat-tea-iot\server`（pytest 在此执行）
- Docker Compose 文件：`E:\dev\wheat-tea-iot\server\docker-compose.yml`
- 数据库服务定义：
  - image: postgres:16-alpine
  - container_name: farmeye-db
  - ports: 127.0.0.1:5432:5432
  - 用户: farmeye / farmeye_pwd / farmeye_db
  - healthcheck: pg_isready -U farmeye -d farmeye_db
- 测试数据库配置：
  - Settings.DATABASE_URL 默认值：`postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db`
  - 集成测试自动在 `farmeye_test` 数据库上执行（DDL 建表和 SQL 索引）
  - 每个测试函数使用独立事务，结束后 ROLLBACK 回滚
- 集成测试文件（3 个）：
  - `tests/integration/test_db_ddl.py` — 21 个用例：表存在性(6)、索引存在性(8)、约束校验(3)、列类型(2)
  - `tests/integration/test_db_crud.py` — 11 个用例：传感器CRUD(3)、病害CRUD(2)、控制日志CRUD(1)、设备CRUD(2)、数据保留(3)、并发写入(1)、每日聚合(1)
  - `tests/integration/test_api_integration.py` — 6 个用例：属性上报-告警(2)、AI识别-告警(2)、命令下发(1)、告警环境联动(1)
- 环境配置：无 `.env` 文件，pydantic-settings 使用默认 DATABASE_URL（与 Docker 容器凭据一致）
- 开发环境：Windows 11，Docker Desktop 可用
- **约束**：不要修改任何源代码文件

## 已有产出上下文

R1 已通过，产出包括：
- `pdc/202607021829_run-tests-and-report/ut_output.txt` — 单元测试完整输出（37 passed, 38 skipped）
- `pdc/202607021829_run-tests-and-report/do_v1.md` — R1 执行报告
- `pdc/202607021829_run-tests-and-report/check_v1.md` — R1 检查报告（PASSED）
