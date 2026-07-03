# 计划审查报告（R1 r1）

## 审查结果

APPROVED

## 发现

### [轻微] 1. 未明确声明 EntryBackupAbility.ets 保持现状

`plan_task.md` 的"配置（保持现状）"只列出 `main_pages.json`、`module.json5`、`Index.ets`，但实际模板中存在 `entrybackupability/EntryBackupAbility.ets`（系统模板生成的备份 Ability，与 PollingManager 无关）。虽然保持不变是显而易见的，但为避免后续 Coder/Verifier 误以为遗漏，建议显式标注"EntryBackupAbility.ets 不变"。

### [轻微] 2. `PollingManager.start` 参数命名与设计文档略有出入

`plan_task.md` 第 23 行写 `start(key, fn, intervalMs)`，而 `docs/4_hamony-architecture.md` 第 233 行使用 `start(key, fn, interval)`。占位实现阶段两种命名均能编译通过，但与设计文档保持一致可避免后续 R2-R7 引用时风格漂移。期望修正方向：可统一为 `intervalMs`（语义更清晰）或 `interval`（贴合设计文档）。

### [轻微] 3. `api.ets` 的 `ApiRequestOptions` 类型作用域未明确

`plan.md` 第 66 行指出"`ApiRequestOptions { method, headers?, body?, expectDataType?, timeoutMs? }` 在同文件定义"，但未说明是 `interface` 还是 `class`，以及是否 `export`。若仅为 `api.ets` 内部使用，应保持文件内私有（不 `export`），避免向 `HttpClient` 暴露传输细节（违反"业务层不感知传输层细节"的设计原则）。若需 `HttpClient` 引用，则需要 `export` 并明确为 `interface`。期望修正方向：在 Coder 阶段明确为文件内私有 `interface`。

### [轻微] 4. `isNetworkError(err: unknown)` 的判定策略过于粗略

`plan.md` 第 58 行写"粗略判定 `@ohos.net.http` 抛错"。ArkTS 中 `unknown` 类型的错误对象需要做类型守卫（如 `err instanceof Error`、`err.code` 数值范围判定）。占位实现阶段可简化，但要避免在 `utils.ets` 中引入任何运行时阻塞（如不可达的 throw）。期望修正方向：Coder 阶段实现时使用 `err instanceof Error` + `err.code` 判定，并在 `isNetworkError` 不可识别时返回 `false`（避免误判）。

## 通过理由

1. **聚焦性**：R1 任务严格围绕"最小可编译骨架"展开——common 层 6 个文件 + services 2 个文件 + EntryAbility 改造，11 个产出文件构成一个明确的、纵向切片的可独立验证功能增量。无功能蔓延。

2. **可编译性保证**：
   - `api.ets` 完整实现（不仅是占位签名），包含 `@ohos.net.http` 生命周期管理与 `@ohos.request` 上传；
   - `HttpClient.ets` 完整实现，包含 JSON 解析、错误码映射、指数退避重试；
   - `PollingManager.ets` 仅占位但签名精确匹配 `EntryAbility` 调用点，保证 `onForeground/onBackground` 编译通过；
   - `common/` 无内部依赖（设计文档第 79 行要求），首轮无循环依赖风险。

3. **依赖方向符合 OOD 设计文档**：
   - `common/` 无内部依赖 ✓
   - `services/` 依赖 `common/`（HttpClient → api.ets + models.ets + constants.ets + utils.ets + RetryPolicy.ets + CacheManager.ets）✓
   - `entryability/` 依赖 `services/PollingManager` ✓
   - 首轮不新增 pages/components，不违反"pages → services → common"依赖方向 ✓

4. **关键细节无遗漏**：
   - `@ohos.net.http` 的 `destroy()` 在 `try/finally` 中调用（设计文档第 120 行要求）；
   - `TextResult.rawBody: string` 而非 `Object`，规避 ArkTS 强类型与 JSON 互转的兼容性问题（设计文档第 425 行要求）；
   - `UploadContext` 暂用 `object` 占位，规避对 UI 上下文类型的提前耦合；
   - `RetryPolicyConfig` 类型与 `RetryPolicy.ets` 文件同名分离（类型在 models，常量在 RetryPolicy.ets），避免 ArkTS 模块解析歧义；
   - `HttpClient` POST 不重试（设计文档第 142 行要求——非幂等 POST 命令下发不做重试）；
   - `PollingCallback = () => Promise<void>` 类型签名与设计文档第 234、423 行完全一致；
   - `ConnectivityStatus = 'loading' | 'online' | 'offline'` 与设计文档第 278、394 行完全一致；
   - `main_pages.json` 保持现状（不加未实现页面，避免编译失败）。

5. **选择理由充分**：自底向上、基础设施优先；PollingManager 占位避免调度逻辑与回调签名紧耦合；Index.ets 不改造避免 SensorService/DeviceService 联动问题；不加路由条目避免模块找不到组件。

6. **与已有模板状态匹配**：实际 EntryAbility.ets / Index.ets / main_pages.json / oh-package.json5 内容与 plan_task.md"当前模板状态"描述一致，可直接落地。

7. **不在范围内的内容明确列出**：R1 未涉及 6 个 Service 实现、12 个 UI 组件、4 个子页面、PollingManager 实际调度逻辑、Index.ets 改造、单元测试用例——避免任务范围蔓延。