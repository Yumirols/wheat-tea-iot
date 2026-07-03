# 农眼卫士 FarmEye Guard v1.0 — OOD 设计方案可落地性审查报告（v4，响应质询版）

## 审查概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `a_v1_design_v3.md` — 鸿蒙移动应用 OOD 设计方案（v3） |
| 对应需求 | `requirement.md` — 鸿蒙移动应用 OOD 设计需求 |
| 审查视角 | OOD 设计的可落地性（ArkTS/ArkUI 框架可行性、组件划分、职责边界、协作关系、API 覆盖） |
| 审查方法 | 基于 v2 审查报告及质询文件逐项复核，按质询意见修订建议 |
| 本版变更 | 响应质询 CH1/CH2/CH3：CH1 接受→H7 降级为中（非 v1.0 阻塞）；CH2 接受→H1 补充 URL 直接加载路径分析；CH3 接受→M4 降级为低（超出设计文档范围） |

---

## 整体评价

设计方案的三层架构（服务层 + 页面层 + 公共层）划分合理，API 覆盖完整，`PollingManager` 集中管理轮询等决策符合 ArkUI 框架约束。

**但 v3 设计版本仅修正了 4 处表面问题**（key 命名对齐、错误码精确列出、`NetworkResult` 补充到模型表、`getRaw()` 方法新增），**v2 审查报告发现的 6 项高严重度问题（H1-H6）均未被设计作者实质性修复**。上一轮质询（CH1-CH5）中，CH1/CH2/CH3 在 v4 中已接受修订（H7 降级为中、H1 补充替代路径分析、M4 降级为低），CH4/CH5 维持原判定。

**v4 审查：9 项高严重度问题、4 项中严重度问题、3 项低严重度问题**（依据质询 CH1/CH2/CH3 修订），详情如下。

---

## 高严重度问题

### H1. `ImageViewer` 图片展示路径：需补充 `image_path` 语义分析（修订，依据质询 CH2 补充替代路径）

**位置**：`a_v1_design_v3.md` §15 `ImageViewer`（第 273–280 行）

**问题描述**：
设计存在两条潜在的图片展示路径，但未明确选择，且 v3 审查（及关联 H4）未评估最简路径：

**路径 A — URL 直接加载**：若 `DiseaseRecord.image_path` 为完整 URL（或可通过 `baseURL + image_path` 拼接），则 `ImageViewer` 直接使用 `<Image src={image_path}>`，ArkUI 天然支持，零额外复杂度。**此路径无需 `ImageService.getImage()`，无需 `ArrayBuffer`，无需 `PixelMap` 解码**。

**路径 B — 二进制 + PixelMap 解码**：若 `image_path` 为 image_id，需 `ImageService.getImage(imageId)` → `HttpClient.getRaw()` → `ArrayBuffer` → `ImageSource` → `PixelMap` → `<Image src={pixelMap}>`。

**依据质询 CH2 的补充分析**：
- v3 审查 **未评估路径 A 的可行性**，即断言 PixelMap 解码为必经之路，证据链不完整
- 从 API 设计惯例判断，`image_path` 字段更可能存储 URL（便于前端直接消费），而非需要二次请求的 image_id
- 若 `image_path` 为 URL，则 H1 和 H4 的紧急度将显著降低

**严重程度**：高 — 当前设计未明确 `image_path` 语义，两条路径均不可确定实施

**改进建议**：
- **首要行动**：需求/API 文档中明确 `DiseaseRecord.image_path` 字段的语义（URL vs image_id）
  - 若为 URL → `ImageViewer` 采用 `<Image src={image_path}>`，无额外架构需求
  - 若为 image_id → 采用 `ImageService.getImagePixelMap(imageId)` 完成 `ArrayBuffer` → `PixelMap` 解码链
- **无论何种路径**：`api.ets` 层仍需新增 `requestRaw()` 方法（见 H4），作为二进制数据获取的基础设施（`GET /image/{image_id}` 接口需要）

---

### H2. `ChartView` 在 ArkUI 中缺少原生图表组件，Canvas 实现复杂度未评估（未修复）

**位置**：`a_v1_design_v3.md` §12 `ChartView`（第 237–245 行）

**问题描述**：
ArkUI API 21 无内置 `<Chart>` 组件，`Canvas` 路线需从零实现坐标轴、刻度、数据点映射、触摸交互。v3 设计仍停留在"在 Canvas 或 Chart 组件上绘制"的模糊描述层面。

**依据质询 CH4 补充的复杂度评估**：
- **坐标轴系统**：需要自绘 X/Y 轴刻度线、标签文本（含单位）、网格线，涉及 `CanvasRenderingContext2D` 的 `strokeLine` / `fillText` / `measureText` 等 API
- **折线/柱状图绘制**：需将 `SensorHistory[]` 数据点映射为 Canvas 像素坐标，处理 `min`/`max` 值域缩放、离群值裁切
- **触摸交互**：`onTouch` 事件 → 像素坐标反算数据索引 → 弹窗展示详情，需要实现空间索引或线性遍历
- **多曲线复合**：温湿度双轴图表需要两个 Y 轴刻度系统，渲染层需要分层绘制
- **参考项目** `reference/zhihui` 中无 Canvas 图表先例，无法复用

**严重程度**：高 — 存在框架能力缺口，开发量预估 5–10 人日

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

**依据质询 CH2 修订的建议**：
- ❌ **错误方向**（v2 审查报告原建议）：将 `HttpClient.post()` 的 `body` 参数类型改为 `string | Object | http.MultiFormData`——这会破坏"仅 `api.ets` 依赖 `@ohos.net.http`"的架构约束
- ✅ **正确方向**：在 `common/api.ets` 层暴露 FormData 构建的抽象函数，或 `HttpClient.post()` 的 `contentType` 和 `rawBody: string | Object | ArrayBuffer` 由 `api.ets` 内部完成 `MultiFormData` 的构建与传输

**严重程度**：高 — 实现需补充技术细节

**改进建议**（修订版）：
- 在 `common/api.ets` 中新增 `buildFormData(fields: Record<string, string | { uri: string; name: string }>)` 辅助函数，内部调用 `http.createMultipartFormData().addPart()`，返回 `http.MultiFormData` 实例
- `api.ets` 新增 `requestMultipart(url, formData, options)` 方法，内部设置 `extraData: formData` 和 `Content-Type: multipart/form-data`
- `HttpClient.post<T>()` 新增 `multipart?: Record<string, string | { uri: string; name: string }>` 可选参数；当 `multipart` 存在时，调用 `api.ets` 的 `requestMultipart()` 路径，而非 JSON 序列化路径
- `ImageService.upload(fileUri: string, params?: Record<string, string>)` 内部组装 `fields` 结构，调用 `HttpClient.post()` 的 multipart 模式

---

### H4. `api.ets` 的 `NetworkResult.rawBody: string` 无法承载二进制响应（部分修复，仍需补充）

**位置**：`a_v1_design_v3.md` 核心接口表 `NetworkResult`（第 301 行）、§2 `HttpClient` 第 124 行

**问题描述**：
v3 设计虽在 `HttpClient` 新增了 `getRaw()` 方法描述（返回 `ArrayBuffer`），但**未描述 `api.ets` 层如何支持**。`@ohos.net.http` 通过 `expectDataType` 控制响应体格式：`STRING` → `string`，`ARRAY_BUFFER` → `ArrayBuffer`。当前 `api.ets` 只有一条返回路径（`string`），无法同时支持 JSON 文本响应和二进制图片响应。

且 `NetworkResult.rawBody: string` 的类型定义仍然只覆盖文本场景。

**严重程度**：高 — 架构遗漏

**改进建议**：
- 在 `api.ets` 中新增 `requestRaw(url, options)` 方法，内部设置 `expectDataType: http.HttpDataType.ARRAY_BUFFER`，返回 `{ statusCode: number; headers: Object; rawBody: ArrayBuffer }`
- 将 `NetworkResult` 拆分为两个类型：`TextResult { rawBody: string }` 和 `BinaryResult { rawBody: ArrayBuffer }`，或使用联合类型 `string | ArrayBuffer`

---

### H5. 所有页面 `aboutToAppear` 中编排异步加载 + `pushUrl` 场景下轮询停止契约不可执行（未修复，依据 CH1 补充）

**位置**：`a_v1_design_v3.md` 场景 A/B/C/D/E（第 309–369 行）

**问题描述**（v2 已发现 + 依据 CH1 补充）：

**v2 已发现**：`aboutToAppear()` 在 ArkUI API 21 中为**同步函数**，不支持 `async`，设计文档全文未定义页面初始加载状态的 UI 表现（骨架屏 / 加载指示器 / 空状态占位）。

**依据 CH1 补充的致命矛盾**：设计文档场景 E 的契约：

```
页面 A → router.pushUrl('pages/B')
  ├─ 页面 A.aboutToDisappear() → PollingManager.stop('A相关key')
  └─ 页面 B.aboutToAppear() → PollingManager.start('B相关key')
```

但在 ArkUI API 21 中：
- `router.pushUrl()` → 目标页面入栈，原页面**隐藏但未销毁**，**不会触发** `aboutToDisappear`
- `router.replaceUrl()` → 当前页面被替换销毁，**会触发** `aboutToDisappear`
- `router.back()` → 当前页面弹出销毁，**会触发** `aboutToDisappear`

因此场景 E 的 `pushUrl` 分支下**轮询停止契约不可执行**。结果是：页面 A 处于隐藏状态时，其轮询仍在后台运行，浪费资源并写入已隐藏页面的 `@State`。

**严重程度**：高 — 每个页面首次加载的空状态 + 隐藏页面的轮询泄漏

**改进建议**（合并 v2 + CH1）：
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

### H7. `PollingManager` 接口扩展性展望（修订，依据质询 CH1 降级为中）

**位置**：`a_v1_design_v3.md` §9 `PollingManager`（第 201–212 行）、需求 §2.2

**问题描述**：

需求 §2.2 明确"v1.0 采用 HTTP 轮询 10s 间隔，**后续可升级**为 WebSocket"。当前 `PollingManager` 的 `start(key, fn, interval)` 接口完全满足 v1.0 HTTP 轮询需求，且已优于参考项目 `reference/zhihui` 的直接 `setInterval` 模式。

**依据质询 CH1 的判定**：
- WebSocket 升级是"后续"路径，非 v1.0 约束条件
- 当前接口不阻塞 v1.0 实现
- v3 审查将此误判为高严重度，与需求范围矛盾

**严重程度**：中 — 非 v1.0 阻塞，属未来扩展性关注点

**改进建议**（可选，可在后续版本引入）：
- 在 `PollingManager` 中引入 `DataSource` 类型：`type DataSource = 'polling' | 'push'`
- v1.0 接口改为 `startPolling(key, fn, interval)`，预留 `subscribePush(key, handler)` 扩展点
- 在"设计决策"中补充此扩展性决策记录

---

### H8. 乐观 UI 回滚未覆盖设备状态漂移场景（新增，依据质询 CH3）

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

### M3. `CommandService` 与 `DeviceService` 的在线状态依赖缺少缓存层定义 + 乐观 UI 回滚联动（未修复，依据 CH3 补充）

**位置**：`a_v1_design_v3.md` §5 `CommandService`（第 158–160 行）

**问题描述**：
设计指出"在下发前通过 `DeviceService` 前置检查设备在线状态"，但"本地缓存的设备状态"未定义在哪里维护。与此联动的是 H8 所述——设备状态可能在乐观 UI 操作过程中漂移（在线→离线），缓存层需要同时支持前置检查和回滚更新。

**严重程度**：中 — 实现细节缺失

**改进建议**：
- 在 `DeviceService` 中定义模块级缓存：`let cachedDevices: DeviceInfo[]` 和 `let lastFetchTime: number`
- 补充 `getCachedDevices(): DeviceInfo[]` 返回缓存值（不强制刷新），`refreshDevices(): Promise<DeviceInfo[]>` 强制刷新
- `CommandService.send()` 前调用 `DeviceService.getCachedDevices()` 做预检；若缓存过期或为空，调用 `refreshDevices()` 重新获取
- 在失败路径（`code=1003`）中补充：自动调用 `DeviceService.refreshDevices()` 更新缓存，避免后续请求基于过期的在线状态

---

### M4. `hilog` 日志策略在 OOD 设计中的覆盖范围（修订，依据质询 CH3 降级为低）

**位置**：`a_v1_design_v3.md` 全文

**问题描述**：

需求 §3 技术栈列出的"日志：`hilog`（来自 `@kit.PerformanceAnalysisKit`）"属于**技术选型说明**，而非要求设计文档必须定义日志策略的行为约束。

**依据质询 CH3 的判定**：
- OOD 设计文档的职责是架构、组件划分、协作关系和关键行为契约
- 日志调用方式属于编码阶段的实现惯例，可在编码规范中约定而非设计文档中展开
- v3 审查对设计文档的内容边界期望过高

**严重程度**：低 — 超出设计文档必要范围，可作为编码规范补充

**改进建议**（可选）：
- 若需纳入设计文档，可在 `common/` 下新增 `logger.ets`，封装 `hilog` 的 `info` / `warn` / `error` 方法
- 在错误处理策略的错误分类表中，每类错误的"处理方式"列补充日志行为

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
| `GET /image/{image_id}` | `ImageService.getImagePixelMap()` | ⚠️ | 需改为 PixelMap 解码路径（H1 + H4） |

---

## 总结

设计方案的**架构方向正确**——三层分离、`PollingManager`、`HttpClient` 门面等抽象决策是合理的。但 v3 版本仅做了 4 处表面修正，核心可落地性问题未被触及。

**当前 9 项高严重度问题**：

| 编号 | 类别 | 状态 | 核心问题 |
|------|------|------|---------|
| H1 | 框架缺口 | 修订 | `image_path` 语义未定导致展示路径不明确；若为 URL 则 PixelMap 解码非必需（详见正文 CH2 分析） |
| H2 | 框架缺口 | 未修复 | Canvas 图表复杂度未评估，无从零实现路径 |
| H3 | 实现指引 | 建议修正 | MultiFormData 应实现在 `api.ets` 层而非 `services/` 层 |
| H4 | 架构遗漏 | 部分修复 | `api.ets` 缺少 `requestRaw()` 方法和 `ArrayBuffer` 响应路径 |
| H5 | 架构矛盾 | 未修复 | `aboutToAppear` 同步约束 + `pushUrl` 不触发 `aboutToDisappear` |
| H6 | 架构遗漏 | 未修复 | 设备切换级联刷新的完整路径未定义 |
| H8 | 交互遗漏 | 未修复 | 乐观 UI 回滚未覆盖设备状态漂移场景 |

**三个框架缺口**（H1+H2+H4）需要 ArkUI 原生 API 知识方可落地，无法在架构层面解决。

**两个架构矛盾**（H3+H5）需要设计作者重新审视分层边界和路由生命周期。

**两个架构遗漏**（H6+H8）需要在设计文档中补充完整的行为契约。

**建议**：上述 9 项高严重度问题全部修复，且 `image_path` 语义经 API 确认后，方可进入编码阶段。

---

## 修订说明（v3 审查报告修订，响应质询 v2）

### 针对质询 CH1 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| `pushUrl` 不触发 `aboutToDisappear`，场景 E 的轮询停止契约不可执行 | **接受** | 在 H5 中补充此致命矛盾，修正场景 E 的轮询停止策略：`pushUrl` 不停止原页面轮询（页面未销毁），仅 `replaceUrl`/`back` 才触发停止；增加 `onBackground`/`onForeground` 的全局暂停/恢复作为兜底 |

### 针对质询 CH2 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| H3 建议 `HttpClient.post()` 签名引入 `http.MultiFormData` 违反三层依赖方向 | **接受** | 修订 H3 改进建议，改为在 `common/api.ets` 层新增 `buildFormData()` 辅助函数和 `requestMultipart()` 方法；`HttpClient.post()` 新增 `multipart?` 抽象参数（非 `http.MultiFormData` 类型），由 `api.ets` 内部完成构造和传输 |

### 针对质询 CH3 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| 乐观 UI 回滚未覆盖设备状态漂移场景 | **接受** | 新增 H8 高严重度问题，定义 `previousState` 保存、回滚后 `DeviceService.refreshDevices()` 刷新缓存、toast 提示区分策略；在 M3 中补充缓存层与回滚的联动设计 |

### 针对质询 CH4 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| Canvas 图表实现复杂度未评估 | **接受** | 在 H2 中补充复杂度评估（坐标轴系统、多曲线复合、触摸交互的 API 依赖和预估工作量），给出分阶段实现建议（v1.0 最小可用：单 Y 轴折线图，无触摸交互），以及 `ChartRendererAPI` 接口抽象预留方案 |

### 针对质询 CH5 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| `PollingManager` 未考虑 WebSocket 升级路径 | **接受** | 新增 H7 高严重度问题，引入 `DataSource` 类型和 `startPolling()` / `subscribePush()` 分离式接口，在设计决策中补充扩展性决策记录 |

---

## 修订说明（v4 审查报告修订，响应质询 v3）

### 针对质询 CH1 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| H7 严重度（HIGH）与需求明确的 v1.0 范围矛盾，WebSocket 升级是"后续"而非当前阻塞项 | **接受** | H7 降级为中严重度，修订描述为"未来扩展性关注点"，移除"阻塞"定性；更新总结表中 H7 行和严重度统计（10 HIGH → 9 HIGH） |

### 针对质询 CH2 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| H1 未评估 URL 直接加载的替代路径，即断言 PixelMap 解码为必经之路，证据链不完整 | **接受** | H1 重写为"`image_path` 语义分析"，补充路径 A（URL 直接加载）和路径 B（二进制 + PixelMap 解码）的取舍分析；首要改进建议改为"明确 `image_path` 语义"；保留 H1 高严重度（因为语义未定仍阻塞实现），但修正了证据方向 |

### 针对质询 CH3 的响应

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| M4 对设计文档的内容边界判断偏严，将技术选型说明等同于设计要求 | **接受** | M4 降级为低严重度，判定"超出设计文档必要范围"；改进建议标记为"可选" |

---

```
DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\b_v1_diag_v4.md
```
