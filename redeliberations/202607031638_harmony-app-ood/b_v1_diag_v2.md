# 农眼卫士 FarmEye Guard v1.0 — OOD 设计方案可落地性审查报告（v2，修订版）

## 审查概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `a_v1_design_v3.md` — 鸿蒙移动应用 OOD 设计方案（v3） |
| 对应需求 | `requirement.md` — 鸿蒙移动应用 OOD 设计需求 |
| 审查视角 | OOD 设计的可落地性（ArkTS/ArkUI 框架可行性、组件划分、职责边界、协作关系、API 覆盖） |
| 审查方法 | 基于 v1 审查报告及质询文件逐项复核，修订遗漏和证据不充分项 |
| 本版变更 | 接受质询 CH1/CH2/CH3/CH4，新增高严重度问题 2 项，修订 H1/M1 建议 |

---

## 整体评价

设计方案整体质量高，架构思路清晰（服务层 + 页面层 + 公共层三层分离），模块划分合理，API 覆盖完整（12 个接口全部覆盖）。服务层剥离 HTTP 业务语义、`PollingManager` 集中管理轮询、数据模型使用 `interface` 等决策符合 ArkTS 框架约束和单一职责原则。

**v2 修订：发现 6 个高严重度问题、4 个中严重度问题、2 个低严重度问题**，详情如下。

---

## 高严重度问题

### H1. `ImageViewer` 图片展示路径存在 ArkUI 实现障碍（v2 修订建议）

**位置**：`a_v1_design_v3.md` §15 `ImageViewer`（第 273–280 行）

**问题描述**：
`ImageViewer` 的职责描述存在自相矛盾的两条路径：
1. "接收图片 URL（或图片二进制数据）作为属性"
2. "图片源来自 `DiseaseRecord.image_path`，通过 `ImageService.getImage(imageId)` 获取"

`ImageService.getImage()` 返回 `ArrayBuffer`（依据 §8 第 196 行）。但在 ArkUI 中，`Image` 组件接受 `string | Resource | PixelMap` 类型，**不支持直接以 `ArrayBuffer` 作为 `src`**。若要将 `ArrayBuffer` 渲染到 `<Image>` 组件，需要先通过 `image.createPixelMap()` 解码为 `PixelMap` 对象。

**v2 关键补充**：v1 报告的方案 A（直接使用 `<Image src={diseaseRecord.image_path}>`）已被质询 CH3 证伪——需求文档定义的 `GET /image/{image_id}` 是带认证头的 API 端点，ArkUI `Image` 组件发起的请求**不会携带 `X-API-Key` 认证头**，且 API 21 中 `Image` 组件**不支持自定义请求头**。因此方案 A 在实际可落地性上不可行。

**严重程度**：高 — 阻塞实现

**改进建议**（v2 修订，仅保留可行方案）：
- **唯一可行方案**：`ImageService` 暴露 `getImagePixelMap(imageId): Promise<PixelMap>` 方法，内部依次完成：
  1. `HttpClient.getRaw('/image/{imageId}')` → 获取 `ArrayBuffer`
  2. `image.createImageSource(arrayBuffer)` → 创建图片源
  3. `imageSource.createPixelMap()` → 解码为 `PixelMap`
- `ImageViewer` 接收 `@Prop imgPixelMap: PixelMap | undefined` 属性，直接传入 `<Image src={this.imgPixelMap}>`
- 同时 `DiseaseRecord` 模型中保留 `image_path` 字段（在 `getImagePixelMap` 方法内部仅需 `image_id`，路径由 `HttpClient` 拼装）

---

### H2. `ChartView` 在 ArkUI 中缺少原生图表组件支持

**位置**：`a_v1_design_v3.md` §12 `ChartView`（第 237–245 行）

**问题描述**：
设计提及"在 ArkUI 的 `Canvas` 或 `Chart` 组件上绘制趋势图"。但：
- ArkUI（API 21）**不存在**内置 `<Chart>` 组件
- `Canvas` 组件虽可用，但从零实现完整的折线图/柱状图（含坐标轴、刻度、触摸交互、数据点详情弹窗）工程量较大
- 参考项目 `reference/zhihui` 中无图表组件的实现先例

**严重程度**：高 — 存在框架能力缺口

**改进建议**：
- 明确选择 `Canvas` 路线，将 `ChartView` 的实现拆分为两个子职责：
  - 纯 Canvas 绘制逻辑封装为 `common/chart-renderer.ets`（坐标轴刻度、数据点映射、画线/柱）
  - 触摸交互处理（`onTouch` 事件 → 最近数据点检索 → 详情弹窗）在 `ChartView` 组件内部实现
- 在 `ChartView.ets` 中声明 `@State private renderer: ChartRenderer` 管理绘图状态
- 若未来 HarmonyOS 生态出现成熟的图表三方库，可作为后续优化方向

---

### H3. `ImageService` 的 `multipart/form-data` 上传路径缺少 ArkTS 实现指引

**位置**：`a_v1_design_v3.md` §8 `ImageService`（第 189 行）、§2 `HttpClient` 第 125 行

**问题描述**：
设计指出"构建 FormData（文件二进制 + 可选参数）"并通过 `HttpClient.post()` 的 `contentType` 覆盖发送。但在 `@ohos.net.http` 中：
- `http.MultiFormData` 类用于构建 multipart 请求体，需要在 `http.request()` 的 `extraData` 中传入 `MultiFormData` 对象
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

**v2 补充**：此问题与 H1 的 PixelMap 解码路径直接关联——`ImageService.getImagePixelMap()` 的实现依赖于 `api.ets` 提供 `ArrayBuffer` 响应能力，修复 H4 是 H1 方案 B 的前提条件。

**严重程度**：高 — 架构遗漏

**改进建议**：
- 在 `api.ets` 中新增 `requestRaw(url, options)` 方法，内部设置 `expectDataType: http.HttpDataType.ARRAY_BUFFER`，返回 `{ statusCode, headers, rawBody: ArrayBuffer }`
- 或将 `NetworkResult.rawBody` 类型修改为 `string | ArrayBuffer`（联合类型），或拆分为 `TextResult` / `BinaryResult` 两个类型

---

### H5. 所有页面 `aboutToAppear` 中编排异步加载，违反 ArkUI 同步约束（v2 新增）

**位置**：`a_v1_design_v3.md` 场景 A/B/C/D/E（第 309–369 行）

**问题描述**：
设计文档中的行为契约将异步数据加载直接写在 `aboutToAppear()` 下：

```
IndexPage.aboutToAppear()
  ├─ DeviceService.getDeviceList()
  ├─ SensorService.getLatest(deviceId)
  └─ PollingManager.start(...)
```

但在 ArkUI（API 21）中，`aboutToAppear()` 生命周期方法为**同步函数**，不支持 `async` 关键字。ArkUI 框架不会等待异步操作完成再执行首次 `build()` 渲染。这意味着：
- 所有页面在首次 `build()` 渲染时数据必然为空（或初始值）
- 从首次渲染到异步数据到达之间存在未定义的 **空白状态窗口**
- 设计文档**全文未定义页面初始加载状态的 UI 表现**（骨架屏 / 加载指示器 / 空状态占位）

**严重程度**：高 — 每个页面首次加载时均存在未定义的空状态

**改进建议**：
- 在每个页面的核心抽象中补充加载状态声明：`@State private isLoading: boolean = true`
- 页面结构改为：`aboutToAppear()` 中通过非 async 方式触发异步初始化（如调用一个独立的 `async loadData()` 方法），`build()` 方法中根据 `isLoading` 条件渲染加载指示器或数据内容
- 行为契约流水图应区分"同步初始化阶段"（设置加载状态）和"异步数据加载阶段"（数据到达后设置 `isLoading = false`）
- 补充空状态 UI 契约：`@State private isEmpty: boolean` 及对应的空状态占位渲染

---

### H6. `DeviceSelector` 设备切换的级联数据刷新路径未定义（v2 新增）

**位置**：`a_v1_design_v3.md` 模块目录及 `components/DeviceSelector.ets`（第 37 行）、设计决策 5（第 466–473 行）

**问题描述**：
设计引入了 `DeviceSelector` 组件用于多设备场景，且 `SensorService`、`DiseaseService`、`AdvisoryService`、`CommandService` 均以 `device_id` 作为查询参数。但当用户在 `DeviceSelector` 中切换设备时，设计**未定义**：
- 哪些页面需要级联刷新数据（不同页面依赖的设备相关服务不同）
- 级联刷新的触发机制（`DeviceSelector` 如何通知页面重新调用多个 Service）
- 切换设备时，`PollingManager` 中正在运行的轮询（基于旧 `device_id`）如何处理——是停止重启还是继续使用旧参数
- 跨页面共享的设备 ID（通过 `router` 参数传递）在页面 A 更改设备选择后，页面 B 如何感知变更

**严重程度**：高 — 多设备场景的核心交互路径缺失

**改进建议**：
- 在 `DeviceSelector` 的核心抽象中补充 `@Link selectedDeviceId: string` 双向绑定，以及 `onDeviceChange?: (newDeviceId: string) => void` 回调契约
- 行为契约中应新增"设备切换"场景，描述：页面层的 `onDeviceChange` 回调 → 重新调用所有依赖 `device_id` 的 Service → `PollingManager` 停止旧 key 的轮询并用新 `device_id` 重启 → 更新 `@State` 触发 UI 刷新
- 关于跨页面设备 ID 同步：在设计决策 5 中补充约定——设备 ID 变更后，通过 `router.replaceUrl` 的 `params` 参数携带新 device_id，各页面在 `aboutToAppear` 中从 `router.getParams()` 获取最新 device_id

---

## 中严重度问题

### M1. 轮询告警状态 → UI 渲染的传播路径未定义（v2 修订建议）

**位置**：`a_v1_design_v3.md` 场景 A（第 316–317 行）

**问题描述**：
场景 A 描述 `PollingManager` 的回调中调用 `AdvisoryService.getAdvisory()` → "检测新告警" → "如有重度告警 → AlarmBanner 显示"。但告警检测结果如何从 `setInterval` 回调传递到 `IndexPage.ets` 的 `@State` 变量，设计**未描述**。

**v2 关键补充**（来自质询 CH4）：`PollingManager` 是服务层模块级单例，其 `start()` 接收的回调函数存储在内部注册表中由 `setInterval` 触发。存在以下隐患：
1. 回调中 `this` 的指向依赖箭头函数捕获页面闭包，设计未约定回调必须使用箭头函数
2. `PollingManager.start()` 的方法签名中未定义 `fn` 参数的类型签名
3. 若页面被销毁后 `PollingManager` 未及时 `stop()`，回调继续执行时将写入已销毁页面的 `@State`，存在内存安全和竞争风险

**严重程度**：中 — 实现者需自行推断

**改进建议**（v2 修订）：
- 在 `PollingManager` 的核心抽象中定义回调类型签名：`type PollingCallback = () => Promise<void>`，文档中明确标注回调必须为箭头函数，捕获词法 `this`
- 在 `IndexPage` 核心抽象中补充：`@State private alarmMessage: string | null` 和 `@State private alarmSeverity: 'mild' | 'moderate' | 'severe' | null`
- 在场景 A 的行为契约中补充具体代码流程
- 补充 `PollingManager.stop(key)` 的 Must-Invoke 契约：页面 `aboutToDisappear` 中必须调用 `stop()` 对应 key
- 在 `PollingManager` 内部增加防御逻辑：每个 tick 中通过 try-catch 包裹回调执行，捕获异常以避免轮询意外终止

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
- "本地缓存的设备状态"未定义在哪里维护
- 若 `DeviceService.getDeviceList()` 每次请求最新状态，则获取后才能判断"离线"→"拒绝"，与"前置检查"的优化目的矛盾
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
需求明确要求"日志：`hilog`（来自 `@kit.PerformanceAnalysisKit`）"，但当前设计文档 **全文未提及** `hilog` 的使用策略。

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
设计在模块目录中标注 `constants.ets` 包含"命令枚举"，需求 §4.7 明确列出 8 条命令，但设计中未给出具体的 `enum` 或 `type` 定义。

**严重程度**：低

**改进建议**：
```
export enum Command { LED_ON = 'led ON', LED_OFF = 'led OFF', BEEP_ON = 'beep ON', BEEP_OFF = 'beep OFF', SPRAY_ON = 'spray ON', SPRAY_OFF = 'spray OFF', IRRIG_ON = 'irrig ON', IRRIG_OFF = 'irrig OFF' }
```

---

### L2. 循环渲染 `ForEach` 模式未在设计中引用

**位置**：`a_v1_design_v3.md` 各处

**问题描述**：
需求在参考项目约定（§6.9）中明确"循环渲染：`ForEach(arr, (item) => {...})`"，但设计文档中未显式引用 `ForEach`。

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
| `GET /image/{image_id}` | `ImageService.getImage()` | ⚠️ | 需改为 `getImagePixelMap()` 路径（见 H1 + H4） |

---

## 总结

设计方案的**架构正确性**和**模块划分合理性**值得肯定，三层分离、`PollingManager`、`HttpClient` 门面等抽象决策均可落地。

v2 修订后，核心可落地的障碍扩展到 **6 个高严重度问题**：
1. **H1 + H4 联动**：图片展示必须走 PixelMap 解码路线，`api.ets` 必须支持 `ArrayBuffer` 响应
2. **H2**：`ChartView` 在 ArkUI 中缺少内置图表组件，需自行实现 Canvas 绘制
3. **H3**：`multipart/form-data` 上传需要明确 `MultiFormData` 的 ArkTS 实现路径
4. **H5**：所有页面必须处理 `aboutToAppear` 同步约束和加载空白状态
5. **H6**：`DeviceSelector` 设备切换需要完整的级联刷新契约

这四个框架能力缺口（H1+H4+H2+H3）和两个架构设计缺口（H5+H6）需在下一版本设计文档中补充完整。

---

## 修订说明（v2 审查报告修订）

### 针对质询 CH1 的修订

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| `aboutToAppear` 同步约束导致所有页面首次加载存在未定义的空白状态 | **接受** | 新增高严重度问题 H5，定位设计文档所有场景契约中 `aboutToAppear` 的异步编排问题，给出加载状态管理建议 |

### 针对质询 CH2 的修订

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| 设备切换的级联数据刷新路径缺失 | **接受** | 新增高严重度问题 H6，定义了 `DeviceSelector.onDeviceChange` 回调契约、`PollingManager` 轮询重启策略、跨页面 deviceId 同步约定 |

### 针对质询 CH3 的修订

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| H1 方案 A 忽略 ArkUI Image 组件不支持自定义请求头的约束，认证不可行 | **接受** | 修订 H1 的改进建议，删除方案 A，仅保留方案 B（PixelMap 解码路线），补充 `ImageService.getImagePixelMap()` 的完整调用链和 `DiseaseRecord` 中 `image_path` 字段的保留策略 |

### 针对质询 CH4 的修订

| 质询内容 | 判定 | 处理 |
|---------|------|------|
| `PollingManager` 回调函数 `this` 上下文依赖未约定，存在已销毁页面状态写入风险 | **接受** | 修订 M1 的改进建议，补充回调类型签名 `PollingCallback`、箭头函数契约、`stop()` Must-Invoke 约定、内部防御性 try-catch |

---

```
DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\b_v1_diag_v2.md
```
