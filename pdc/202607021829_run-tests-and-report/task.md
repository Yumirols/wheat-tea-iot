# 任务描述

执行 `server/` 项目的全部测试并产出测试报告。测试范围包括：

1. **单元测试** — `pytest -v`（无额外参数），确认集成测试默认跳过、已有单元测试全部通过
2. **数据库集成测试** — 启动 PostgreSQL 容器后执行 `pytest tests/integration/ --run-integration -v`，确认环境隔离、DDL验证、CRUD操作、数据保留和API全链路测试通过
3. **端到端联调脚本** — 启动完整 Docker 组后执行 `python tests/integration_run.py`，确认七步闭环全部通过

## 前置条件

- 单元测试：无外部依赖
- 集成测试：需要 PostgreSQL 16 容器（`docker compose --profile dev up -d db`）
- E2E 联调：需要完整 Docker 容器组（`docker compose --profile dev up -d`）

## 产出物

- `test_report.md` — 完整的测试执行报告，包含：
  - 测试环境信息
  - 各测试类型的执行命令和结果
  - 逐用例状态（通过/失败/跳过）
  - 失败用例的分析和根因
  - 测试结论（是否全部通过）

## 约束

- 测试在本地开发环境中执行（Windows 11）
- 工作目录 `server/`
- 如有测试失败，需要在报告中记录详细错误信息和初步根因分析
- 不要修改任何源代码文件
