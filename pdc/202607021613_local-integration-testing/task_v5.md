# 任务指令（v5）

## 动作
NEW

## 任务描述
依据 `docs/local-integration-testing.md` SS7.6（行 2059-2509）的完整代码，在 `server/tests/integration_run.py` 创建独立端到端联调脚本。

预期产出：
- `server/tests/integration_run.py` — 独立可执行的 httpx 黑盒端到端联调脚本
- 完整执行七步联调流程：健康检查 → 上报环境数据 → 校验快照 → AI 上报 → 查询建议 → 下发命令 → 闭环校验
- 退出码 0（全部通过）/ 1（任一步失败）
- 每一行代码应与设计文档 SS7.6 逐字符一致

## 选择理由
- 这是验证清单中的最后一项（第 8 项），完成后全部 9 项验证项均可勾选
- T1-T4 已全部 PASSED，集成测试代码覆盖了 DDL 验证、CRUD 操作、API 全链路测试
- integration_run.py 是独立的黑盒测试脚本，不依赖 pytest 环境，是上线前最后一道防线
- 使用 httpx 库对运行中的 Docker 容器组进行真实 HTTP 测试

## 任务上下文
- 设计文档 SS7.6（行 2059-2509）已完整定义 integration_run.py 的全部代码，约 450 行
- 使用 httpx 库，不使用 pytest
- 七步联调流程：健康检查→上报环境数据→校验快照→AI上报→查询建议→下发命令→闭环校验
- 环境变量配置：BASE_URL、API_KEY、DEVICE_ID
- `server/tests/integration_run.py` 文件尚不存在，需新建

## 已有产出上下文
工作目录 `server/tests/integration/` 中已有：
- `__init__.py` — 包标记（已 PASSED）
- `conftest.py` — 集成测试基础设施（已 PASSED）
- `test_db_ddl.py` — DDL/索引验证（已 PASSED）
- `test_db_crud.py` — CRUD 操作测试（已 PASSED）
- `test_api_integration.py` — API 全链路集成测试（已 PASSED）

本任务产出 integration_run.py 是独立的，不依赖上述任何文件。
