# 计划审查报告（v9 r1）

## 审查结果
REJECTED

## 发现

### [一般] 测试用例数量声称与实际清单不一致

**位置**：计划第 194 行 "与设计文档 §4.1-4.2 的 48 个测试用例完全对齐"

**问题**：计划的选择理由声称 T9 覆盖"48 个测试用例"，但文件的逐项描述仅列出 37 个 API 单元测试用例（编号 #1-35、#39-40）。设计文档 §4.2 的 48 个测试用例包含集成测试、Docker 测试、端到端测试等，这些不在 T9 子任务范围内。task_v9.md 对此的表述是"40+ 个测试用例"（第 78 行），计划偏离了任务规格。

**为什么是问题**：可能导致 Do 阶段误解范围，试图实现超范围的 11 个测试用例（含集成/e2e/Docker 测试），造成 Scope Creep。

**修正方向**：将"48 个测试用例"改为明确表述，例如"37 个 API 单元测试用例（覆盖设计文档 §4.2 中 #1-#35 和 #39-#40），与设计文档的单元测试规格对齐"。

### [轻微] async_client fixture 描述不精确

**位置**：计划第 184 行 "async_client 依赖覆盖 TestClient"

**问题**：task_v9.md 明确要求使用 `httpx.AsyncClient` + `ASGITransport`（异步版本），而"TestClient"是 Starlette 同步测试客户端。两者 API 签名不同（async/await vs 同步调用），不同的命名可能导致实现阶段误用错误的客户端类。

**修正方向**：改为"async_client（httpx.AsyncClient + ASGITransport，通过 dependency_overrides 注入 Mock）"。

### [轻微] 未体现推荐执行顺序

**位置**：计划第 181-193 行 T9 任务描述及第 194-195 行选择理由

**问题**：task_v9.md 第 113 行明确建议"test_health.py 和 test_device.py 应首先可运行验证（依赖最少）"，但计划未提及此优先级信息。

**修正方向**：在任务描述或选择理由中补充建议执行顺序，例如"建议按 conftest.py → test_health.py + test_device.py（依赖最少优先验证）→ 其余 API 测试文件的顺序执行"。
