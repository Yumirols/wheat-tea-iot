# 农眼卫士 FarmEye Guard v1.0 — OOD 设计方案可落地性审查报告

## 审查概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `a_v1_design_v3.md` — 鸿蒙移动应用 OOD 设计方案（v3） |
| 对应需求 | `requirement.md` — 鸿蒙移动应用 OOD 设计需求 |
| 审查视角 | OOD 设计的可落地性（ArkTS/ArkUI 框架可行性、组件划分、职责边界、协作关系、API 覆盖） |
| 审查方法 | 逐项对照需求、核查 ArkTS 框架能力、检查组件职责边界、验证协作路径完整性 |

---

## 整体评价

设计方案整体质量高，架构思路清晰（服务层 + 页面层 + 公共层三层分离），模块划分合理，API 覆盖完整（12 个接口全部覆盖）。服务层剥离 HTTP 业务语义、`PollingManager` 集中管理轮询、数据模型使用 `interface` 等决策符合 ArkTS 框架约束和单一职责原则。

**发现 4 个高严重度问题、4 个中严重度问题、2 个低严重度问题**，详情如下。

---

## 高严重度问题

### H1. `ImageViewer` 图片展示路径存在 ArkUI 实现障碍

**位置**：`a_v1_design_v3.md` §15 `ImageViewer`（第 273–280 行）

**问题描述**：
`ImageViewer` 的职责描述存在自相矛盾的两条路径：
1. "接收图片 URL（或图片二进制数据）作为属性"
2. "图片源来自 `DiseaseRecord.image_path`，通过 `ImageService.getImage(imageId)` 获取"

`ImageService.getImage()` 返回 `ArrayBuffer`（依据 §8 第 196 行）。但在 ArkUI 中，`Image` 组件接受 `string | Resource | PixelMap` 类型，**不支持直接以 `ArrayBuffer` 作为 `src`**。若要将 `ArrayBuffer` 渲染到 `<Image>` 组件，需要先通过 `image.createPixelMap()` 解码为 `PixelMap` 对象，这个流程涉及 `@ohos.multimedia.image` 的异步解码管线，非 ArkUI `Image` 组件的原生能力。

同时，`image_path` 字段本身可能是服务端可访问的 URL，若能直接作为 `<Image src={...}>` 使用，则 `ImageService.getImage()` 的二进制获取路径冗余。

**严重程度**：高 — 阻塞实现

**改进建议**：
- 方案 A（推荐）：明确 `image_path` 为服务端可访问 URL，`ImageViewer` 直接使用 `<Image src={diseaseRecord.image_path}>`，取消 `ImageService.getImage()` 二进制路径
- 方案 B（如需二进制）：在 `ImageViewer` 中接收 `PixelMap` 类型，`ImageService` 负责完成 `ArrayBuffer → PixelMap` 的解码并暴露 `getImagePixelMap(imageId): Promise<PixelMap>` 方法，`ImageViewer` 接收 `@Prop` 传入的 `PixelMap` 对象

---

### H2. `ChartView` 在 ArkUI 中缺少原生图表组件支持

**位置**：`a_v1_design_v3.md` §12 `ChartView`（第 237–245 行）

**问题描述**：
设计提及"在 ArkUI 的 `Canvas` 或 `Chart` 组件上绘制趋势图"。但：
- ArkUI（API 21）**不存在**内置 `<Chart>` 组件（`@ohos.graphics.chart` 在 API 21 中不可用）
- `Canvas` 组件（`<Canvas>`）虽可用，但从零实现完整的折线图/柱状图（含坐标轴、刻度、触摸交互、数据点详情弹窗）工程量较大，且 ArkUI 的 `CanvasRenderingContext2D` API 能力有限
- 参考项目 `reference/zhihui` 中无图表组件的实现先例

**严重程度**：高 — 存在框架能力缺口

**改进建议**：
- 明确选择 `Canvas` 路线，将 `ChartView` 的实现拆分为两个子职责：
  - 纯 Canvas 绘制逻辑封装为 `common/chart-renderer.ets`（坐标轴刻度、数据点映射、画线/柱）
  - 触摸交互处理（`onTouch` 事件 → 最近数据点检索 → 详情弹窗）在 `ChartView` 组件内部实现
- 在 `ChartView.ets` 中声明 `@State private renderer: ChartRenderer` 管理绘图状态
- 若未来 HarmonyOS 生态出现成熟的图表三方库（如 `ohpm` 上的图表包），可作为后续优化方向在注释中标记

---

### H3. `ImageService` 的 `multipart/form-data` 上传路径缺少 ArkTS 实现指引

**位置**：`a_v1_design_v3.md` §8 `ImageService`（第 189 行）、§2 `HttpClient` 第 125 行

**问题描述**：
设计指出"构建 FormData（文件二进制 + 可选参数）"并通过 `HttpClient.post()` 的 `contentType` 覆盖发送。但在 ArkTS / `@ohos.net.http` 中：
- `@ohos.net.http` 提供 `http.MultiFormData` 类用于构建 multipart 请求体，需要在 `http.request()` 的 `extraData` 中传入 `MultiFormData` 对象
- `HttpClient.post()` 当前设计在 JSON 路径下对 body 执行 `JSON.stringify()` 序列化，而 `MultiFormData` 对象**不经过 JSON 序列化**，需要 `post()` 内部对 `extraData` 类型进行判断分支处理
- 设计未定义 `multipart/form-data` 请求体在 ArkTS 类型系统中的具体结构

**严重程度**：高 — 实现需补充技术细节

**改进建议**：
- 在 `HttpClient.post<T>()` 方法签名中明确 `body` 参数类型为 `string | Object | http.MultiFormData`（而非单一泛型 T），内部根据类型判断序列化策略：`Object` → `JSON.stringify`、`MultiFormData` → 直接传入 `extraData`
- 在 `ImageService.upload(fileUri: string, params?: Record<string, string>)` 的方法签名中显式表达：文件通过 URI 引用而非内存二进制，`MultiFormData` 通过 `http.createMultipartFormData().addPart()` 构建
- 在 `common/api.ets` 层或 `services/` 下补充 `formDataBuilder.ets` 辅助函数，封装 `MultiFormData` 的构建细节

---

### H4. `api.ets` 的 `NetworkResult.rawBody: string` 无法承载二进制响应

**位置**：`a_v1_design_v3.md` 核心接口表 `NetworkResult`（第 301 行）、§2 `HttpClient` 第 124 行

**问题描述**：
`NetworkResult` 定义中 `rawBody` 类型为 `string`，但 `HttpClient.getRaw()` 需要返回 `ArrayBuffer` 给 `ImageService`。`@ohos.net.http` 通过 `http.request()` 的 `expectDataType` 选项控制响应体格式：
- `http.HttpDataType.STRING` — 返回 `string`
- `http.HttpDataType.ARRAY_BUFFER` — 返回 `ArrayBuffer`

当前 `api.ets` 只有一条返回路径（`string`），**无法同时支持 JSON 文本响应和二进制图片响应**。需要 `api.ets` 根据调用者需求切换 `expectDataType`。

**严重程度**：高 — 架构遗漏

**改进建议**：
- 在 `api.ets` 中新增 `requestRaw(url, options)` 方法，内部设置 `expectDataType: http.HttpDataType.ARRAY_BUFFER`，返回 `{ statusCode, headers, rawBody: ArrayBuffer }`
- 或在 `api.ets` 的 `request()` 参数中新增 `responseType: 'text' | 'arraybuffer'` 选项，统一出口但内部按需设置 `expectDataType`
- 同时将 `NetworkResult.rawBody` 类型修改为 `string | ArrayBuffer`（联合类型），或拆分为 `TextResult` / `BinaryResult` 两个类型

---

## 中严重度问题

### M1. 轮询告警状态 → UI 渲染的传播路径未定义

**位置**：`a_v1_design_v3.md` 场景 A（第 316–317 行）

**问题描述**：
场景 A 描述 `PollingManager` 的回调中调用 `AdvisoryService.getAdvisory()` → "检测新告警" → "如有重度告警 → AlarmBanner 显示"。但告警检测结果如何从 `setInterval` 回调传递到 `IndexPage.ets` 的 `@State` 变量并最终传递给 `<AlarmBanner>` 组件的 `@Prop`，设计**未描述**。

在 ArkTS 中，`setInterval` 回调运行在 UI 线程，可以访问页面闭包中的 `@State` 变量，但设计未定义：
- 告警状态的 `@State` 变量声明位置
- 轮询回调中更新 `@State` 的具体方式
- `AlarmBanner` 接收的 `@Prop` 属性类型

**严重程度**：中 — 实现者需自行推断

**改进建议**：
- 在 `IndexPage` 的核心抽象定义中补充：`@State private alarmMessage: string | null` 和 `@State private alarmSeverity: 'mild' | 'moderate' | 'severe' | null`
- 在场景 A 的行为契约中补充：`PollingManager.start('index_alarm', 10000, async () => { const advisory = await AdvisoryService.getAdvisory(); if (advisory.latest_detection?.severity === 'severe') { this.alarmMessage = ...; this.alarmSeverity = 'severe'; } })`
- `AlarmBanner` 接收 `@Prop alarmMessage: string` 和 `@Prop severity: string`

---

### M2. `SensorService` 核心抽象中遗漏 `getDaily()` 方法

**位置**：`a_v1_design_v3.md` §3 `SensorService`（第 131–140 行）

**问题描述**：
`SensorService` 在核心接口表（第 293 行）中声明了 `DailyAggregation` 模型类型，对应 `GET /sensor/daily` 接口，但在核心抽象 §3 的方法描述中仅列出"最新快照、历史数据、日聚合三种查询"，未具体定义 `getDaily()` 的方法签名、参数和返回类型。API 接口需求明确要求了 `page` / `page_size` 分页参数。

**严重程度**：中 — 不完整

**改进建议**：
- 在 §3 `SensorService` 的职责描述中补充：`getDaily(deviceId: string, start: string, end: string, page?: number, pageSize?: number): Promise<PaginatedData<DailyAggregation>>`

---

### M3. `CommandService` 与 `DeviceService` 的在线状态依赖缺少缓存层定义

**位置**：`a_v1_design_v3.md` §5 `CommandService`（第 158–160 行）

**问题描述**：
设计指出"在下发前通过 `DeviceService` 前置检查设备在线状态（若本地缓存的设备状态为离线则提前拒绝）"，但：
- "本地缓存的设备状态"未定义在哪里维护 — 是 `DeviceService` 持有模块级缓存变量？还是 `ControlPage` 的 `@State`？还是 `PollingManager`？
- 若 `DeviceService.getDeviceList()` 每次请求最新状态，则获取后才能判断"离线"→"拒绝"，这与"前置检查"的优化目的矛盾
- 若为模块级缓存，第一次访问时未初始化，需要定义缓存刷新机制

**严重程度**：中 — 实现细节缺失

**改进建议**：
- 在 `DeviceService` 中定义模块级缓存：`let cachedDevices: DeviceInfo[]` 和 `let lastFetchTime: number`
- 补充 `getCachedDevices(): DeviceInfo[]` 方法返回缓存值（不强制刷新），`refreshDevices(): Promise<DeviceInfo[]>` 强制刷新缓存
- `CommandService.send()` 前调用 `DeviceService.getCachedDevices()` 做预检；若缓存过期或为空，调用 `refreshDevices()` 重新获取后再次检查

---

### M4. `hilog` 日志策略未在设计中体现

**位置**：`a_v1_design_v3.md` 全文

**问题描述**：
需求明确要求"日志：`hilog`（来自 `@kit.PerformanceAnalysisKit`）"，且该约束在 v1/v2/v3 的多轮审查中均已被确认通过。但当前设计文档（v3）中**全文未提及** `hilog` 的使用策略，包括：
- 各 Service 的错误日志如何记录
- 日志级别约定（INFO / WARN / ERROR）
- `PollingManager` 的轮询行为日志
- 日志标签（`LOG_TAG`）的命名规范

**严重程度**：中 — 未满足需求约束

**改进建议**：
- 在 `common/utils.ets` 中增加日志工具函数，或直接在 `common/` 下新增 `logger.ets`，封装 `hilog` 的 `info` / `warn` / `error` 方法
- 约定统一的 `LOG_TAG: string = 'FarmEye'` 和领域子标签（如 `'SensorService'`, `'PollingManager'`）
- 在错误处理策略的错误分类表中，每类错误的"处理方式"列补充日志行为

---

## 低严重度问题

### L1. `constants.ets` 中的命令枚举未显式定义

**位置**：`a_v1_design_v3.md` 模块目录 `constants.ets`（第 57 行）

**问题描述**：
设计在模块目录中标注 `constants.ets` 包含"命令枚举"，需求 §4.7 明确列出 8 条命令（`led ON/OFF`、`beep ON/OFF`、`spray ON/OFF`、`irrig ON/OFF`），但设计中未给出具体的 `enum` 或 `type` 定义。

**严重程度**：低

**改进建议**：
- 在 `common/constants.ets` 中补充：
  ```
  export enum Command { LED_ON = 'led ON', LED_OFF = 'led OFF', BEEP_ON = 'beep ON', BEEP_OFF = 'beep OFF', SPRAY_ON = 'spray ON', SPRAY_OFF = 'spray OFF', IRRIG_ON = 'irrig ON', IRRIG_OFF = 'irrig OFF' }
  ```

---

### L2. 循环渲染 `ForEach` 模式未在设计中引用

**位置**：`a_v1_design_v3.md` 各处

**问题描述**：
需求在参考项目约定（§6.9）中明确"循环渲染：`ForEach(arr, (item) => {...})`"是项目的标准 UI 渲染模式。但设计文档中未显式引用 `ForEach`，例如 `SensorCard` 群组渲染和 `DiseaseRecord` 列表渲染。

**严重程度**：低

**改进建议**：
- 在 `IndexPage` 和 `DashboardPage` 的 `SensorCard` 使用描述中补充 `ForEach(sensorDataList, (item) => { SensorCard({...}) })`
- 在 `DiseaseRecordsPage` 的列表渲染描述中补充 `ForEach(records, (item) => { ... })`

---

## API 覆盖完整性检查

| API | 对应 Service | 覆盖率 | 备注 |
|-----|-------------|--------|------|
| `GET /device/list` | `DeviceService` | ✅ | 完整覆盖 |
| `GET /sensor/latest` | `SensorService.getLatest()` | ✅ | 完整覆盖 |
| `GET /sensor/history` | `SensorService.getHistory()` | ✅ | 完整覆盖 |
| `GET /sensor/daily` | `SensorService.getDaily()` | ⚠️ | 模型已定义，但 Service 抽象中未列方法签名（见 M2） |
| `GET /disease/list` | `DiseaseService.getList()` | ✅ | 完整覆盖 |
| `GET /disease/stats` | `DiseaseService.getStats()` | ✅ | 完整覆盖 |
| `GET /disease/heatmap` | `DiseaseService.getHeatmap()` | ✅ | 完整覆盖 |
| `POST /command/send` | `CommandService.send()` | ✅ | 完整覆盖 |
| `GET /command/logs` | `CommandService.getLogs()` | ✅ | 完整覆盖 |
| `GET /advisory` | `AdvisoryService.getAdvisory()` | ✅ | 完整覆盖 |
| `POST /image/upload` | `ImageService.upload()` | ⚠️ | 未定义方法签名（见 H3） |
| `GET /image/{image_id}` | `ImageService.getImage()` | ⚠️ | 实现路径存疑（见 H1 + H4） |

---

## 总结

设计方案的**架构正确性**和**模块划分合理性**值得肯定，三层分离、`PollingManager`、`HttpClient` 门面等抽象决策均可落地。

核心可落地的障碍集中在 **4 个 ArkUI/ArkTS 框架能力缺口**上：`ImageViewer` + `ArrayBuffer` 的渲染路径（H1）、`ChartView` 缺少内置图表组件（H2）、`multipart/form-data` 缺少 ArkTS API 层面的实现指引（H3）、`api.ets` 未支持二进制响应模式（H4）。这四个问题需在下一版本的设计中补充技术细节或重构实现路径。

---

```
DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\b_v1_diag_v1.md
```
