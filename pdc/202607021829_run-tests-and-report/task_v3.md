# 任务指令（v3）

## 动作
NEW

## 任务描述

### 前置步骤：清理环境
在 `server/` 目录执行：
```
docker compose --profile dev down
```
确保无残留容器干扰。

### 步骤一：启动完整 Docker 组
在 `server/` 目录执行：
```
docker compose --profile dev up -d
```

**验证标准：**
- 容器 `farmeye-db` 启动成功，状态为 healthy
- 容器 `farmeye-api-dev` 启动成功
- 可使用 `docker compose ps` 或 `docker ps` 确认

### 步骤二：等待服务就绪
等待 api-dev 容器完全启动（约 5-10 秒）。可通过以下方式确认：
- `docker compose logs api-dev` 查看启动日志
- 或直接运行联调脚本（脚本内部有超时处理）

### 步骤三：运行端到端联调脚本
在 `server/` 目录执行：
```
python tests/integration_run.py
```

**预期结果（如实记录）：**
- step_health_check（步骤 1）——可能 PASS：FastAPI 启动时 `health` 端点不依赖数据库 schema，仅检查 DB 连接是否可达
- 后续步骤（步骤 2-7）——可能 FAIL：数据库写入操作依赖 ORM 模型，已知 `server_default` 字符串语法问题会导致 DDL 执行失败

### 步骤四：保存输出
将完整的终端输出保存到工作目录 `pdc/202607021829_run-tests-and-report/e2e_output.txt`。

### 步骤五：编写执行报告
编写 `do_v3.md` 执行报告，包含：
- 执行过程描述
- 容器启动状态（各容器是否正常运行）
- 联调脚本结果汇总（逐步骤记录 PASS/FAIL）
- 如有失败，记录详细错误信息和初步根因分析
- 偏差说明（如有）

## 选择理由

R2 已确认数据库容器可正常启动但 ORM schema 存在 `server_default` 语法 bug 导致集成测试全部失败。R3 启动完整 Docker 组（api-dev + db）运行独立的端到端联调脚本 `integration_run.py`。该脚本从外部黑盒视角通过真实 HTTP 请求验证七步闭环流程，不依赖 pytest 框架。预期 health check 可能通过但后续步骤可能因已知的 schema 问题失败。如实记录结果即可，为 R4 的测试报告综合提供数据。

## 任务上下文

- 工作根目录：`E:\dev\wheat-tea-iot`
- Docker Compose 文件：`E:\dev\wheat-tea-iot\server\docker-compose.yml`
- 端到端联调脚本：`E:\dev\wheat-tea-iot\server\tests\integration_run.py`
- 服务定义：
  - api-dev：开发模式，基于 ubuntu:25.04，端口 8000，热重载，依赖 db 健康
  - db：postgres:16-alpine，端口 5432，用户 farmeye/farmeye_pwd，库 farmeye_db
- 已知根因：ORM 模型 `server_default="CURRENT_TIMESTAMP"` 字符串字面量问题
  - 影响文件：`app/models/sensor.py`（3 处）、`app/models/disease.py`（2 处）、`app/models/control.py`（4 处）
  - 表现：Base.metadata.create_all() 生成 DDL 时误将函数渲染为带引号的字符串
  - 影响范围：集成测试全部 38 个用例 ERROR at setup；联调脚本的健康检查之外的步骤可能受影响
- 联调脚本七步流程：
  1. 健康检查（GET /api/v1/health，无需认证）
  2. 上报环境数据（POST /api/v1/iotda/properties/report）
  3. 校验最新快照（GET /api/v1/sensor/latest）
  4. 触发病虫害决策（POST /api/v1/iotda/ai/report）
  5. 查询防治建议（GET /api/v1/advisory）
  6. 模拟下发控制指令（POST /api/v1/command/send）
  7. 控制状态闭环校验（POST + GET /api/v1/command/logs）
- 无需 .env 文件：api-dev 服务从 docker-compose.yml 定义的 env_file 读取 `.env.dev`，但该文件可能不存在；pydantic-settings 的内置默认值应与 Docker 容器内环境兼容
- **约束**：不要修改任何源代码文件

## 已有产出上下文

R2 已通过，产出包括：
- `pdc/202607021829_run-tests-and-report/it_output.txt` — 集成测试完整输出（38 ERROR，全部源于 InvalidDatetimeFormat）
- `pdc/202607021829_run-tests-and-report/do_v2.md` — R2 执行报告
- `pdc/202607021829_run-tests-and-report/check_v2.md` — R2 检查报告（PASSED）
- PostgreSQL 容器 farmeye-db 当前仍处于运行状态
