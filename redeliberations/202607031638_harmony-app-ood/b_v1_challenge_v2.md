# 可落地性审查报告质询 — 质询 v2

## 审查概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `b_v1_diag_v2.md` — OOD 设计方案可落地性审查报告（修订版） |
| 待审查设计 | `a_v1_design_v3.md` — 鸿蒙移动应用 OOD 设计方案（v3） |
| 审查视角 | OOD 设计的可落地性 |
| 质询角色 | 质量审查报告的质询专家 |

---

## 质询列表

### CH1. 场景 E 的轮询停止契约与 ArkUI `router.pushUrl` 行为矛盾（遗漏）

**位置**：`b_v1_diag_v2.md` H5（第 111–137 行）、`a_v1_design_v3.md` 场景 E（第 362–369 行）

**问题描述**：
诊断报告 H5 指出了 `aboutToAppear` 的同步约束问题，但**遗漏了 `aboutToDisappear` 在路由场景下的调用时机矛盾**。

设计文档场景 E 的契约流水图：

```
页面 A → router.pushUrl('pages/B')
  ├─ 页面 A.aboutToDisappear() → PollingManager.stop('A相关key')
  └─ 页面 B.aboutToAppear() → PollingManager.start('B相关key')
```

但在 ArkUI（API 21）中：
- `router.pushUrl()` → 目标页面入栈，原页面**隐藏但未销毁**，**不会触发** `aboutToDisappear`
- `router.replaceUrl()` → 当前页面被替换销毁，**会触发** `aboutToDisappear`
- `router.back()` → 当前页面弹出销毁，**会触发** `aboutToDisappear`，前页面恢复

因此场景 E 的契约在 `pushUrl` 场景下**不可执行**——页面 A 的轮询无法通过 `aboutToDisappear` 停止，而页面 B 又通过 `aboutToAppear` 启动了对应 key 的轮询。轮询调度约束表（§并发设计）中各页面的轮询 key 不同，`PollingManager` 不会自动抑制页面 A 的轮询。结果是：页面 A 处于 `pushUrl` 隐藏状态时，其轮询仍在后台运行。

**判定**：**CHALLENGED** — 遗漏了关键的可落地性矛盾

**影响**：
- 隐藏页面的轮询持续运行，浪费网络和计算资源
- 隐藏页面的轮询回调写入已隐藏页面的 `@State`，虽不阻塞但冗余
- 违背了设计文档"页面切换不影响非活跃页面的轮询"（第 369 行）——实际是"不应影响但未被停止"

---

### CH2. H3 改进建议引入 `http.MultiFormData` 违反三层架构依赖方向（逻辑矛盾）

**位置**：`b_v1_diag_v2.md` H3（第 73–87 行）

**问题描述**：
诊断报告 H3 建议将 `HttpClient.post<T>()` 的 `body` 参数类型改为 `string | Object | http.MultiFormData`。但设计文档明确的三层依赖方向为：

```
pages/ → services/ → common/
```

且 `api.ets` 的职责定义（§1，第 103–114 行）为"`@ohos.net.http` 的轻量适配器"，`api.ets` 是唯一应该导入 `@ohos.net.http` 模块的层。`HttpClient` 位于 `services/` 层，方法签名中直接出现 `http.MultiFormData` 类型意味着：

1. `services/HttpClient.ets` 需要 `import http from '@ohos.net.http'`
2. 服务层直接依赖底层传输模块，违反"服务层不直接操作 `http` 模块"的架构原则
3. 若未来替换网络库，`HttpClient` 签名中的 `http.MultiFormData` 类型也需要修改，与"仅修改 `api.ets`"的决策矛盾

**设计文档 §1 和职责分工表明确说**：
- `api.ets`：封装 `@ohos.net.http` 的生命周期管理，**仅供 `HttpClient` 调用**
- `HttpClient`：**在 `api.ets` 返回的原始响应上叠加业务语义**

即 `HttpClient` 调用 `api.ets` 时传入参数应使用 `api.ets` 定义的抽象类型，而非直接使用 `@ohos.net.http` 的原生类型。

**判定**：**CHALLENGED** — 建议方案与设计文档自身架构原则矛盾

**正确方向**：
- 应在 `common/api.ets` 层暴露 FormData 构建的抽象函数或包装类型（而非将 `http.MultiFormData` 泄露到服务层）
- 或 `HttpClient` 的 `post` 方法接受 `contentType` 和 `rawBody: string | Object | ArrayBuffer`，由 `api.ets` 内部完成 `MultiFormData` 的构建与传输

---

### CH3. 乐观 UI 更新的失败回滚路径未覆盖设备状态漂移场景（遗漏）

**位置**：`b_v1_diag_v2.md` M3（第 199–215 行）、`a_v1_design_v3.md` 决策 7（第 483–490 行）、场景 B（第 320–334 行）

**问题描述**：
设计文档决策 7 采用乐观 UI 更新——点击后立即切换 UI 为目标状态，失败时回滚。诊断报告 M3 讨论了 `DeviceService` 的缓存层缺失，但**未将缓存过期与乐观 UI 回滚路径联动分析**。

具体遗漏场景：
1. `ControlPage` 加载时 `DeviceService.getCachedDevices()` 返回 `online=true`
2. 用户看到设备在线，点击 ControlButton（LED ON）
3. 乐观 UI 立即将按钮切换为"开启中"或"已开启"状态
4. 请求发出前设备物理掉线，服务器返回 `code=1003`（设备离线）
5. 乐观 UI 需要回滚至"已关闭"状态

设计文档和诊断报告均未定义：
- 回滚时 `@State` 的具体恢复机制（操作前状态如何保存？）
- 回滚后是否需要更新 `DeviceService` 缓存（将设备标记为离线，避免后续操作重复失败）
- 回滚后的 toast 提示策略（"操作失败"与"设备离线"应明确区分）

**判定**：**CHALLENGED** — 遗漏了乐观 UI 与设备状态漂移的交互场景

**补充建议**：
- 在 `ControlPage` 的核心抽象中补充：每个 `ControlButton` 操作前保存操作前状态到 `@State private previousState: boolean`，失败时恢复此状态
- 在场景 B 中补充回滚路径：`code=1003` 或网络异常 → 恢复 `ControlButton` 状态为 `previousState` → 调用 `DeviceService.refreshDevices()` 更新缓存 → toast 提示具体原因
- 在 `CommandService.send()` 的失败路径中补充缓存失效信号

---

### CH4. `ChartView` Canvas 实现复杂度未评估，存在实现风险（证据不充分）

**位置**：`b_v1_diag_v2.md` H2（第 50–68 行）

**问题描述**：
诊断报告 H2 确认了 ArkUI 无内置 Chart 组件，并建议使用 Canvas 路线，将"纯 Canvas 绘制逻辑封装为 `common/chart-renderer.ets`"。但诊断报告**未评估此路线的实际开发复杂度**：

1. ArkUI API 21 的 `CanvasRenderingContext2D` 是 `@ohos.arkui.canvas` 下的原生 API，其绘制接口与 Web Canvas 相似但并非完全一致，坐标轴刻度、网格线、标签等均需从零实现
2. 折线图所需的触摸交互（`onTouch` 事件 → 最近数据点检索 → 详情弹窗）涉及坐标映射计算和数据点索引，非 trivial 实现
3. 参考项目 `reference/zhihui` 中**无 Canvas 图表实现先例**，缺乏可复用的参考代码
4. 多图表演示场景（如同时展示温湿度两条曲线）的复合渲染未讨论
5. 设计文档和诊断报告均未提及 Canvas 与 ArkUI 渲染管线的交互细节（如离屏渲染、帧率控制、重绘触发机制）

**判定**：**CHALLENGED** — 改进建议未充分评估实现复杂度，建议的具体化程度不足以支撑"可落地"判定

**补充建议**：
- 在 `a_v1_design_v3.md` 的 H2 改进建议中增加复杂度评估：预估开发工作量、Canvas 绘制核心 API 列表、示例伪代码
- 给出分阶段实现建议：v1.0 先实现基础折线图（单数据线 + 简易坐标轴），图表类型切换、触摸交互、双轴图表作为后续迭代
- 或考虑在 `common/chart-renderer.ets` 中定义 `interface ChartRendererAPI` 抽象，为未来切换至成熟三方图表库预留接口

---

### CH5. `PollingManager` 接口未考虑 WebSocket 升级路径的兼容性（遗漏）

**位置**：`b_v1_diag_v2.md` 全文、`a_v1_design_v3.md` §9 `PollingManager`（第 201–212 行）、需求 §2.2

**问题描述**：
需求明确要求"v1.0 采用 HTTP 轮询 10s 间隔，后续可升级为 WebSocket"（§2.2）。诊断报告**全文未评估 `PollingManager` 的接口设计与未来 WebSocket 升级的兼容性**。

`PollingManager` 当前接口：
```
start(key: string, fn: PollingCallback, interval: number)
stop(key: string)
stopAll()
```

其中 `interval` 参数与轮询模式（拉模式）强绑定。WebSocket 升级后：
- 数据驱动方式从 `setInterval` 定时拉取变为服务端推送
- 不再需要 `interval` 参数
- 需要 `onMessage(key, data)` 或 `subscribe(key, handler)` 的回调模式
- `PollingManager` 的接口抽象可能需要重构，影响所有调用者（`IndexPage`, `DashboardPage`, `AdvisoryPage`）

**判定**：**CHALLENGED** — 遗漏了接口的可扩展性约束对架构设计的影响

**补充建议**：
- 在 `PollingManager` 的核心抽象中定义 `DataSource` 抽象：`type DataSource = 'polling' | 'push'`，`start()` 接口按 `DataSource` 类型分派不同调度策略
- 或采用 `startPolling(key, fn, interval)` / `subscribePush(key, handler)` 分离式接口设计，为后续升级预留扩展点
- 在设计决策中补充"轮询调度器接口可扩展性"决策记录，说明 v1.0 仅实现轮询模式，但接口预留了推模式扩展点

---

## 质询总结

| 编号 | 类型 | 严重程度 | 对象章节 | 核心问题 |
|------|------|---------|---------|---------|
| CH1 | 遗漏 | 高 | 场景 E + H5 | `pushUrl` 不触发 `aboutToDisappear`，场景 E 的轮询停止契约不可执行 |
| CH2 | 逻辑矛盾 | 高 | H3 建议 | `http.MultiFormData` 泄露到 `services/` 层，违反三层依赖方向 |
| CH3 | 遗漏 | 中 | 决策 7 + 场景 B | 设备状态漂移场景下乐观 UI 回滚路径未定义 |
| CH4 | 证据不充分 | 中 | H2 | Canvas 图表实现复杂度未评估，开发者可能低估工作量 |
| CH5 | 遗漏 | 中 | §9 PollingManager | 未考虑 WebSocket 升级路径对 `start(interval)` 接口的影响 |

**总体判定**：**CHALLENGED** — 存在 1 项关键可落地性矛盾（CH1，场景 E 契约不可执行）、1 项改进建议自相矛盾（CH2）、3 项遗漏/评估不足

```
CHALLENGED:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\b_v1_challenge_v2.md
```
