# 可落地性审查报告质询 — b_v1_diag_v5.md

## 质询概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `b_v1_diag_v5.md` — OOD 设计方案可落地性审查报告（v5，响应质询版） |
| 审查视角 | 对审查报告自身的问题定位、证据支撑、逻辑自洽和覆盖完备性进行二次质询 |
| 质询结论 | **CHALLENGED** — 审查报告存在逻辑缺失和覆盖遗漏 |

---

## CH1 — 逻辑完整性：H10 RetryPolicy 与 PollingManager 轮询调度交互未定义

**位置**：`b_v1_diag_v5.md` H10（第 255–266 行）、轮询调度约束表（第 408–412 行）

**问题**：

H10 新增了带指数退避的 `RetryPolicy`：
```
baseDelayMs: 1000, maxDelayMs: 10000, maxRetries: 3
```

但未评估其与 `PollingManager` 10s 轮询周期的交互效应。

在 `setInterval(async () => {...}, 10000)` 模式下，单个轮询 tick 的实际总耗时可能超过 10s：
- 初始请求：~2s（含网络往返 + JSON 解析）
- 重试 1（1s delay + ~2s）：第 5s 完成，仍失败
- 重试 2（2s delay + ~2s）：第 9s 完成，仍失败
- 重试 3（4s delay + ~2s）：第 15s 完成

由于 `setInterval` **不等待回调完成**，第 10s 时下一个 tick 仍会触发回调，导致：

1. **并发请求**：前一轮询的重试（第 4 次，正在请求）与下一个 tick 的请求同时执行
2. **UI 状态竞争**：两个请求的响应到达时序不确定，`@State` 被交替更新 → UI 闪烁
3. **带宽浪费**：弱网场景下并发请求加重网络拥塞，与 H10 的弱网韧性目标背道而驰
4. **CacheManager 缓存竞争**：若前一个重试写入缓存后，后一个 tick 覆盖写回更旧的数据

**判定**：审查报告新增了 RetryPolicy 和 PollingManager 两个相互影响的机制，但未分析二者交互的副作用。改进建议在轮询场景下可能导致并发问题和反向效果，属于建议本身的可落地性缺口。

**改进建议**：
- 在 `PollingManager` 的核心抽象中定义轮询 tick 并发策略，至少选择以下之一：
  - **串行模式**：使用递归 `setTimeout` 而非 `setInterval`，上一个 tick 完全结束后再调度下一个 10s
  - **跳略模式**：`setInterval` + 运行标志位，若前一个 tick 未完成则跳过当前 tick
- 在 `RetryPolicy` 中补充轮询适配选项：设置**每个 tick 的整体超时截断**（如 `tickTimeoutMs: 8000`，确保重试在下一个 tick 前完成或放弃）
- 补充说明轮询回调中发起重试后，如何处理剩余 `setInterval` 周期内的 cache 和 UI 一致性

---

## CH2 — 覆盖完备性：现有 `common/api.ets` 与两层架构的兼容性未评估

**位置**：`b_v1_diag_v5.md` 全文

**问题**：

需求 §5 明确列出 `common/api.ets` 为**已有文件**（"已有文件，需在此基础上设计实现"），且 `common/models.ets` 同样已存在。v3 设计提出了"原始传输层（`api.ets`）→ 业务门面层（`HttpClient.ets`）"的两层 HTTP 封装结构，将现有 `api.ets` 重新定义为 `@ohos.net.http` 的轻量适配器。

审查报告详细审查了 `HttpClient` 的设计缺陷（H3 multipart 实现路径、H4 二进制响应缺失）和 `PollingManager` 的不足，但**从未评估"现有 `api.ets` 的实际实现是否支持被降级为纯传输层"**这一核心前提：

1. **职责重叠风险**：现有 `api.ets` 的功能描述为"HTTP 请求封装"，可能已包含认证头注入、JSON 解析或基础路径拼接等逻辑。如果确实如此，则这些职责与新建的 `HttpClient` 重叠，要么重构现有代码，要么修改设计分配
2. **依赖方向合规性**：设计依赖方向为 `services/` → `common/`。如果现有 `api.ets` 以具名导出函数提供 HTTP 能力，`HttpClient` 可直接导入使用；但如果现有 `api.ets` 以类或实例对象暴露，则需要确认导入方式是否与 ArkTS 模块系统兼容
3. **迁移成本未评估**：即使现有 `api.ets` 需要大规模重构以适应新角色，该成本也未在设计或审查中体现。"已有文件"的既有结构对设计方案形成约束，但审查未将此约束纳入评估

**判定**：审查报告未评估设计方案对"已有文件"的重构影响。设计方案的可行性部分依赖于对现有 `api.ets` 的假设，这些假设在审查中未被验证或标记为风险。

**改进建议**：
- 审查现有 `common/api.ets` 的实现内容，逐项对比设计分配给 `api.ets` 和 `HttpClient.ets` 的职责边界
- 评估现有代码是否需要重构以及重构范围（完全重写 vs 包覆 vs 增量添加）
- 在审查报告中补充"现有文件兼容性"评估小节，明确设计方案不依赖对现有文件角色的错误假设

---

## CH3 — 逻辑完整性：H5 中 aboutToAppear 初始加载的错误处理未定义

**位置**：`b_v1_diag_v5.md` H5（第 140–148 行）

**问题**：

H5 建议每个页面在 `aboutToAppear()` 中"通过非 async 方式触发 `loadData()` 异步方法"，并增加 `@State private isLoading` 控制骨架屏。但该建议**未定义 `loadData()` 初始调用时的错误处理路径**。

在 ArkTS 中，从同步函数调用 async 函数的典型模式为：
```typescript
aboutToAppear() {
  this.loadData()  // fire-and-forget
}
```

存在两类未处理的异常场景：

1. **同步异常**（第 0 次 await 之前抛出）：如果 `loadData()` 在第一次 `await` 之前抛出异常（如参数校验失败、访问未初始化属性），异常将直接传播到 `aboutToAppear` 调用方（ArkUI 框架层），导致页面加载失败或白屏。因为没有 `try-catch` 包裹
2. **异步异常未处理**：`loadData()` 返回的 Promise 未被 `.catch()` 捕获。如果 `loadData()` 内部未自行 try-catch，Promise rejection 将导致 `unhandled promise rejection`，ArkTS 运行时行为取决于运行时实现

H5 改进建议应该明确初始加载的错误处理契约：

```typescript
aboutToAppear() {
  this.isLoading = true
  this.loadData()
    .catch((err: Error) => {
      this.isLoading = false
      this.errorMessage = '数据加载失败'
      promptAction.showToast({ message: '加载失败，请下拉刷新', duration: 2000 })
    })
}
```

**判定**：H5 的改进建议不完整——定义了加载态 UI，但未定义加载失败路径，存在页面白屏风险。

**改进建议**：
- 为每个页面补充 `@State private errorMessage: string | null` 和可选的"重新加载"触发器
- 在 H5 的行为契约中补充"初始化失败→显示错误状态→用户触发重新加载"的完整链路
- `loadData()` 方法统一返回 `Promise<void>`，由调用方统一处理异常

---

## 质询汇总

| 编号 | 维度 | 质询要点 | 原报告判定 |
|------|------|---------|-----------|
| CH1 | 逻辑完整性 | H10 RetryPolicy 与 PollingManager 10s 轮询间隔的交互未定义，setInterval 与指数退避存在竞争 | 建议缺陷 |
| CH2 | 覆盖完备性 | 现有 `common/api.ets` 与两层架构的兼容性未评估，设计依赖于未经验证的前提假设 | 覆盖遗漏 |
| CH3 | 逻辑完整性 | H5 `aboutToAppear` 初始加载的错误处理未定义，异步 Promise 的同步异常和 rejection 均未覆盖 | 建议不完整 |

---

```
CHALLENGED:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\b_v1_challenge_v5.md
```
