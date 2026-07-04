# 设计审查报告（R1 r2）

## 审查结果

APPROVED

## 发现

### R1 修订验证

R1 共提出 3 个 [一般] + 4 个 [轻微] 问题。R2 修订对全部 7 个问题均有针对性修复：

| R1 编号 | 严重度 | R2 修复位置 | 验证 |
|---------|--------|------------|------|
| 一般-1 | HttpClient 缺 `isNetworkError`/`sleep` 导入 | §7 L912 `import { isNetworkError, sleep } from '../common/utils';` | 已修复 |
| 一般-2 | `api.ets` 中 `request` 导入与导出同名冲突 | §6 L820 改为 `import { request as ohRequest } from '@kit.RequestKit';`；L882-888 伪代码中 `ohRequest.agent.create()` / `ohRequest.uploadFile()` 同步更新 | 已修复 |
| 一般-3 | `models.ets` 缺 `CommandResponse` 接口 | §"类型定义" L216-225 新增 `CommandResponse`（`command_id`/`device_id`/`command`/`status` 四字段，与 `docs/3_client-api-reference.md` §2.5.1 响应示例完全一致）；§1 业务实体清单 L591 同步加入 | 已修复 |
| 轻微-1 | `withRetry` 伪代码 `lastError` 不可达 | §7 L977-1007 重构：删除 `let lastError` 变量与末行 `throw lastError ?? ...`；改为控制流清晰的"成功/重试/抛错"三分支 | 已修复 |
| 轻微-2 | `api.ets` 中 `BusinessError` 导入未使用 | §6 L848 明确 `try-catch (err: BusinessError)` 类型守卫；L899-900 新增 "BusinessError 使用说明" 段落解释语义 | 已修复 |
| 轻微-3 | `PollingManager.start` 形参未使用 | §8 L1046 形参改用下划线前缀 `start(_key: string, _fn: PollingCallback, _interval: number): void` | 已修复 |
| 轻微-4 | `DEFAULT_RETRY.timeoutMs` 字段无运行时消费者 | §3 L747-750 新增 "timeoutMs 字段语义说明" 段落明确：保留是为后续动态超时策略预留接口，避免破坏 `RetryPolicyConfig` 依赖契约；§实施风险与边界声明 L1165 同步列出该风险 | 已修复 |

### R2 独立审查（新增审视）

除修复 R1 问题外，对 R2 设计做独立审查无新发现严重或一般缺陷：

- **类型契约正确性**：`SensorSnapshot`（含 `mac_addr` / `ip_addr` / `created_at`）与 `SensorHistory`（不含 `mac_addr` / `created_at`）的字段集均与 `docs/3_client-api-reference.md` §2.2.1、§2.2.2 响应示例精确匹配。
- **`CommandResponse` 字段一致性**：四字段 `command_id`/`device_id`/`command`/`status` 完整对应 API 文档 §2.5.1 响应 `data` 结构。
- **`api.ets` 导入重命名一致性**：`ohRequest` 重命名在导入语句与 `uploadFile` 伪代码中均已正确引用，无遗漏。
- **模块依赖图无环**：`EntryAbility` → `PollingManager` 单向；`HttpClient` → `common/*` 单向；`PollingManager` 仅依赖 `models.ets` 中的 `PollingCallback` 类型。无循环依赖。
- **PollingManager 占位边界明确**：L1061-1067 "占位边界声明" 显式列出本轮不实现的字段（`currentTimer` / `executeTick()`）与不创建定时器的约束，与后续轮次的演进路径清晰衔接。
- **`withRetry` 控制流完备性**：R2 重构后的 `for` 循环体内每条路径（成功 return、状态码重试、网络异常重试、末次抛错）均有明确出口，末行 `throw new Error('Retry exhausted')` 作为 ArkTS 严格类型"所有路径终结"的占位，注释说明运行时不可达——可接受。
- **R2 残余小瑕疵（不影响通过）**：
  - §7 `get` 方法"实现逻辑（伪代码）"步骤 4-5（L936-946）仍以内联方式描述重试循环，未提及调用 `withRetry` 辅助函数；与下方 L977-1007 的 `withRetry` 伪代码存在表述层级不一致。属文档叙述风格小问题，编码期以 `withRetry` 为准即可，不影响设计正确性。
