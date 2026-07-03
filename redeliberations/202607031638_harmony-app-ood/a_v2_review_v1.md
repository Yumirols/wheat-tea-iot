# OOD 设计方案审查报告（v4）

## 审查结果

APPROVED

## 逐维度审查

### 1. 类型系统可行性

**[通过]** 全量模型类型选择与 ArkTS 类型系统能力匹配

- **数据模型使用 `interface`**：ArkTS 的 `interface` 天然匹配 `JSON.parse()` 反序列化场景，运行时零开销，编译期提供类型检查 — 与参考项目 `DisplayPage.ets` 中 `interface LightCommandBody`、`interface FengCommandBody` 的模式一致
- **泛型使用**：`HttpClient.get<T>()` / `post<T>()`、`CacheEntry<T>`、`ApiResponse<T>`、`PaginatedData<T>` — ArkTS 支持泛型函数和泛型接口，均在语言能力范围内
- **`NetworkResult` 联合类型**：拆分为 `TextResult` / `BinaryResult` — ArkTS 的 `type` 别名 + union 是标准特性，可行
- **`ChartRendererAPI` 接口 + `LineChartRenderer` 实现**：ArkTS 支持 `interface` 与 `implements` 关键字，参考项目虽未使用此模式，但该特性在 ArkTS 语言规范中受支持
- **模块级单例**：`HttpClient`、`PollingManager`、`CacheManager` 采用模块级 `export const` 天然单例 — ArkTS 模块导入/导出机制原生支持，无需类构造

**[轻微]** `CacheManager` 的模块级单例形态下，多个 Service 共享同一份缓存键空间，若不同 Service 的缓存键命名冲突，将导致数据交叉污染。建议在设计中约定缓存键命名规范（如 `"sensor_latest_{deviceId}"` 前缀模式），或者在 `CacheManager` 接口设计中明确命名空间的策略。

**[轻微]** 命令枚举的形态选择：`constants.ets` 定义为联合类型（`'led ON' | 'led OFF' | ...`）而非枚举。ArkTS 支持 `enum` 和 `type union` 两种方式。当前选择联合类型在编译期提供了类型安全，运行时开销更低，但丧失了枚举的反射能力。对于当前规模的 V1.0 需求可行，若后续需要基于命令类型做动态分发或配置化，建议迁移为枚举。

### 2. 标准库与生态覆盖

**[通过]** 所有设计能力均在 `@ohos.net.http` / `@kit.ArkUI` 等标准库覆盖范围内

- **`api.ets` 中的 `@ohos.net.http` 生命周期管理**：`createHttp()`、`destroy()`、`request()`、`expectDataType: ARRAY_BUFFER` — 均为标准 API，可行
- **`buildFormData()` / `requestMultipart()`**：`http.createMultipartFormData().addPart()` 在 `@ohos.net.http` 中可用，参考项目虽未使用但标准库文档支持
- **`Image` 组件 URL 加载**：ArkUI `<Image src={url}>` 原生支持 HTTP/HTTPS URL 加载，与 `ImageViewer` 的 URL 路径方案一致
- **Canvas 图表渲染**：ArkUI 提供 `<Canvas>` 组件 + `CanvasRenderingContext2D`，`LineChartRenderer` 基于此实现折线图绘制可行。`ChartRendererAPI` 接口的定义将绘制逻辑与组件解耦，策略模式在 ArkTS 中可行
- **`promptAction.showToast()`**：参考项目 `DisplayPage.ets` 广泛使用 (`showToast({ message: '...', duration })`)，与设计中的用户反馈策略一致
- **`@ohos.data.preferences`**：参考项目 `landing.ets` 中使用，设计未提及但无遗漏
- **`router.pushUrl()` / `router.replaceUrl()`**：参考项目 `landing.ets` 使用 `router.replaceUrl({ url: 'pages/DisplayPage' })`，设计与之一致。场景 E 中 `pushUrl` 不触发 `aboutToDisappear` 的行为与 ArkUI 框架规范一致

**[轻微]** `ArrayBuffer` → `PixelMap` 解码链（备用路径）依赖 `@ohos.multimedia.image` 的 `createImageSource()` 和 `createPixelMap()`。这是标准 API，但需确认 `ImageSource` 在 `ARRAY_BUFFER` 输入下的兼容性。当前设计将其标记为备用路径，不对 V1.0 核心功能构成风险。

### 3. 语言特性可行性

**[通过]** 错误处理、并发设计、资源管理方案与 ArkTS/ArkUI 框架约束一致

- **错误处理策略**：分层捕获（`api.ets` 网络层 → `HttpClient` 重试层 → `HttpClient` 错误码映射层 → Service 层 → Page 层）使用 `try-catch` + `async/await`，与 ArkTS 错误处理模型完全兼容
- **`aboutToAppear` 同步约束处理**：设计采用同步触发 + `Promise.catch()` 模式：
  ```ets
  aboutToAppear() {
    this.isLoading = true
    this.loadData().catch((err: Error) => { ... })
  }
  ```
  参考项目 `DisplayPage.ets` 同样在同步 `aboutToAppear()` 中调用 `this.initData()` 触发异步流。设计模式与参考项目一致且更规范
- **并发模型**：ArKTX 运行在单 UI 线程，网络请求通过 `async/await` 非阻塞。`PollingManager` 的递归 `setTimeout` 串行模式消除与 `setInterval` 的竞争 — 该治理策略正确
- **轮询生命周期**：`EntryAbility.onBackground()` / `onForeground()` 统一暂停/恢复轮询。参考项目 `EntryAbility.ets` 具备 `onForeground()` / `onBackground()` 生命周期钩子（当前为空实现），设计在此基础上的扩展可行
- **模块/包结构**：`pages/` + `components/` + `services/` + `common/` 四层结构符合 ArkTS 项目组织惯例

**[通过]** `PollingManager` 的多 key 共存策略与 `pushUrl` 不销毁页面的行为一致，参考项目 `landing.ets` 使用 `router.replaceUrl` 跳转，设计中两种场景（`pushUrl` / `replaceUrl`）的轮询行为区分正确

**[轻微]** `PollingManager` 使用递归 `setTimeout` 串行调度时，若单个 tick 执行时间超过轮询间隔（如重试导致单 tick 耗时 >10s），实际轮询频率会低于配置间隔。这是串行模式的固有特性（有背压），设计应在 PollingManager 的职责描述中注明此行为预期，以免调用方误以为严格准时执行。

### 4. 设计一致性

**[通过]** 各模块职责清晰、协作关系完整、依赖方向无循环

- **职责边界**：`common/api.ets`（原始传输层）↔ `services/HttpClient.ets`（业务门面层）的职责划分表清晰，且包含与现有 `api.ets` 不一致时的迁移策略（增量剥离）。这一层分离使得单元测试时可独立验证 `HttpClient` 业务逻辑（mock `api.ets` 层）
- **协作闭环**：场景 A~F 覆盖了首页加载与轮询、设备控制乐观回滚、分页浏览、仪表盘刷新、页面切换生命周期管理、设备切换级联刷新 — 六大关键交互路径形成完整闭环
- **依赖方向**：
  ```
  pages/ ──→ services/ ──→ common/
    │                        ↑
    └──────── components/ ───┘
  ```
  组件仅依赖 `common/models.ets` 类型引用，无循环依赖
- **数据模型覆盖**：模型接口与 API 文档的响应结构对齐 — `DeviceInfo`（与 `/device/list` 响应一致）、`SensorSnapshot`（与 `/sensor/latest` 一致，含 `alarm_flag`）、`DiseaseRecord`（与 `/disease/list` 一致，含 `image_path`）等

**[轻微]** `DiseaseRecord` 模型缺少 `linkage_detail` 字段（API 响应 `linkage_detail` 返回环境联动分析文本）。虽然核心功能不依赖该字段，但 `AdvisoryPage` 的决策建议展示可能需要此数据。建议在 `DiseaseRecord` 模型中补充该字段。

**[轻微]** 场景 A 和场景 D 中均描述 `SensorService.getLatest(deviceId)` 的调用，但未明确 `deviceId` 在首个设备未选择时的默认值（API 支持不传 `device_id` 返回所有设备最新快照列表）。建议在 `SensorService.getLatest()` 的方法描述中注明 `deviceId` 为可选参数的行为。

### 5. 设计质量

**[通过]** 职责划分遵循 SRP、抽象层次恰当、便于后续实现和测试

- **SRP 评估**：各 Service 按业务域划分（Sensor / Disease / Command / Advisory / Device / Image），职责单一。各组件职责明确不重叠
- **抽象层次适当**：UI 层、业务服务层、传输层三个抽象层次清晰。`ChartRendererAPI` 接口 + 策略模式避免了组件内部的条件分支膨胀，不过度设计
- **可测试性**：`HttpClient` 依赖于可 mock 的 `api.ets` 层；Service 依赖于可 mock 的 `HttpClient`（通过模块级导出可在测试中替换）；页面组件通过 `@Prop` / `@Link` 接收数据，可在测试中直接注入测试数据
- **弱网韧性设计**：`RetryPolicy` + `CacheManager` + `connectivityStatus` + `PollingManager` 串行调度四者形成完整的弱网应对方案，结构清晰
- **乐观 UI 回滚**：`@State previousState` 保存 + 失败回滚 + `DeviceService.refreshDevices()` 缓存更新的设计覆盖了 H8 要求的设备状态漂移场景

**[轻微]** `PollingCallback` 类型签名（`() => Promise<void>`）在修订说明中已声明定义，且通过 `PollingManager.start(key, fn, interval)` 的接口签名隐式约束。但未在 `common/models.ets` 或 `PollingManager` 核心抽象中显式导出为独立类型定义。建议补充显式的 `type PollingCallback = () => Promise<void>` 导出，以避免后续实现时类型定义分散。

**[轻微]** `CommandService` 在失败路径中直接调用 `DeviceService.refreshDevices()` 来实现缓存失效信号。这是一种 ad-hoc 的硬引用方式。对于 V1.0 规模的单一 Service 间通信场景可行（无循环调用风险），但如果后续 Service 间通信关系增多，建议采用事件分发机制（如发布-订阅模式）解耦。

## 修改要求（REJECTED 时存在）

无。设计通过审查。

## 其他说明

1. **`image_path` 直接 URL 加载的前提条件**：设计假设后端服务能够通过 HTTP GET `baseURL + "/images/2026/07/03/img_xxx.jpg"` 返回图片二进制流。API 文档的 `GET /image/{image_id}` 端点仅说明了按 image_id 查询的路径。两者路径格式不同（`/images/` vs `/image/`）。若后端未配置 `/images/` 路径的静态文件服务或路由，该假设不成立。设计已包含备用路径方案（image_id → ArrayBuffer → PixelMap），建议在实现阶段与后端团队确认 `/images/` URL 的可访问性，若否决则启用备用路径。

2. **与参考项目代码风格的一致性**：审查确认设计与参考项目在以下方面保持一致：
   - 组件装饰器使用（`@Entry` + `@Component` + `struct`）
   - 状态装饰器使用（`@State`、`@Link`、`@Prop`）
   - 异步请求模式（`async/await` + `try-catch`）
   - 用户反馈方式（`promptAction.showToast()`）
   - 页面声明式 UI 布局（`Column`、`Row`、`Button`、`Text` 等组件）
   - 参考项目使用的 `implements` 接口模式与设计中的 `ChartRendererAPI` 一致
