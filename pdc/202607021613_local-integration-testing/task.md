# 任务描述

依据 `docs/local-integration-testing.md` 实现集成测试与端到端联调测试代码。

## 产出文件清单

```
server/tests/integration/
  __init__.py              - 包标记文件
  conftest.py              - 集成测试专用 fixture 和配置
  test_db_ddl.py           - DDL / 索引验证
  test_db_crud.py          - CRUD 操作 + 数据保留 + 并发测试
  test_api_integration.py  - Webhook 全链路 API 集成测试

server/tests/
  integration_run.py       - 独立端到端联调脚本
```

## 验证清单

- [ ] `tests/integration/__init__.py` 创建
- [ ] `tests/integration/conftest.py` 创建并验证：
  - [ ] 可自动创建 `farmeye_test` 数据库
  - [ ] `Base.metadata.create_all()` 成功执行
  - [ ] SQL 级 UNIQUE 索引创建成功
  - [ ] 事务回滚隔离生效（测试间数据不残留）
  - [ ] FastAPI 依赖注入被正确覆盖
- [ ] `test_db_ddl.py` 全部用例通过
- [ ] `test_db_crud.py` 全部用例通过（含防重复、数据保留、并发）
- [ ] `test_api_integration.py` 全部用例通过
- [ ] `integration_run.py` 七步全部 `[PASS]`
- [ ] 已有单元测试不受影响（`pytest` 无参数时集成测试跳过）
- [ ] 集成测试默认跳过（`pytest -v` 不执行 integration 标记用例）

## 关键约束

1. 集成测试代码位于 `server/tests/integration/` 独立目录
2. 所有集成测试用例标记 `@pytest.mark.integration`，默认跳过
3. conftest 使用事务级回滚隔离，测试间互不污染
4. conftest 需要覆盖 `get_db` 为真实数据库 Session，覆盖 `verify_api_key` 跳过认证
5. 端到端脚本独立于 pytest，使用 `httpx` 对运行中的 Docker 容器组进行黑盒 HTTP 测试
6. 不破坏已有单元测试
