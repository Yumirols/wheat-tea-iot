# 农眼卫士 FarmEye Guard v1.0 — OOD 设计方案可落地性审查报告（v5，响应质询版）

## 审查概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `a_v1_design_v3.md` — 鸿蒙移动应用 OOD 设计方案（v3） |
| 对应需求 | `requirement.md` — 鸿蒙移动应用 OOD 设计需求 |
| 审查视角 | OOD 设计的可落地性（ArkTS/ArkUI 框架可行性、组件划分、职责边界、协作关系、API 覆盖） |
| 审查方法 | 基于 v4 审查报告及质询文件逐项复核，按质询意见修订建议 |
| 本版变更 | 响应质询 CH1–CH5：CH1 接受→新增 H9；CH2 接受→修正 H2 估算为任务分解；CH3 接受→H1/H4 增加耦合关系标注；CH4 接受→新增 H10/M5；CH5 接受→修正严重度统计 |

---

## 整体评价

设计方案的三层架构（服务层 + 页面层 + 公共层）划分合理，API 覆盖完整，`PollingManager` 集中管理轮询等决策符合 ArkUI 框架约束。

但 v3 设计版本存在多处可落地性缺口：框架能力缺口（Canvas 图表、multi-part 传输）、架构矛盾（`aboutToAppear` 同步约束、`pushUrl` 生命周期）、架构遗漏（设备切换级联刷新、弱网韧性缺失）、以及首页传感器轮询缺失的核心体验缺口。

**v5 审查：9 项高严重度问题、4 项中严重度问题、3 项低严重度问题**（依据质询 CH1–CH5 修订），详情如下。

---

## 高严重度问题

### H1. `ImageViewer` 图片展示路径：需补充 `image_path` 语义分析（修订，与 H4 耦合）

**位置**：`a_v1_design_v3.md` §15 `ImageViewer`（第 273–280 行）

**问题描述**：
设计存在两条潜在的图片展示路径，但未明确选择：

**路径 A — URL 直接加载**：若 `DiseaseRecord.image_path` 为完整 URL（或可通过 `baseURL + image_path` 拼接），则 `ImageViewer` 直接使用 `<Image src={image_path}>`，ArkUI 天然支持，零额外复杂度。此路径无需 `ImageService.getImage()`，无需 `ArrayBuffer`，无需 `PixelMap` 解码。

**路径 B — 二进制 + PixelMap 解码**：若 `image_path` 为 image_id，需 `ImageService.getImage(imageId)` → `HttpClient.getRaw()` → `ArrayBuffer` → `ImageSource` → `PixelMap` → `<Image src={pixelMap}>`。

从 API 设计惯例判断，`image_path` 字段更可能存储 URL（便于前端直接消费），但设计文档未确认此语义。

**严重程度**：高 — 当前设计未明确 `image_path` 语义，两条路径均不可确定实施

**改进建议**：
- **首要行动**：需求/API 文档中明确 `DiseaseRecord.image_path` 字段的语义（URL vs image_id）
  - 若为 URL → `ImageViewer` 采用 `<Image src={image_path}>`，无额外架构需求
  - 若为 image_id → 采用 `ImageService.getImagePixelMap(imageId)` 完成 `ArrayBuffer` → `PixelMap` 解码链
- **与 H4 耦合关系**：若路径 A 确认（URL 加载），H4 的 `requestRaw()` 仅用于图片上传场景的 multipart 构建，紧急度降低至中；若路径 B 确认（image_id），H4 保持高严重度。两大问题待 `image_path` 语义确认后重新评估严重度。

---

### H2. `ChartView` 在 ArkUI 中缺少原生图表组件，Canvas 实现复杂度未评估（修订，估算修正为任务分解）

**位置**：`a_v1_design_v3.md` §12 `ChartView`（第 237–245 行）

**问题描述**：
ArkUI API 21 无内置 `<Chart>` 组件，`Canvas` 路线需从零实现坐标轴、刻度、数据点映射、触摸交互。v3 设计仍停留在"在 Canvas 或 Chart 组件上绘制"的模糊描述层面。

**复杂度任务分解**（各子任务独立可估，开发者按实际数据量级标定）：

| 子任务 | 技术依赖 | 预估工时（人时） |
|--------|---------|----------------|
| 坐标轴系统（X/Y 刻度线、标签文本、网格线） | `CanvasRenderingContext2D.strokeLine` / `fillText` / `measureText` | 8–16h |
| 数据点→像素坐标映射（值域缩放、离群值裁切） | 线性映射函数 | 4–8h |
| 折线图绘制（单线） | `CanvasRenderingContext2D.path` / `stroke` | 4–8h |
| 柱状图绘制 | `CanvasRenderingContext2D.fillRect` | 4–8h |
| 触摸交互（像素反算→数据索引→详情弹窗） | `onTouch` 事件处理 | 8–16h |
| 温湿度双 Y 轴复合图表 | 双层刻度系统 + 分层绘制 | 8–16h |
| **v1.0 最小可用合计**（单 Y 轴折线，无触摸交互） | — | **16–32h（2–4 人日）** |
| **完整功能合计** | — | **36–80h（5–10 人日）** |

**严重程度**：高 — 存在框架能力缺口，v1.0 最小可用版本预估 2–4 人日

**改进建议**（分阶段）：
- **v1.0 最小可用**：仅实现单 Y 轴折线图，数据线 1 条，坐标轴不包含刻度标签可读性优化；触摸交互放到下一版
- **架构预留**：在 `common/` 下定义 `interface ChartRendererAPI`：
  ```typescript
  interface ChartRendererAPI { render(ctx: CanvasRenderingContext2D, data: number[], width: number, height: number): void; onTouch(x: number, y: number): DataPoint | null; }
  ```
- 折线图和柱状图分别实现此接口，`ChartView` 组件通过 `@Prop chartType: 'line' | 'bar'` 切换渲染器实例

---

### H3. `ImageService` 的 `multipart/form-data` 上传路径缺少 ArkTS 实现指引（未修复，建议方案修订）

**位置**：`a_v1_design_v3.md` §8 `ImageService`（第 189 行）、§2 `HttpClient` 第 125 行

**问题描述**：
设计指出"构建 FormData"并通过 `HttpClient.post()` 发送。`@ohos.net.http` 中通过 `http.MultiFormData` 类构建 multipart 请求体。但 `HttpClient` 位于 `services/` 层——按照三层依赖方向（`services/` → `common/`），**`HttpClient` 不应直接导入 `@ohos.net.http`**。

**严重程度**：高 — 实现需补充技术细节

**改进建议**（修订版）：
- 在 `common/api.ets` 中新增 `buildFormData(fields: Record<string, string | { uri: string; name: string }>)` 辅助函数，内部调用 `http.createMultipartFormData().addPart()`，返回 `http.MultiFormData` 实例
- `api.ets` 新增 `requestMultipart(url, formData, options)` 方法，内部设置 `extraData: formData` 和 `Content-Type: multipart/form-data`
- `HttpClient.post<T>()` 新增 `multipart?: Record<string, string | { uri: string; name: string }>` 可选参数；当 `multipart` 存在时，调用 `api.ets` 的 `requestMultipart()` 路径，而非 JSON 序列化路径
- `ImageService.upload(fileUri: string, params?: Record<string, string>)` 内部组装 `fields` 结构，调用 `HttpClient.post()` 的 multipart 模式

---

### H4. `api.ets` 的 `NetworkResult.rawBody: string` 无法承载二进制响应（部分修复，与 H1 耦合）

**位置**：`a_v1_design_v3.md` 核心接口表 `NetworkResult`（第 301 行）、§2 `HttpClient` 第 124 行

**问题描述**：
v3 设计虽在 `HttpClient` 新增了 `getRaw()` 方法描述（返回 `ArrayBuffer`），但**未描述 `api.ets` 层如何支持**。`@ohos.net.http` 通过 `expectDataType` 控制响应体格式：`STRING` → `string`，`ARRAY_BUFFER` → `ArrayBuffer`。当前 `api.ets` 只有一条返回路径（`string`），无法同时支持 JSON 文本响应和二进制图片响应。且 `NetworkResult.rawBody: string` 的类型定义仍然只覆盖文本场景。

**严重程度**：高 — 架构遗漏（与 H1 耦合，详见 H1 耦合关系说明）

**改进建议**：
- 在 `api.ets` 中新增 `requestRaw(url, options)` 方法，内部设置 `expectDataType: http.HttpDataType.ARRAY_BUFFER`，返回 `{ statusCode: number; headers: Object; rawBody: ArrayBuffer }`
- 将 `NetworkResult` 拆分为两个类型：`TextResult { rawBody: string }` 和 `BinaryResult { rawBody: ArrayBuffer }`，或使用联合类型 `string | ArrayBuffer`
- **严重度重新评估**：待 H1 的 `image_path` 语义确认后：
  - 若为 URL 加载（路径 A），本问题严重度降为中（仅图片上传场景需 `requestRaw()`，实际为 H3 的子集）
  - 若为 image_id 加载（路径 B），本问题保持高严重度

---

### H5. 所有页面 `aboutToAppear` 中编排异步加载 + `pushUrl` 场景下轮询停止契约不可执行（未修复）

**位置**：`a_v1_design_v3.md` 场景 A/B/C/D/E（第 309–369 行）

**问题描述**：

**问题 1**：`aboutToAppear()` 在 ArkUI API 21 中为**同步函数**，不支持 `async`，设计文档全文未定义页面初始加载状态的 UI 表现（骨架屏 / 加载指示器 / 空状态占位）。

**问题 2**：设计文档场景 E 的契约：
```
页面 A → router.pushUrl('pages/B')
  ├─ 页面 A.aboutToDisappear() → PollingManager.stop('A相关key')
  └─ 页面 B.aboutToAppear() → PollingManager.start('B相关key')
```
但在 ArkUI API 21 中：
- `router.pushUrl()` → 目标页面入栈，原页面**隐藏但未销毁**，**不会触发** `aboutToDisappear`
- `router.replaceUrl()` → 当前页面被替换销毁，会触发 `aboutToDisappear`
- `router.back()` → 当前页面弹出销毁，会触发 `aboutToDisappear`

因此场景 E 的 `pushUrl` 分支下**轮询停止契约不可执行**，页面 A 隐藏时轮询仍在后台运行，浪费资源并写入已隐藏页面的 `@State`。

**严重程度**：高 — 每个页面首次加载的空状态 + 隐藏页面的轮询泄漏

**改进建议**：
- 每个页面增加 `@State private isLoading: boolean = true`
- `aboutToAppear()` 中通过非 async 方式触发 `loadData()` 异步方法，`build()` 中根据 `isLoading` 条件渲染加载指示器或数据内容
- **场景 E 修正为**：
  - `router.pushUrl()` → 页面 A **不停止轮询**（因为页面未销毁），页面 B 启动自己的轮询（key 不同），`PollingManager` 允许多 key 共存
  - `router.replaceUrl()` / `router.back()` → 页面销毁时触发 `aboutToDisappear`，停止对应轮询
  - 在 `EntryAbility.onBackground()` 中统一 `suspendAll()`，无论哪种路由方式，应用进入后台时暂停所有轮询
- 行为契约流水图应区分"同步初始化阶段"和"异步数据加载阶段"

---

### H6. `DeviceSelector` 设备切换的级联数据刷新路径未定义（未修复）

**位置**：`a_v1_design_v3.md` 模块目录 `components/DeviceSelector.ets`（第 37 行）、设计决策 5（第 466–473 行）

**问题描述**：
设计引入了 `DeviceSelector` 组件用于多设备场景，但未定义：
- 设备切换时哪些页面需要级联刷新数据
- 级联刷新的触发机制（`DeviceSelector` 如何通知页面重新调用多个 Service）
- 切换设备时 `PollingManager` 中正在运行的轮询如何处理
- 跨页面共享的设备 ID 变更后，页面 B 如何感知

**严重程度**：高 — 多设备场景的核心交互路径缺失

**改进建议**：
- `DeviceSelector` 补充 `@Link selectedDeviceId: string` 双向绑定和 `onDeviceChange?: (newDeviceId: string) => void` 回调契约
- 新增"设备切换"行为场景：`onDeviceChange` → 重新调用依赖 `device_id` 的 Service → `PollingManager` 用新 `device_id` 重启轮询 → 更新 `@State`
- 跨页面共享：设备 ID 变更后通过 `router.replaceUrl({ params: { deviceId: newId } })` 携带新 ID，各页面在 `aboutToAppear` 中从 `router.getParams()` 获取最新 device_id

---

### H7. `PollingManager` 接口扩展性展望（降级为中）

**状态**：中 — 非 v1.0 阻塞，属未来扩展性关注点（v4 已降级，维持不变）

---

### H8. 乐观 UI 回滚未覆盖设备状态漂移场景（未修复）

**位置**：`a_v1_design_v3.md` 决策 7（第 483–490 行）、场景 B（第 320–334 行）

**问题描述**：
决策 7 采用乐观 UI 更新——点击后立即切换 UI 为目标状态，失败时回滚。但未定义设备状态漂移场景的处理：
1. `ControlPage` 加载时 `DeviceService` 缓存返回 `online=true`
2. 用户点击 ControlButton（LED ON）
3. 乐观 UI 立即将按钮切换为"已开启"
4. 请求发出前设备物理掉线，服务器返回 `code=1003`（设备离线）
5. 乐观 UI 需要回滚至"已关闭"状态

缺失的关键契约：
- 操作前状态如何保存（`@State private previousState: boolean`）
- 回滚后是否更新 `DeviceService` 缓存（将设备标记为离线，避免后续操作重复失败）
- 回滚后的 toast 提示区分"操作失败"与"设备离线"

**严重程度**：高 — 核心交互路径在设备状态漂移时出错

**改进建议**：
- 在 `ControlPage` 核心抽象中补充每个 `ControlButton` 操作前保存状态到 `@State private previousState: boolean`
- 在场景 B 中补充回滚路径：`code=1003` 或网络异常 → 恢复 `ControlButton` 状态为 `previousState` → 调用 `DeviceService.refreshDevices()` 更新缓存 → toast 提示具体原因
- 在 `CommandService.send()` 的失败路径中补充缓存失效信号

---

### H9. IndexPage 首页缺少传感器数据实时刷新轮询（新增，依据质询 CH1）

**位置**：`a_v1_design_v3.md` 场景 A（第 312–317 行）

**问题描述**：
需求 §2.1 明确要求**"环境参数实时展示卡片：温湿度、光照、CO2、土壤 NPK、信号强度等传感器数据的实时数值显示"**。但设计文档场景 A 显示 IndexPage 的轮询调度为：
```
PollingManager.start('index_alarm', 10000)
   └─ 每 10s: AdvisoryService.getAdvisory() → 检测新告警
```
IndexPage 上的 `SensorCard` 群组仅在 `aboutToAppear` 时通过 `SensorService.getLatest(deviceId)` 获取一次静态快照，**没有设置传感器数据轮询**。这意味着用户停留在首页时，温湿度等环境参数是**静态快照而非实时数值**，与需求 §2.1 的"实时展示"矛盾。

DashboardPage 虽有 `dashboard_sensor` 轮询（10s 刷新传感器数据），但用户通常将首页（IndexPage）作为默认停留页面。如果首页传感器卡片不刷新，核心体验在默认场景下是"准实时"而非"实时"。

**严重程度**：高 — 核心体验缺口，直接背离需求

**改进建议**：
- 在 IndexPage 的 `aboutToAppear` 中注册传感器数据轮询：
  ```
  PollingManager.start('index_sensor', 10000)
     └─ 每 10s: SensorService.getLatest(deviceId) → 更新 SensorCard 群组的 @State
  ```
- 在轮询调度约束表中 IndexPage 行补充 `'index_sensor'` key，间隔 10s，与告警轮询共存
- 考虑是否可将 IndexPage 与 DashboardPage 的传感器轮询合并（同一 key，避免两个页面各自轮询浪费），但需评估用户双页面同时可见的场景

---

### H10. 农业 IoT 场景弱网韧性完全未覆盖（新增，依据质询 CH4）

**位置**：`a_v1_design_v3.md` 错误处理策略（第 373–393 行）

**问题描述**：
应用场景为农业物联网（摄像头、传感器部署在大田/大棚环境中），网络连接稳定性低于城市室内环境。但设计文档和审查报告均未覆盖弱网场景的三大缺口：

**1. 请求重试机制缺失**
设计文档的错误处理策略定义了各类错误的处理方式，但**缺失请求重试机制的定义**：
- 网络超时后是否自动重试？
- 重试次数和退避策略是什么（固定间隔 / 指数退避 / 立即重试）？
- 重试是否区分幂等和非幂等请求？

**2. 离线状态 UI 表现未定义**
- 数据卡顿/空值时是否展示"数据加载中"占位 vs "设备离线"提示？
- 页面标题处是否展示连接状态指示器？
- 当前设计仅在错误时通过 `promptAction.showToast()` 提示，但 toast 消失后 UI 仍展示空白/错误状态

**3. 本地缓存策略未定义**
- IndexPage 首页在无网络连接时是否至少展示最后一次成功获取的快照？还是空白的 SensorCard？
- 切换页面后返回，缓存是否保留？
- 本地缓存的时效性如何管理？

**严重程度**：高 — IoT 场景下弱网韧性是核心质量属性

**改进建议**：
- **在 `common/` 下新增 `RetryPolicy` 定义**：
  ```typescript
  interface RetryPolicy {
    maxRetries: number;        // 建议：3
    baseDelayMs: number;       // 建议：1000（指数退避起始）
    maxDelayMs: number;        // 建议：10000
    retryOn: number[];         // 建议：[408, 429, 502, 503, 504]
    timeoutMs: number;         // 建议：10000
  }
  ```
  在 `HttpClient` 层实现重试逻辑（`get<T>` / `post<T>` 内部对可重试状态码和网络异常进行指数退避重试，对非幂等 POST 命令请求不做重试）

- **在 `common/` 下新增 `CacheManager`**：
  ```typescript
  interface CacheEntry<T> { data: T; timestamp: number; ttl: number; }
  ```
  - `SensorService` 在成功获取数据后存入 `CacheEntry`
  - 网络失败时优先返回缓存数据 + 页面展示"数据可能非最新"提示
  - 缓存 TTL 默认 30s（与轮询间隔 10s 配合，避免展示超过 3 轮轮询周期的旧数据）

- **离线 UI 表现**：
  - 每个页面补充 `@State private connectivityStatus: 'loading' | 'online' | 'offline' = 'loading'`
  - `build()` 中根据 `connectivityStatus` 渲染连接状态指示器（页面顶部细条，绿色/黄色/红色）
  - `SensorCard` 补充"数据来源时间戳"展示，帮助用户判断数据新鲜度

---

## 中严重度问题

### M1. 轮询告警状态 → UI 渲染的传播路径未定义（未修复）

**位置**：`a_v1_design_v3.md` 场景 A（第 316–317 行）

**问题描述**：
场景 A 描述 `PollingManager` 回调中调用 `AdvisoryService.getAdvisory()` → "检测新告警" → "AlarmBanner 显示"。但告警结果从 `setInterval` 回调传递到 `@State` 变量的路径未定义。

`PollingManager` 是服务层模块级单例，其 `start()` 接收的回调函数存储在内部注册表中。存在隐患：
1. 回调中 `this` 指向依赖箭头函数捕获页面闭包，设计未约定回调必须使用箭头函数
2. `PollingManager.start()` 方法签名中未定义 `fn` 参数的类型签名
3. 页面被销毁后 `PollingManager` 未及时 `stop()`，回调继续执行时将写入已销毁页面的 `@State`

**严重程度**：中 — 实现者需自行推断

**改进建议**：
- 定义回调类型签名：`type PollingCallback = () => Promise<void>`，文档中明确标注回调必须为箭头函数
- `IndexPage` 核心抽象补充：`@State private alarmMessage: string | null` 和 `@State private alarmSeverity: 'mild' | 'moderate' | 'severe' | null`
- 在场景 A 的行为契约中补充"轮询回调 → 更新 `@State` → `build()` 重新渲染 → `AlarmBanner` 显示"的完整链路
- `PollingManager.stop(key)` 标注为 Must-Invoke：页面 `aboutToDisappear` 必须调用
- `PollingManager` 内部每个 tick 通过 try-catch 包裹回调执行

---

### M2. `SensorService` 核心抽象中遗漏 `getDaily()` 方法（未修复）

**位置**：`a_v1_design_v3.md` §3 `SensorService`（第 131–140 行）

**问题描述**：
核心接口表（第 293 行）声明了 `DailyAggregation` 模型类型，对应 `GET /sensor/daily` 接口，但 §3 未具体定义 `getDaily()` 的方法签名、参数和返回类型。

**严重程度**：中 — 不完整

**改进建议**：
- 在 §3 补充：`getDaily(deviceId: string, start: string, end: string, page?: number, pageSize?: number): Promise<PaginatedData<DailyAggregation>>`

---

### M3. `CommandService` 与 `DeviceService` 的在线状态依赖缺少缓存层定义（未修复）

**位置**：`a_v1_design_v3.md` §5 `CommandService`（第 158–160 行）

**问题描述**：
设计指出"在下发前通过 `DeviceService` 前置检查设备在线状态"，但"本地缓存的设备状态"未定义在哪里维护。设备状态可能在乐观 UI 操作过程中漂移（在线→离线），缓存层需要同时支持前置检查和回滚更新。

**严重程度**：中 — 实现细节缺失

**改进建议**：
- 在 `DeviceService` 中定义模块级缓存：`let cachedDevices: DeviceInfo[]` 和 `let lastFetchTime: number`
- 补充 `getCachedDevices(): DeviceInfo[]` 返回缓存值（不强制刷新），`refreshDevices(): Promise<DeviceInfo[]>` 强制刷新
- `CommandService.send()` 前调用 `DeviceService.getCachedDevices()` 做预检；若缓存过期或为空，调用 `refreshDevices()` 重新获取
- 在失败路径（`code=1003`）中补充：自动调用 `DeviceService.refreshDevices()` 更新缓存，避免后续请求基于过期的在线状态

---

### M4. `hilog` 日志策略在 OOD 设计中的覆盖范围（降级为低）

**状态**：低 — 超出设计文档必要范围（v4 已降级，维持不变）

---

### M5. 弱网场景请求重试机制缺失（从原 H10 拆分，中严重度子项）

**位置**：`a_v1_design_v3.md` 错误处理策略（第 373–393 行）

**问题描述**：
设计文档定义了网络错误、HTTP 状态码、业务错误码的分类处理，但未定义重试策略。在农业 IoT 弱网场景下，瞬时网络波动是常态，缺乏重试机制会导致用户体验频繁中断。

**严重程度**：中 — 非架构级缺失，属实现级策略缺失

**改进建议**：
- 在 `HttpClient` 中实现指数退避重试，可重试条件：网络异常（`catch` 捕获）或 HTTP 408/429/502/503/504
- 非幂等请求（`POST /command/send`）不做重试

---

## 低严重度问题

### L1. `constants.ets` 中的命令枚举未显式定义（未修复）

**位置**：`a_v1_design_v3.md` 模块目录 `constants.ets`（第 57 行）

**严重程度**：低

**改进建议**：
定义 `enum Command { LED_ON = 'led ON', ... }` 或 `type Command = 'led ON' | ...`

### L2. 循环渲染 `ForEach` 模式未在设计中引用（未修复）

**位置**：`a_v1_design_v3.md` 各处

**严重程度**：低

**改进建议**：
在 `IndexPage`、`DashboardPage`、`DiseaseRecordsPage` 的组件使用描述中补充 `ForEach` 示例

### L3. 弱网场景下本地缓存策略（从 H10 拆分，低严重度子项）

**位置**：`a_v1_design_v3.md` 错误处理策略

**严重程度**：低 — 可在编码阶段通过局部优化补充

**改进建议**：
在 `SensorService` 中实现轻量级内存缓存，网络失败时返回最后一次成功获取的数据，并在 UI 上标记"数据可能非最新"。

---

## API 覆盖完整性检查

| API | 对应 Service | 覆盖率 | 备注 |
|-----|-------------|--------|------|
| `GET /device/list` | `DeviceService` | ✅ | 完整覆盖 |
| `GET /sensor/latest` | `SensorService.getLatest()` | ✅ | 完整覆盖 |
| `GET /sensor/history` | `SensorService.getHistory()` | ✅ | 完整覆盖 |
| `GET /sensor/daily` | `SensorService.getDaily()` | ⚠️ | 模型已定义，Service 抽象中未列方法签名（M2） |
| `GET /disease/list` | `DiseaseService.getList()` | ✅ | 完整覆盖 |
| `GET /disease/stats` | `DiseaseService.getStats()` | ✅ | 完整覆盖 |
| `GET /disease/heatmap` | `DiseaseService.getHeatmap()` | ✅ | 完整覆盖 |
| `POST /command/send` | `CommandService.send()` | ✅ | 完整覆盖 |
| `GET /command/logs` | `CommandService.getLogs()` | ✅ | 完整覆盖 |
| `GET /advisory` | `AdvisoryService.getAdvisory()` | ✅ | 完整覆盖 |
| `POST /image/upload` | `ImageService.upload()` | ⚠️ | 方法签名和 MultiFormData 实现路径未定义（H3） |
| `GET /image/{image_id}` | `ImageService.getImagePixelMap()` | ⚠️ | 依赖 H1 的 `image_path` 语义确认（H1 + H4） |

---

## 总结

设计方案的**架构方向正确**——三层分离、`PollingManager`、`HttpClient` 门面等抽象决策是合理的。但 v3 版本可落地性缺口集中体现在三个维度：

**当前 9 项高严重度问题**（含新增 H9、H10）：

| 编号 | 类别 | 状态 | 核心问题 |
|------|------|------|---------|
| H1 | 语义未定 | 依赖确认 | `image_path` 未定导致展示路径不明确 |
| H2 | 框架缺口 | 任务分解 | Canvas 图表复杂度高，v1.0 需最小可用版本 |
| H3 | 架构矛盾 | 未修复 | MultiFormData 实现在错误的层次（应到 `api.ets`） |
| H4 | 架构遗漏 | 部分修复 | `api.ets` 缺少二进制响应路径，与 H1 耦合 |
| H5 | 架构矛盾 | 未修复 | `aboutToAppear` 同步约束 + `pushUrl` 不触发 `aboutToDisappear` |
| H6 | 架构遗漏 | 未修复 | 设备切换级联刷新的完整路径未定义 |
| H8 | 交互遗漏 | 未修复 | 乐观 UI 回滚未覆盖设备状态漂移场景 |
| H9 | 体验缺口 | 新增 | IndexPage 首页缺少传感器数据实时轮询 |
| H10 | 架构遗漏 | 新增 | IoT 弱网场景的缓存、重试、离线 UI 完全未覆盖 |

**关键依赖链**：`H1(image_path 语义)` → 影响 `H4(requestRaw 紧急性)` → 影响 API 覆盖完整性检查中 `GET /image/{image_id}` 的行；H9 和 H10 为独立新增。

**建议**：上述 9 项高严重度问题全部修复，且 `image_path` 语义经 API 确认后，方可进入编码阶段。

---

## 修订说明（v5 审查报告修订，响应质询 v4）

### 针对质询 CH1 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| IndexPage 首页传感器数据无实时轮询，审查报告未发现 | **接受** | 新增 H9 高严重度问题，在 IndexPage `aboutToAppear` 中补充 `index_sensor` 传感器轮询，更新行为契约和轮询调度约束表 |

### 针对质询 CH2 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| H2 工时估算 5–10 人日无出处、无分解、无对照 | **接受** | 修订 H2，将估算修正为细粒度任务分解表（坐标轴系统、数据映射、折线/柱状、触摸交互、双 Y 轴 6 个子任务各附独立工时区间），区分 v1.0 最小可用（2–4 人日）和完整功能（5–10 人日），补充技术依赖注释 |

### 针对质询 CH3 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| H1（image_path 语义待定）与 H4（requestRaw 必须）存在未处理的依赖矛盾 | **接受** | 在 H1 改进建议中新增"与 H4 耦合关系"段落，明确两种路径下 H4 严重度的升降规则；在 H4 改进建议中新增"严重度重新评估"段落，条件化映射至 H1 的验证结果；两条问题标注交叉引用 |

### 针对质询 CH4 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| 农业 IoT 场景的弱网韧性完全未覆盖 | **接受** | 新增 H10 高严重度问题（覆盖重试机制、离线 UI、本地缓存三大缺口），补充 `RetryPolicy` 接口定义、`CacheManager` 接口定义、离线 UI 状态设计方案；将重试策略作为 M5、本地缓存作为 L3 拆分子项 |

### 针对质询 CH5 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| 高严重度数量声称 9 项、实际 7 项，统计不一致 | **接受** | 修正统计口径：v4 版实际 HIGH 为 H1–H6 + H8 = 7 项；v5 版增加 H9、H10 后更新为 9 项。全局检查所有数量声称与实际情况一致 |

---

```
DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\b_v1_diag_v5.md
```
