# 执行审查报告（v9 r1）

## 审查结果
REJECTED

## 发现

### **[一般]** `test_unknown_service_id` 缺少 DB 未写入断言

**文件**: `server/tests/test_iotda_webhook.py` 第 190-218 行

**问题**: 任务规范（task_v9.md 第 34 行）明确要求该测试应 "验证 200 但不写入 DB（mock 断言 add 未调用）"。实际测试只验证了 HTTP 200 和 `code=0`，但没有添加 `mock_db_session.add.assert_not_called()` 或等效断言来确认未知 service_id 未被持久化。测试注释（第 215-218 行）也承认 "此处只验证接口返回正常"。

**为什么是问题**: 缺少关键断言，测试无法覆盖 "service_id 不匹配时不写入 DB" 这一核心验证点。如果端点实现发生变化（例如错误地开始写入所有 service_id），此测试仍然通过，无法捕获回归。

**期望修正方向**: 在测试函数末尾添加 `mock_db_session.add.assert_not_called()` 断言，验证未知 service_id 确实未被持久化到数据库。

### **[轻微]** 缺少 `event_loop` fixture

**文件**: `server/tests/conftest.py` 第 1-213 行

**问题**: 任务规范（task_v9.md 第 17 行）要求 conftest.py 包含 "event_loop fixture（session 级，复用事件循环）"。Doer 使用 `pytest.ini` 中的 `asyncio_default_fixture_loop_scope = function` 替代了该 fixture。

**为什么是问题**: 功能等效（使用 pytest-asyncio 0.24+ 的推荐配置方式），但与任务规范中的明确要求不符。

**期望修正方向**: 在 conftest.py 中添加 session 级别的 `event_loop` fixture，或更新任务规范以反映 pytest.ini 配置方式为可接受方案。

### 其他说明

以下偏离已记录在执行报告中，审查确认属于合理调整：

- **test_page_size_cap**（用例 #14）：端点 Query 参数声明 `le=100`，FastAPI 校验层直接拒绝 200 返回 422。测试调整为验证 422，实际效果一致（上限 100 被强制实施），正确。
- **test_get_image_not_found**（用例 #35）：实际端点抛出 `HTTPException(404)` 返回 404，测试验证 404 + `code=1002`。测试按实际代码行为编写，正确。
- **test_db_write_failure**（用例 #8）：实际端点全局 catch 异常返回 200 + `code=0`，测试验证 200 + `code=0`。单元测试应测试实际代码行为，正确。

### 覆盖度验证

| 验证项 | 状态 |
|--------|------|
| 10 个测试文件全部创建 | 通过（含 pytest.ini 共 11 个文件） |
| conftest.py：pytest 钩子（addoption/configure/collection_modifyitems） | 通过 |
| conftest.py：mock_db_session fixture | 通过 |
| conftest.py：override_dependencies autouse fixture（verify_api_key + get_db） | 通过 |
| conftest.py：async_client (httpx.AsyncClient + ASGITransport) | 通过 |
| conftest.py：sample payload fixtures（3 个） | 通过 |
| conftest.py：event_loop fixture | **缺失**（使用 pytest.ini 替代） |
| 37 个测试用例全部实现 | 通过 |
| 所有测试通过（37 passed） | 通过 |
| 无需真实 DB / Docker | 通过 |
