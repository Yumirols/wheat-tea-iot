# 农眼卫士 FarmEye Guard v1.0 — 鸿蒙移动应用 OOD 设计方案（v8）

## 概述

鸿蒙 App 作为"端-云-台"三层架构中的表现层，承担农户移动端监控与远程控制职责。设计核心目标是在 ArkTS + ArkUI 的声明式框架约束下，实现数据展示、设备控制、告警推送、记录浏览、图像管理五大功能域的内聚组织。

**整体架构思路**：采用"服务层（Service Layer）+ 页面层（View Layer）+ 公共层（Common Layer）"三层次架构：

- **服务层**将 HTTP API 交互封装为具有明确职责的 Service 类，页面通过 Service 获取数据，不直接操作底层网络模块。
- **页面层**遵循 ArkUI 的 `Navigation` 导航体系，`Index` 作为主入口，其它子页面作为 `NavDestination` 组件加载，内部按职责拆分为子组件。
- **公共层**承载数据模型定义（`interface`）、HTTP 与上传原始封装、共享常量、工具函数、弱网韧性基础设施，被所有页面和服务引用。

**依赖方向**：页面层 → 服务层 → 公共层。页面层仅依赖服务层的接口抽象，不依赖实现细节；服务层依赖公共层的数据模型定义、HTTP/上传原始封装和韧性基础设施。

---

## 模块划分

### 模块边界

```
harmony-app/
├── AppScope/                      # 应用全局配置与资源
│   ├── app.json5                  # 应用级配置（bundleName、版本、图标、标签）
│   └── resources/                 # 应用级公共资源
├── entry/                         # 主 Entry 模块
│   ├── src/main/
│   │   ├── module.json5           # 模块级配置（Ability 声明、权限 INTERNET 等）
│   │   ├── resources/             # 模块级资源（string/color/float、深色模式、图片）
│   │   └── ets/                   # ArkTS 源码目录
│   │       ├── entryability/
│   │       │   └── EntryAbility.ets          # Ability 生命周期管理，加载首页；onBackground 统一暂停轮询
│   │       ├── entrybackupability/
│   │       │   └── EntryBackupAbility.ets    # 数据备份与恢复 Ability（模板自动生成）
│   │       ├── pages/                        # 视图层：声明式页面组件
│   │       │   ├── Index.ets                 # 首页入口（@Entry）：承载 Navigation 容器与 NavPathStack 实例
│   │       │   ├── DashboardPage.ets         # 仪表盘（@Component + NavDestination）：传感器卡片 + 实时曲线
│   │       │   ├── DiseaseRecordsPage.ets    # 病虫害记录（@Component + NavDestination）：列表 + 筛选 + 详情弹窗
│   │       │   ├── ControlPage.ets           # 远程控制（@Component + NavDestination）：设备执行机构操作面板
│   │       │   └── AdvisoryPage.ets          # 防治建议（@Component + NavDestination）：AI 决策建议展示
│   │       ├── components/                   # 12 个可复用 UI 组件
│   │       │   ├── SensorCard.ets            # 传感器参数卡片（温度/湿度/光照/CO2/NPK/距离），含数据时间戳与告警标签
│   │       │   ├── ChartView.ets             # 历史趋势图表组件，通过 chartType 属性切换 LineChart 或 BarChart
│   │       │   ├── LineChartRenderer.ets     # Canvas 折线图渲染器（v1.0 最小可用：单 Y 轴单折线，无触摸交互）
│   │       │   ├── BarChartRenderer.ets      # Canvas 柱状图渲染器（v1.0 预留架构，非必须）
│   │       │   ├── DeviceSelector.ets        # 设备选择器：与 AppStorage.selectedDeviceId 双向绑定
│   │       │   ├── AlarmBanner.ets           # 告警横幅（基于 SensorService alarm_flag 位掩码解析，三色 severity）
│   │       │   ├── ControlButton.ets         # 控制按钮（ON/OFF 双态，包含 Pending 状态与乐观 UI 回滚）
│   │       │   ├── SeverityBadge.ets         # 严重度徽标（Mild/Moderate/Severe 三色）
│   │       │   ├── PaginatedList.ets         # 分页列表容器（当前硬编码为 DiseaseRecord 类型）
│   │       │   ├── ImageViewer.ets           # 病虫害图片查看器（URL 主路径 + ArrayBuffer 降级）
│   │       │   ├── ConnectivityIndicator.ets # 连接状态指示器（页面顶部 4px 细条，绿/黄/红三色）
│   │       │   └── LoadingState.ets          # 统一加载状态占位（三态：loading 旋转环 / error 错误重试 / empty 空态）
│   │       ├── services/                     # 服务层：API 交互封装
│   │       │   ├── HttpClient.ets            # HTTP 客户端——业务级门面（baseURL、API Key、JSON 解析、错误码映射、指数退避重试）
│   │       │   ├── SensorService.ets         # 传感器数据查询（latest / history / daily）：已区分有参/无参接口签名，含内存缓存
│   │       │   ├── DiseaseService.ets        # 病虫害记录查询（list / stats / heatmap）
│   │       │   ├── CommandService.ets        # 设备控制命令下发（send / logs）：失败路径发送缓存失效信号
│   │       │   ├── AdvisoryService.ets       # 防治建议拉取
│   │       │   ├── DeviceService.ets         # 设备列表与在线状态：含模块级缓存（getCachedDevices / refreshDevices）
│   │       │   ├── ImageService.ets          # 图像上传与获取（通过 api.uploadFile + HttpClient.getRaw）
│   │       │   └── PollingManager.ets        # 轮询调度器（统一管理各模块轮询生命周期，串行/跳略模式）
│   │       └── common/
│   │           ├── models.ets                # 数据模型：18+ 个响应结构、业务实体 interface 定义
│   │           ├── api.ets                   # HTTP 原始封装——@ohos.net.http 生命周期管理 + requestRaw 二进制 + @ohos.request 上传
│   │           ├── constants.ets             # 全局常量（API、轮询间隔、缓存 TTL/前缀、命令枚举、错误码、报警位掩码、重试设置）
│   │           ├── RetryPolicy.ets           # 默认重试策略常量（DEFAULT_RETRY 基于 RetryPolicyConfig 类型导出）
│   │           ├── CacheManager.ets          # 通用内存缓存管理器（CacheEntry<T>，TTL 控制，过期失效）
│   │           └── utils.ets                 # 工具函数（formatTimestamp、parseAlarmFlag 位掩码解析、sleep、buildQueryString、isNetworkError）
```

### 模块职责

| 模块 | 职责 | 依赖 |
|------|------|------|
| `pages/` | 页面编排、UI 状态管理（含 isLoading/errorMessage/connectivityStatus）、用户交互事件响应、生命周期守护 | `services/`, `components/`, `common/` |
| `components/` | 可复用 UI 部件的渲染和局部状态管理 | 仅 `common/models.ets`（类型引用） |
| `services/` | 封装业务 HTTP 请求逻辑、数据响应解析、业务预处理、本地缓存管理 | `common/`（特别是 `common/api.ets` 和 `models.ets`） |
| `common/` | 数据模型定义、HTTP 与上传原始封装、弱网韧性基础设施（RetryPolicy、CacheManager）、工具函数 | 无内部依赖 |

### 模块间依赖方向

```
pages/ ──→ services/ ──→ common/
  │                        ↑
  └──────── components/ ───┘
```

- `pages/` 依赖 `services/` 获取数据，依赖 `components/` 渲染子 UI。
- `services/` 依赖 `common/` 进行 HTTP 通信和类型引用。
- `components/` 仅引用 `common/models.ets` 中的类型定义。

### `common/api.ets` 与 `services/HttpClient.ets` 的职责分工

`api.ets` 和 `HttpClient.ets` 处于不同的抽象层次，形成"原始传输层 → 业务门面层"的两层 HTTP 封装结构：

| 层次 | 文件 | 职责范围 | 使用者 |
|------|------|---------|--------|
| **原始传输层** | `common/api.ets` | 封装 `@ohos.net.http` 的生命周期管理（`createHttp()`/`destroy()`）、请求超时设置、基础请求头兜底填充、网络异常原生错误捕获、HTTP 状态码判断；`requestRaw()` 返回 `ArrayBuffer`；`uploadFile()` 封装系统原生 `@ohos.request` 上传能力。返回 `TextResult` / `BinaryResult` / `ApiResponse<ImageUploadResult>` 联合类型 | 仅供 `HttpClient` 和 `ImageService` 调用 |
| **业务门面层** | `services/HttpClient.ets` | 在 `api.ets` 基础上叠加业务语义：注入 `X-API-Key` 认证头、拼接 API 基础路径（`/api/v1`）、JSON 序列化/反序列化、通用业务错误码（1001–5000）映射、统一的 `ApiResponse<T>` 解析、指数退避重试。提供 `get<T>()` / `post<T>()` 泛型方法和 `getRaw()` 二进制获取方法 | 供所有 `*Service` 调用 |

**关于现有 `common/api.ets` 的实况说明**：`api.ets` 当前在 `request()` / `requestRaw()` 中引入了 `HEADER_API_KEY` 常量和 `DEFAULT_TIMEOUT_MS` 常量作为请求头/超时设置的默认值，存在轻微的业务语义侵入。当前 v1.0 阶段此耦合可接受（超时和 API Key 头字段名是基础设施级常量，非纯业务逻辑）；后续架构升级时可通过配置参数化完全剥离。

### `common/RetryPolicy.ets` 和 `common/CacheManager.ets` 的定位

`RetryPolicy` 和 `CacheManager` 位于 `common/` 层，作为弱网韧性基础设施被 `HttpClient` 和各 Service 使用：

- **RetryPolicy** 导出默认重试策略常量 `DEFAULT_RETRY: RetryPolicyConfig`，被 `HttpClient` 在 `get<T>()` / `post<T>()` 内部用于判断是否重试、退避间隔等。非幂等 POST（命令下发）不做重试。
- **CacheManager** 提供泛型内存缓存能力，被各 Service（特别是 `SensorService`、`DeviceService`）用于缓存最后一次成功获取的数据，网络失败时返回缓存值。

---

## 核心抽象

### 1. `api.ets` — HTTP 原始传输与上传封装

**角色**：`@ohos.net.http` 和 `@ohos.request` 的轻量适配器。

**职责**：
- 管理 `http.createHttp()` 和 `destroy()` 的完整生命周期（每次请求创建新实例，请求完成后销毁）
- 提供原始 `request(url, options)` 函数，接收 URL、请求方法和头部、请求体，返回 `TextResult`
- `requestRaw(url, options)` 方法，内部设置 `expectDataType: http.HttpDataType.ARRAY_BUFFER`，返回 `BinaryResult`
- `uploadFile(context, url, filePath, header, data)` 方法，封装系统原生 `@ohos.request.uploadFile()` API，实现 `multipart/form-data` 的后台多线程图片上传任务，返回 Promise 包装的 `ApiResponse<ImageUploadResult>`
- 设置全局超时（10s，从常量导入 `DEFAULT_TIMEOUT_MS`）
- 捕获网络层异常（无网络、超时、DNS 解析失败）并转换为结构化失败信号
- 不解析 JSON（除 `uploadFile`）、不拼接 `/api/v1` 前缀、不处理业务错误码

**协作方式**：被 `HttpClient`（普通 JSON/二进制请求）和 `ImageService`（文件上传）调用。

**类型形态选择理由**：选择为纯函数导出（而非类），因为传输层是一组无状态的工具函数，不需要持有内部状态，ArkTS 的模块级函数导出即可满足。

### 2. `HttpClient` — HTTP 业务门面（含重试逻辑）

**角色**：服务层 HTTP 通信的统一入口单例。

**职责**：
- 持有 API 基础 URL（通过常量模块获取）和 `X-API-Key` 认证令牌（向外提供获取 API Key 和 Base URL 的只读属性，供文件上传等模块直接引用）
- 在 `api.ets` 返回的原始响应上叠加业务处理：JSON 解析 → 检查 `code` 字段 → 映射为 `ApiResponse<T>`
- 提供 `get<T>(path, params)` / `post<T>(path, body)` 泛型方法，返回已解析的 `ApiResponse<T>` 或抛出业务异常
- 提供 `getRaw(path, params?)` 方法，返回 `ArrayBuffer`，专用于二进制响应（如图片）获取，绕过 JSON 解析路径
- **生产环境免签图片访问策略**：由于服务端的图片静态目录（`/images/...`）在生产环境下豁免了 `X-API-Key` 鉴权，因此图片加载直接使用原生 `<Image>` 传入 `baseURL + image_path` 形式 of HTTP URL 即可，无需携带鉴权 Header，从而完美复用 ArkUI 原生的图片高速缓存与后台解码能力。仅在渲染失败的降级流中通过 `getRaw()` 管道获取
- 实现指数退避重试：对网络异常（catch 捕获）和 HTTP 408/429/502/503/504 进行重试，baseDelayMs=1000, maxDelayMs=10000, maxRetries=3；非幂等请求（POST 命令下发）不做重试

**协作方式**：所有 `*Service` 通过 `HttpClient` 发起 HTTP 请求，不直接调用 `api.ets`。JSON API 场景使用 `get<T>()` / `post<T>()` 泛型方法；`ImageService` 获取图片二进制降级流时使用 `getRaw(path)` 方法。

**类型形态选择理由**：选择为模块级变量实现的单例，因为 API Key 和基础 URL 全局唯一且配置一次后不再变化，模块级 `export const` 天然实现单例语义，无需类构造。

### 3. `SensorService` — 传感器数据获取（含本地缓存）

**角色**：环境监测数据的统一查询入口。

**职责**：
- 封装最新快照、历史数据、日聚合三种查询的 HTTP 请求逻辑和响应解析
- 提供以下获取方法：
  - `getLatest(deviceId: string): Promise<SensorSnapshot>`：查询特定设备最新一条快照数据，内部自动从 API 返回的 `records` 数组中提取并返回首项元素。
  - `getAllLatest(): Promise<SensorSnapshot[]>`：查询所有设备的最新快照数据列表（对应后端 API 省略 `device_id` 参数的行为）。
  - `getHistory(deviceId, start, end, page?, pageSize?)`：查询历史传感器数据。
  - `getDaily(deviceId, start, end, page?, pageSize?)`：查询日聚合传感器数据。
- 返回经过类型断言后的结构化数据（而非裸 JSON）
- 不持有 UI 状态，仅做数据获取和转换
- 实现轻量级内存缓存：成功获取数据后存入 `CacheManager`，设默认 TTL 30s；网络失败时优先返回缓存数据，调用方可根据数据时间戳展示"数据可能非最新"提示

**协作方式**：被 `Index`（最新快照卡片 + 10s 传感器轮询 + 告警位掩码轮询）、`DashboardPage`（历史趋势图表）调用。

### 4. `DiseaseService` — 病虫害记录服务

**角色**：病虫害检测记录的数据访问层。

**职责**：
- 封装记录列表（`getList(filters)`）、统计（`getStats()`）、热力图（`getHeatmap()`）三类查询
- 将筛选参数（设备 ID、作物类型、严重度、分页）映射为 URL query 参数
- 返回分页封装的数据结构 `PaginatedData<DiseaseRecord>`
- `getList()` 接受 `DiseaseListFilters` 接口（含 `device_id`、`crop_type`、`severity`、`page`、`page_size`）

**协作方式**：被 `DiseaseRecordsPage` 调用，通过 `PaginatedList` 组件支持分页加载。

### 5. `CommandService` — 设备控制命令下发

**角色**：远程设备控制的操作入口。

**职责**：
- 封装 `POST /command/send` 的下发逻辑
- 封装 `GET /command/logs` 的查询逻辑
- 在下发前通过 `DeviceService` 前置检查设备在线状态（若本地缓存的设备状态为离线则提前拒绝，避免无效请求）
- 下发失败路径（`code=1003` 或网络异常）：发送缓存失效信号给 `DeviceService`，触发缓存刷新，避免后续请求基于过期的在线状态

**协作方式**：被 `ControlPage` 调用。调用前需通过 `DeviceService.getCachedDevices()` 检查设备在线状态。`ControlPage` 自身也会进行前置在线状态检查（双重校验）。

**已知耦合说明**：`CommandService` 在失败路径中直接调用 `DeviceService.refreshDevices()`——这是跨 Service 的硬编码引用。当前 v1.0 阶段此耦合可接受（两个 Service 同属一个模块层，且设备状态失效后立即刷新是强时序相关性操作）。后续架构升级时可通过事件机制解耦（如发布 Channel 事件让 DeviceService 自行订阅）。

### 6. `AdvisoryService` — 防治建议服务

**角色**：AI 决策建议的拉取入口。

**职责**：
- 封装 `GET /advisory` 的请求和响应解析
- 解析建议详情（`AdvisoryDetection`、`AdvisoryEnv`、`AdvisoryLinkage`、`AdvisoryAction` 嵌套结构）
- 提供按 `deviceId` + 时间窗口维度的缓存（30s TTL）

**协作方式**：被 `AdvisoryPage` 调用，同时被该页面的 `PollingManager` 周期性轮询以刷新最新建议数据。

### 7. `DeviceService` — 设备管理服务（含模块级缓存）

**角色**：设备列表与在线状态的查询入口。

**职责**：
- 封装 `GET /device/list` 的查询
- 维护模块级缓存：模块级 `cachedDevices` 数组 + `CacheManager`，60s TTL
- 提供 `getDeviceList()` 强制远程查询、`getCachedDevices(): DeviceInfo[]` 返回缓存值（不强制刷新）、`refreshDevices(): Promise<DeviceInfo[]>` 强制刷新
- 提供设备在线状态的判断依据（返回的 `online` 布尔字段）

**协作方式**：被 `Index`（设备选择器初始化）、`ControlPage`（控制前检查在线状态）调用。`CommandService` 在失败路径中调用 `DeviceService.refreshDevices()` 更新缓存。`Index` 的告警轮询也通过 `DeviceService.getCachedDevices()` 前置判断设备的在线状态。

### 8. `ImageService` — 图像上传与获取

**角色**：病虫害图片资源的传输管理入口。

**职责**：
- 封装 `POST /image/upload` 的文件上传逻辑：接收 UI 上下文、文件沙箱路径与关联参数，读取 `HttpClient` 的 Base URL 和 API Key，组装成系统原生格式配置，并调用 `api.uploadFile()` 委托 `@ohos.request` 服务进行后台多线程上传，返回 Promise 封装的 JSON 响应。
- 封装 `GET /image/{image_id}` 的二进制流降级获取逻辑：调用 `HttpClient.getRaw(path)` 获取 `ArrayBuffer` 并返回给页面层以解码为 `PixelMap`。
- 不处理图片裁剪、压缩等非传输层职责。

**协作方式**：
- 被 `DiseaseRecordsPage`（查看病虫害记录中的图片降级流）和未来的图片上传页面调用。
- 图片上传：通过调用 `api.uploadFile()` 委托后台任务直接上传沙箱文件，避开 JSON 序列化路径。
- 图片获取（降级路径）：通过 `HttpClient.getRaw(path)` 获取 `ArrayBuffer` 并解码为 `PixelMap`，避开 JSON 序列化路径。
- **生产环境首选路径**：通过直接引用 `baseURL + image_path` 由 native `Image` 组件加载，免于手动调用 `ImageService`。

### 9. `PollingManager` — 轮询调度器

**角色**：统一管理所有轮询任务的生命周期。

**职责**：
- 维护一个轮询任务注册表，每个任务包含：轮询函数、间隔、是否活跃、运行标志位
- 提供 `start(key, fn, interval)` / `stop(key)` / `stopAll()` / `suspendAll()` / `resumeAll()` 接口
- `start(key, fn, interval)` 中 `fn` 的参数类型为 `PollingCallback`（`export type PollingCallback = () => Promise<void>`，定义于 `common/models.ets`）
- 在页面 `aboutToAppear` / `aboutToDisappear` 生命周期中控制轮询的启动与停止
- **串行模式**：使用递归 `setTimeout` 替代 `setInterval`，上一个 tick（含重试）完全结束后再调度下一个周期
- **串行定时策略与频率漂移**：每个 tick 完成后以 `setTimeout(fn, interval)` 调度下一个 tick；若某 tick 因重试耗时超过 `interval`，实际有效轮询频率 = 1/(tickDuration + interval) ≤ 1/interval，即轮询频率可能低于配置值。此行为在 IoT 弱网场景下是刻意的——避免请求堆积比维持名义频率更重要，因此视作设计特性而非缺陷
- 同一 key 不会重复注册（已存在的先清除再新建）
- 每个 tick 通过 try-catch 包裹回调执行
- 在 `EntryAbility.onBackground()` / `onForeground()` 中统一暂停和恢复所有轮询

**协作方式**：被除 `ControlPage` 外的页面用于轮询数据刷新。`PollingCallback` 回调由各页面提供，通常是调用 Service 方法并更新 `@State` 变量的闭包。

### 10. `RetryPolicy` — 重试策略定义

**角色**：弱网韧性基础设施的配置定义。

**职责**：
- 定义重试策略的配置结构：`RetryPolicyConfig`（包含 `maxRetries`, `baseDelayMs`, `maxDelayMs`, `retryOn`, `timeoutMs`）
- 导出默认重试策略常量 `DEFAULT_RETRY: RetryPolicyConfig`
- 被 `HttpClient` 用于实现指数退避重试逻辑

**类型形态选择理由**：选择为纯类型定义（interface）+ 默认值常量导出，因为重试策略是纯配置结构，无需行为逻辑。

### 11. `CacheManager` — 通用内存缓存管理器

**角色**：通用内存缓存基础设施。

**职责**：
- 提供 `CacheEntry<T>` 结构（`data: T, timestamp: number, ttl: number`）
- 提供 `set(key, data, ttl?)` / `get(key)` / `invalidate(key)` / `clear()` 接口
- 自动失效超过 TTL 的缓存项
- 被各 Service 用于缓存最后一次成功获取的数据

**类型形态选择理由**：选择为模块级管理器的单例形态，因为缓存数据需要在 Service 的多次方法调用间共享，模块级导出天然满足。

**缓存键命名约定**：为避免多 Service 使用同一 `CacheManager` 实例时的键空间冲突，约定各 Service 使用统一前缀命名空间作为缓存键前缀。代码中定义有 10 个具名前缀常量，包括 `sensor_latest_`、`sensor_all_latest`、`sensor_history_`、`sensor_daily_`、`device_list_`、`disease_list_`、`disease_stats`、`disease_heatmap`、`advisory_`、`command_logs_`。

### 12. 页面组件（`Index` / `DashboardPage` / `DiseaseRecordsPage` / `ControlPage` / `AdvisoryPage`）

**角色**：
- `Index`：ArkUI 视图层的唯一入口（`@Entry`）页面，承载 `Navigation` 容器与 `NavPathStack` 路由栈单例。
- 其它子页面（`DashboardPage` 等）：表现为非 `@Entry` 的普通 `@Component` 组件，根节点为 `NavDestination`，被 `Index` 的路由表动态加载。

**职责**：
- **全局状态绑定**：所有需要感知当前选择设备的页面均使用 `@StorageLink('selectedDeviceId') selectedDeviceId: string` 双向绑定全局存储，无需手动通过路由传参，自动实现"一处更改，全屏同步"。
- **组件销毁安全屏障**：每个页面声明私有变量 `private isDestroyed: boolean = false`，在 `aboutToDisappear()` 中将其置为 `true`。所有 `await` 异步回调执行结束后，更新任何 `@State` 状态前必须前置校验 `if (this.isDestroyed) return;`，防止已销毁组件被更新状态引起的运行时警告/崩溃。
- **本地 UI 状态管理**：声明本地 `@State` 装饰的状态（如 `isLoading`、`errorMessage`、`connectivity` 等）。
- **网络指示状态机同步**：声明页面的 `@State connectivity: ConnectivityStatus`（`'loading' | 'online' | 'offline'`）。在 loadData 的成功/失败路径中维护此状态：
  - 首次加载成功：置为 `'online'`。
  - 加载失败（含网络异常）：置为 `'offline'`。
  - **注意**：当前 `Index` 页面的 `connectivity` 状态机的具体实现在告警轮询中依赖 `DeviceService.getCachedDevices()` 判断在线状态，而非严格基于每次传感器请求的成功/失败——这是一个已知的简化行为，详见 场景 A 的实况说明。
- 在同步的 `aboutToAppear()` 中通过非 async 方式触发 `loadData()` 异步方法。
- `loadData()` 统一返回 `Promise<void>`，并在异步段完成后根据结果更新状态。
- `build()` 中根据 UI 状态条件渲染加载旋转环、错误重试页、顶部连接指示器（`ConnectivityIndicator`）以及真实数据内容。
- 在 `aboutToDisappear` 中调用 `this.isDestroyed = true` 并注销自己所注册的所有轮询任务（`PollingManager.stop()`）。
- 页面切换通过 `Index` 的 `pageStack: NavPathStack` 进行跳转管理（如 `this.pageStack.pushPathByName(name, param)`）。

**协作方式**：通过 Service 获取数据，通过子组件完成具体 UI 渲染。页面路由与参数获取基于 `NavPathStack` 路由栈。

### 13. `SensorCard` — 传感器参数卡片（含数据时间戳与告警标签）

**角色**：环境参数的单值展示组件。

**职责**：
- 接收参数名、数值、单位、数据时间戳、告警标签数组作为 `@Prop` 属性
- 按数值范围和告警标签切换背景高亮色
- 展示数值的单位后缀
- 展示数据来源时间戳（帮助用户判断数据新鲜度）
- 支持 `alarmLabels` 数组渲染告警标签徽标

**协作方式**：被 `DashboardPage` 和 `Index` 复用。通过 `@Prop` 接收父组件的参数值。

### 14. `ChartView` — 历史趋势图表

**角色**：传感器历史数据的可视化组件。

**职责**：
- 通过 `@Prop chartType: 'line' | 'bar'` 切换具体渲染器组件
- `chartType === 'line'` 时委托 `LineChartRenderer` 渲染，`'bar'` 时委托 `BarChartRenderer` 渲染
- 接收数据点数组作为输入
- **v1.0 限制**：Canvas 不支持响应式重绘。父组件切换设备时通过 `<ChartView key={'chart-' + chartRebuildKey} ... />` 强制重建实例触发重绘。
- 不依赖独立的 `ChartRendererAPI` 接口（v1.0 采用直接的组件切换模式，未抽象统一渲染器接口）

**协作方式**：被 `DashboardPage` 调用，数据源来自 `SensorService.getHistory()`。v1.0 最小可用版本：仅实现 `LineChartRenderer`（单 Y 轴单折线，无触摸交互），`BarChartRenderer` 预留架构后续实现。

### 15. `ControlButton` — 双态控制按钮（含乐观 UI 回滚）

**角色**：设备 ON/OFF 控制的操作组件。

**职责**：
- 通过 `@Link isOn: boolean` 接收并同步父组件状态——点击后立即执行 `this.isOn = targetState` 实现乐观 UI 翻转，此修改直接反映到父组件的对应 `@State` 变量
- 操作前保存当前状态到 `@State private previousState: boolean`
- 乐观 UI：点击后立即切换为目标状态并显示加载态（按钮置灰，`isPending = true`）
- 显示当前状态文案（"已开启"/"已关闭"）
- 失败时回滚：恢复为 `this.previousState`，通过 `console.error` 记录错误，由父组件 `ControlPage` 负责通过 `promptAction.showToast()` 反馈给用户
- 错误反馈委托给父组件，组件自身保持纯粹的状态管理职责

**`@Link` 决策说明**：选择 `@Link` 而非 `@Prop` 的理由是——`@Prop` 在 ArkUI 中为只读属性，子组件无法对其赋值；乐观 UI 要求点击后立即翻转状态，需要子组件具备直接修改父组件状态的能力。`@Link` 通过 `$isOn` 语法传递引用，`this.isOn = targetState` 即向父组件的 `@State` 写入，语义明确。

**协作方式**：被 `ControlPage` 复用，每个实例对应一个执行机构（喷淋/灌溉/蜂鸣器/LED）。

### 16. `AlarmBanner` — 告警横幅

**角色**：页面顶部实时告警展示组件。

**职责**：
- 通过 `@Prop message: string` 接收告警消息文本
- 通过 `@Prop severity: string` 接收严重程度（当前为宽松的 `string` 类型，在渲染时与 `'mild'`、`'moderate'`、`'severe'` 进行三色匹配，不匹配时使用灰色兜底）
- 自动展示最新一条告警信息，支持滚动多行文本显示
- 用户点击横幅时触发跳转（通过 `onTap` 回调路由到 `AdvisoryPage`）
- 用户可点击关闭按钮解除当前告警展示（仅隐藏展示，不消除服务端告警记录）
- 当 `message` 为空字符串时，组件自身不渲染（通过 `width: 0, height: 0` 隐藏）

**协作方式**：被 `Index` 使用，数据源来自告警轮询回调中基于 `SensorSnapshot.alarm_flag` 位掩码解析的告警信息。

### 17. `PaginatedList` — 分页列表容器（当前非泛型）

**角色**：支持无限滚动的分页列表组件。

**职责**：
- 接收父组件提供的 `@Builder` 渲染模板（`renderItem`）作为 `@BuilderParam`
- 接收 `loadPage: (page: number) => Promise<PaginatedData<DiseaseRecord>>` 分页加载回调函数
- 管理加载更多、加载中、无更多数据三种状态
- 在滚动到底部前 5 条时自动触发下一页加载
- `aboutToAppear` 时加载第 1 页
- 失败时 `console.error` 记录，已有数据保留

**当前实现约束**：`PaginatedList` 内部所有类型（`records`、`loadPage` 返回值、`renderItem` 参数）均硬编码为 `DiseaseRecord`，不具备泛型复用能力。后续可通过 ArkTS 泛型 `@BuilderParam` 机制改造或拆分为具体类型副本来实现通用性。

**协作方式**：被 `DiseaseRecordsPage` 使用，加载函数指向 `DiseaseService.getList()`。

### 18. `ImageViewer` — 病虫害图片查看器

**角色**：病虫害记录关联图片的展示组件。

**职责**：
- **主路径（直接 URL 加载）**：`DiseaseRecord.image_path` 为服务端返回的 URL 相对路径（如 `/images/2026/07/03/img_xxx.jpg`），API 文档（§2.4.1）明确标注 `image_path` 为"公开 URL"，可通过 `baseURL + image_path` 拼接为完整 URL 供 `Image` 组件直接加载，服务端在生产部署下放行此目录，免于 Header 鉴权。
- 接收图片 URL 作为 `@Prop` 属性
- 在图片容器中使用 `<Image src={fullImageUrl}>` 渲染网络图片，ArkUI 原生支持
- 展示加载中、加载失败、空状态三种占位效果
- **降级路径**：若 `Image` 组件加载失败（`onError` 回调），采用备用路径——调用 `ImageService.getImagePixelMap(imageId)` 完成 `ArrayBuffer` → `ImageSource` → `PixelMap` 解码链，`ImageViewer` 通过 `@Prop` 接收 `PixelMap` 对象渲染
- `imageId` 从 `image_path` 的文件名部分提取（如 `/images/2026/07/03/img_20260703_061500_021.jpg` 中提取 `img_20260703_061500_021`），对应 `GET /image/{image_id}` 二进制流端点（API 文档 §2.4.2）

**协作方式**：被 `DiseaseRecordsPage` 中的记录详情弹窗调用，图片源来自 `DiseaseRecord.image_path` 拼接后的完整 URL。

### 19. `ConnectivityIndicator` — 连接状态指示器

**角色**：网络连接状态的 UI 表现组件。

**职责**：
- 接收 `@Prop status: ConnectivityStatus` 属性（类型别名为 `'loading' | 'online' | 'offline'`，定义于 `models.ets`）
- 渲染页面顶部 4px 细条（黄色/绿色/红色），直观展示连接状态
- 提供 `@Builder` 供页面直接嵌入 `build()` 布局

### 20. `LoadingState` — 统一加载状态占位

**角色**：数据加载三态（loading / error / empty）的统一占位组件。

**职责**：
- 接收 `@Prop status: 'loading' | 'error' | 'empty'` 三态枚举
- `loading` 态：渲染 `Progress` 旋转环（`ProgressType.Ring`）+ "加载中..." 文字
- `error` 态：渲染错误图标 + `errorMessage` 文本（空时降级显示"加载失败，请重试"）+ "重试"按钮
- `empty` 态：渲染空图标 + "暂无数据" 文字
- 接收可选的 `onRetry?: () => void` 回调

### 21. 数据模型接口（`common/models.ets`）

**角色**：业务数据的类型定义集合。

**核心接口一览**：

| 接口 | 描述 | 对应 API |
|------|------|---------|
| `DeviceInfo` | 设备信息（id, device_id, device_name, mac_addr, ip_addr, registered_at, last_seen, online, created_at） | `/device/list` |
| `SensorSnapshot` | 最新环境数据快照（id, device_id, mac_addr, timestamp, temperature, humidity, light, co2, soil_n/p/k, distance, rssi, ip_addr, alarm_flag, created_at） | `/sensor/latest` |
| `SensorHistory` | 历史传感器数据记录（id, device_id, timestamp, 全部环境字段, rssi, ip_addr, alarm_flag） | `/sensor/history` |
| `DailyAggregation` | 日聚合数据（id, device_id, agg_date, avg/max/min 各环境指标, record_count, created_at） | `/sensor/daily` |
| `DiseaseRecord` | 病虫害记录（id, device_id, timestamp, crop_type, disease_type, confidence, severity, severity_code, linkage_risk_level, linkage_detail, image_path, action_taken, created_at） | `/disease/list` |
| `DiseaseStats` | 多维度统计（total_detections, by_crop, by_severity, by_disease） | `/disease/stats` |
| `HeatmapPoint` | 热力图单点（device_id, disease_type, severity, timestamp, crop_type） | `/disease/heatmap` |
| `HeatmapSummary` | 热力图汇总（active_disease_types, affected_devices, total_records） | `/disease/heatmap` |
| `HeatmapData` | 热力图整体响应（heatmap_points, summary） | `/disease/heatmap` |
| `CommandRequest` | 控制命令请求结构体（device_id, command, source?, operator?） | `/command/send` 请求体 |
| `CommandResponse` | 命令下发响应（command_id, device_id, command, status） | `/command/send` 响应 |
| `CommandLog` | 控制日志记录（id, device_id, command_id, timestamp, command, source, operator, result_code, result_msg） | `/command/logs` |
| `AdvisoryDetection` | 防治建议 - 最新检测子结构（crop_type, disease_type, severity, severity_code, confidence, timestamp） | `/advisory` |
| `AdvisoryEnv` | 防治建议 - 环境子结构（temperature, humidity, light, co2） | `/advisory` |
| `AdvisoryLinkage` | 防治建议 - 环境-病虫害联动分析（risk_level, matched_conditions, recommendation） | `/advisory` |
| `AdvisoryAction` | 防治建议 - 建议动作（action, description, auto_action_triggered, auto_action） | `/advisory` |
| `Advisory` | 防治建议整体响应（latest_detection, current_env, env_disease_linkage, advisory） | `/advisory` |
| `ImageUploadResult` | 图片上传结果（image_id, image_path, file_size, uploaded_at） | `/image/upload` |
| `TextResult` | 文本响应封装（statusCode, headers, rawBody: string） | `api.ets` 内部返回给 `HttpClient` |
| `BinaryResult` | 二进制响应封装（statusCode, headers, rawBody: ArrayBuffer） | `api.ets` 内部返回给 `HttpClient` |
| `ApiResponse<T>` | 通用 API 响应外层（code, message, data） | 所有接口 |
| `Pagination` | 分页元数据（total, page, page_size） | 分页接口 |
| `PaginatedData<T>` | 分页数据结构（pagination, records） | 分页接口 |
| `RetryPolicyConfig` | 重试策略配置（maxRetries, baseDelayMs, maxDelayMs, retryOn, timeoutMs） | — |
| `CacheEntry<T>` | 缓存条目（data, timestamp, ttl） | — |
| `PollingCallback` | 轮询回调类型（`type PollingCallback = () => Promise<void>`） | — |
| `ConnectivityStatus` | 页面连接状态类型（`'loading' | 'online' | 'offline'`） | — |

`NetworkResult` 拆分为 `TextResult` 和 `BinaryResult` 联合类型，`api.ets` 的 `request()` 返回 `TextResult`，`requestRaw()` 返回 `BinaryResult`。

---

## 关键行为契约

### 场景 A：首页加载 → 环境快照展示 + 传感器轮询 + 告警轮询（基于位掩码）

```
Index.aboutToAppear()  [同步初始化]
  ├─ isDestroyed = false
  └─ loadDevices() [异步]
       ├─ DeviceService.getDeviceList() → 获取设备列表 → 成功则 connectivity = 'online' → 渲染 DeviceSelector
       │    并初始化 AppStorage.selectedDeviceId（若未存储或存储值不在列表中，设置首项为默认）
       └─ catch → deviceError = 错误信息 → connectivity = 'offline'
       └─ finally → isLoadingDevices = false → startPolling()
            ├─ PollingManager.start('index_sensor', 10000)
            │    └─ 每 10s（串行 setTimeout）: fetchLatestSensor()
            │         └─ SensorService.getLatest(selectedDeviceId) → if (isDestroyed) return → 更新 latestSnapshot
            │         └─ catch → console.error（不修改 connectivity）
            └─ PollingManager.start('index_alarm', 10000)
                 └─ 每 10s: fetchAlarmStatus()
                      ├─ DeviceService.getCachedDevices(selectedDeviceId) → 前置判断在线状态 → 更新 connectivity
                      ├─ SensorService.getLatest(selectedDeviceId) → if (isDestroyed) return
                      └─ 解析 snapshot.alarm_flag 位掩码：
                           ├─ 位 0 (0x01) = 高温报警     ├─ 位 1 (0x02) = 低温报警
                           ├─ 位 2 (0x04) = 高湿报警     ├─ 位 3 (0x08) = 低湿报警
                           ├─ 位 4 (0x10) = 低光照报警   ├─ 位 5 (0x20) = 高 CO2 报警
                           ├─ 位 6 (0x40) = 低氮报警     └─ 位 7 (0x80) = 低磷报警
                      └─ 若 alarm_flag > 0 → 解析报警标签 → 设置 bannerMessage / bannerSeverity / isBannerVisible

build() 条件渲染:
  ├─ isLoadingDevices=true → LoadingState loading
  ├─ deviceError!='' → LoadingState error 含重试按钮
  ├─ devices.length===0 → LoadingState empty
  └─ 正常 → 数据内容 + ConnectivityIndicator 顶部状态条 + AlarmBanner（conditionally）
```

**实况说明**：
- 首页告警轮询使用 `SensorService.getLatest()` 获取传感器快照，然后解析其 `alarm_flag` 位掩码来判定告警类型，而非调用 `AdvisoryService`。这是 v1.0 的简化设计——后端传感器快照已包含 `alarm_flag` 字段，避免了额外的告警接口调用。
- `connectivity` 状态在 `fetchAlarmStatus()` 中基于 `DeviceService` 缓存的设备在线状态判定，而非严格基于每次传感器请求的成功/失败——这是已知的简化，在 IoT 场景下传感器数据可能因网络波动失败但设备本身仍在线。
- 设备切换（`onDeviceIdChanged` 回调）时，`Index` 重新启动全部轮询并立即执行一次传感器和告警数据获取。

### 场景 B：远程设备控制（乐观 UI + 异步控制状态闭环确认）

```
用户点击 ControlPage 的 ControlButton
  ├─ [保存前状态] @State private previousState = this.isOn
  ├─ [乐观 UI & 挂起] 按钮状态 isOn 临时翻转，同时按钮显示 Loading，并禁用重复点击（处于 Pending 状态）
  ├─ [前置检查] DeviceService.getCachedDevices() 检查设备 online（双重校验：ControlPage 和 CommandService 各检查一次）：
  │    ├─ 离线 → 回滚：恢复 isOn = previousState，按钮退出 Loading 态 → toast"设备离线，无法执行操作"
  │    └─ 在线 → 继续下发
  ├─ CommandService.send(selectedDeviceId, command)
  │    ├─ HttpClient.POST('/command', payload) → 后端下发云端并生成 command_id
  │    ├─ 解析响应:
  │    │    ├─ code=0 (状态 "sent") → 云端已发送，进入【控制确认轮询循环】：
  │    │    │    ├─ 启动周期 1s 的微型轮询任务，至多执行 5 次（总长 5s 超时门槛）
  │    │    │    ├─ 每次轮询调用 CommandService.getLogs(selectedDeviceId) 并匹配该 command_id
  │    │    │    ├─ 情况1：匹配到记录且 result_code == 0
  │    │    │    │    └─ 真正执行成功 → 按钮结束 Loading/Pending 状态，保持 isOn 新值，完成状态闭环 → toast"操作成功"
  │    │    │    ├─ 情况2：匹配到记录且 result_code > 0 (非0)
  │    │    │    │    └─ 执行失败/设备最终离线 → 退出 Pending 态，回滚 isOn = previousState → DeviceService.refreshDevices() 刷新状态 → toast"设备执行失败/离线"
  │    │    │    └─ 情况3：轮询 5 次结束仍无 result_code (Pending 超时)
  │    │    │         └─ 退出 Pending 态，回滚 isOn = previousState → toast"执行超时，请稍后刷新重试"
  │    │    ├─ code=1003 (设备已离线) → 回滚：isOn = previousState，退出 Loading 态 → DeviceService.refreshDevices() 刷新缓存 → toast"设备离线"
  │    │    └─ 其他非0错误码 → 回滚：isOn = previousState，退出 Loading 态 → toast"操作失败，请重试"
  │    └─ 无论成败 → 刷新控制日志列表
```

### 场景 C：病虫害记录分页浏览 + 图片直连与降级

```
DiseaseRecordsPage.aboutToAppear() [以 NavDestination 挂载]
  ├─ isDestroyed = false
  ├─ PaginatedList.aboutToAppear() → 自动加载第 1 页
  │    └─ DiseaseService.getList(filters, page=1) → 追加至 records 数组
  │         ├─ filters: device_id（当前选定设备）, crop_type（筛选条件）, severity（筛选条件）, page, page_size
  │         └─ 响应含 pagination.total → 根据 records.length < total 判定 hasMore
  ├─ 筛选变更（cropFilter/severityFilter/selectedDeviceId 变化 → onFilterChanged 回调）
  │    └─ listRebuildKey++ → 通过 key 变更强制重建 PaginatedList 实例
  ├─ 用户点击某条记录 → 弹出详情弹窗
  │    └─ 若有 image_path → ImageViewer { src: baseURL + image_path }
  │         ├─ 主路径（免签直连）：由 native Image 组件直接向后端 GET 该静态资源渲染
  │         └─ 降级路径（Image 触发 onError）：组件调用 ImageService.getRaw 获取 ArrayBuffer →
  │              ImageSource 创建 → 解码为 PixelMap 并重新赋给 ImageViewer 渲染
  └─ 用户滚动到底部 → PaginatedList 触发 loadNextPage → 追加至现有列表
```

**实况说明**：与文档早期版本不同，`DiseaseRecordsPage` 不包含 `isLoading`、`errorMessage`、`connectivityStatus` 等状态变量的声明，也没有显式的 `loadData()` 方法。数据加载完全委托给 `PaginatedList` 组件（其内部管理 `isLoading` 和 `hasMore` 状态）。筛选参数（`cropFilter`/`severityFilter`）通过 `@Watch` 监听变更后递增 `listRebuildKey`，利用 ArkUI 的 `key` 属性机制强制重建 `PaginatedList` 实例来触发重新加载。

### 场景 D：仪表盘实时数据刷新

```
DashboardPage.aboutToAppear() [以 NavDestination 挂载]
  ├─ isDestroyed = false
  ├─ isLoading = true
  ├─ loadData() [异步]
  │    ├─ SensorService.getLatest(selectedDeviceId) → SensorCard 群组刷新（含数据时间戳）
  │    ├─ SensorService.getHistory(selectedDeviceId, timeRange) → ChartView 折线图渲染（LineChartRenderer）
  │    └─ isLoading = false
  └─ PollingManager.start('dashboard_sensor', 10000)
       └─ 每 10s（串行 setTimeout）: SensorService.getLatest(selectedDeviceId) → if (isDestroyed) return → 更新 @State → SensorCard 刷新 (成功与失败分别触发 connectivity 状态机在线/离线转换)
```

### 场景 E：页面切换与轮询生命周期管理 (基于 Navigation)

```
页面 A 路由跳转到页面 B：pageStack.pushPathByName('B')
  ├─ 页面 A 不被销毁（仍在路由栈中），轮询任务在后台继续运行（key 不同，与 B 共存）
  ├─ 页面 B.aboutToAppear() → PollingManager.start('B相关key')
  └─ PollingManager 允许多 key 共存

页面 B 返回页面 A：pageStack.pop()
  ├─ 页面 B 被销毁，触发 页面 B.aboutToDisappear() → PollingManager.stop('B相关key')，isDestroyed = true
  └─ 页面 A 重新获得焦点显示，其轮询仍在正常运行，不需重复触发

应用进入后台: EntryAbility.onBackground() → PollingManager.suspendAll() 暂停所有轮询
应用回到前台: EntryAbility.onForeground() → PollingManager.resumeAll() 恢复所有轮询
```

### 场景 F：设备切换级联刷新 (基于 AppStorage)

```
DeviceSelector 触发 onDeviceChange(newDeviceId)
  ├─ 更新全局状态 AppStorage.selectedDeviceId = newDeviceId
  ├─ Index 通过 @Watch('onDeviceIdChanged') 监听变更：
  │    ├─ startPolling()：重新注册 'index_sensor' 和 'index_alarm' 轮询
  │    ├─ fetchLatestSensor()：立即获取新设备的传感器数据
  │    └─ fetchAlarmStatus()：立即获取新设备的告警状态
  └─ 各子页面通过 @StorageLink 监听变更：
       ├─ DashboardPage → @Watch → 重新调用 SensorService.getLatest / getHistory
       ├─ AdvisoryPage → @Watch → 重新拉取 AdvisoryService.getAdvisory
       ├─ ControlPage → @Watch → 重新加载控制日志
       └─ DiseaseRecordsPage → @Watch → onFilterChanged → 递增 listRebuildKey 强制重建列表
```

---

## 错误处理策略

### 错误分类

| 类别 | 来源 | 处理方式 |
|------|------|---------|
| **网络连接失败** | `http.request()` 抛出异常（无网络、超时、DNS 解析失败） | 在 `api.ets` 层统一 `catch` 为结构化错误，`HttpClient` 触发指数退避重试（幂等请求至多 3 次，非幂等不做重试）；重试耗尽后传递至 Service 层；页面层根据 `connectivity` 展示离线 UI |
| **HTTP 非 200 状态码** | 服务端返回 4xx/5xx | `HttpClient` 根据状态码映射为 `ApiResponse` 中的 `code` 字段；408/429/502/503/504 触发重试（需在 `RetryPolicyConfig.retryOn` 中） |
| **业务错误码** | API `response.code ≠ 0` | 码值 1001（参数校验失败）、1002（资源不存在）、1003（设备离线）明确提示；1004（API Key 无效）、1005（频率限制）、2001（数据库错误）、3001（IoTDA 调用失败）、5000（服务器内部错误）统一提示"服务异常，请稍后重试"。`constants.ets` 中定义为具名 `ErrorCode` 联合类型 |
| **JSON 解析失败** | 响应体非预期格式 | `HttpClient` 层 `try-catch`，返回格式错误信号，页面层提示"数据格式异常" |
| **图片格式异常** | 图片数据非预期格式或损坏 | `ImageService` 返回失败信号，`ImageViewer` 组件展示"图片加载失败"占位 |
| **UI 操作错误** | 用户快速重复点击、在离线状态下操作 | 组件层防重复点击（加载态/Pending 态禁用按钮）+ 操作前通过 `DeviceService` 检查设备状态 |

### 弱网韧性策略

| 维度 | 策略 |
|------|------|
| **请求重试** | `HttpClient` 实现指数退避重试（baseDelayMs=1000, maxDelayMs=10000, maxRetries=3），仅幂等 GET 请求重试，非幂等 POST 不做重试 |
| **本地缓存** | `CacheManager` 提供通用内存缓存，各 Service 在成功获取数据后缓存；网络失败时优先返回缓存数据并标记"数据可能非最新"；传感器数据默认 TTL 30s |
| **离线 UI** | 每个页面增加 `@State connectivity`（`ConnectivityStatus` 类型），`ConnectivityIndicator` 在页面顶部展示 4px 绿/黄/红细条；`SensorCard` 展示数据时间戳帮助判断新鲜度 |
| **轮询与重试交互** | `PollingManager` 采用串行模式（递归 `setTimeout`），上一个 tick 完全结束后再调度下一个；轮询回调中的重试在写入缓存时检查页面销毁标记，防销毁前存入过期数据 |
| **安全屏障** | 所有页面在销毁时触发 `isDestroyed = true`，异步回调必须检查该标志，严禁在销毁后修改本地 `@State` |

### `connectivity` 状态转换矩阵

| 当前状态 | 触发事件 | 下一状态 | 说明 |
|---------|---------|---------|------|
| `'online'` | 页面 `aboutToAppear` | `'loading'` | 开始加载数据，`ConnectivityIndicator` 显示黄色 |
| `'loading'` | Service 调用成功 | `'online'` | 数据获取成功，恢复在线标识（绿色） |
| `'loading'` | 网络异常 + 重试耗尽 | `'offline'` | 连续失败，标记离线（红色） |
| `'offline'` | 后续 Service 调用成功 | `'online'` | 网络恢复，标记重新在线（绿色） |
| `'offline'` | 后续 Service 再次失败 | `'offline'` | 连续离线，保持离线标识 |
| `'loading'` / `'online'` / `'offline'` | 业务错误（API code ≠ 0） | 保持当前值不变 | 业务错误不影响连接状态判定 |

**转换规则**：
- 初始值：`'online'`（避免启动时闪白）；`aboutToAppear` 中设置为 `'loading'`。
- 状态转换在每个页面的 `loadData()` 以及轮询 Callback 的 catch 块中同步维护，拒绝模块级 `globalConnectivity` 方案，以确保页面指示的精确性。

---

## 并发设计

### 线程模型

ArkTS 运行在 ArkUI 的主 UI 线程上，所有 UI 操作和状态更新必须在主线程执行。网络请求通过 `@ohos.net.http` 的回调异步模型处理。

- **网络请求**：使用 `async/await` 语法，不阻塞 UI 线程。
- **轮询**：`PollingManager` 内部使用递归 `setTimeout` 串行调度，每个回调函数内部 `await` 网络请求，上一个 tick（含重试）完全结束后再调度下一个。
- **重试**：`HttpClient` 内部的指数退避重试使用 `sleep`（`setTimeout` 包装的 Promise）延迟执行，不阻塞轮询的串行调度。
- **状态更新**：所有 `@State` 变量的修改在 `await` 之后恢复的同步上下文中执行，且由于提供了 `isDestroyed` 屏障，确保在主线程生命周期安全的范围内更新 UI 状态。

### 轮询调度约束

| 页面 | 轮询 key | 间隔 | 触发条件 | 停止条件 |
|------|---------|------|---------|---------|
| Index | `index_sensor` | 10s | 页面出现（或设备切换） | 页面消失（NavDestination 移除） |
| Index | `index_alarm` | 10s | 页面出现（或设备切换） | 页面消失（NavDestination 移除） |
| DashboardPage | `dashboard_sensor` | 10s | 页面出现 | 页面消失（NavDestination 移除） |
| AdvisoryPage | `advisory_refresh` | 10s | 页面出现 | 页面消失（NavDestination 移除） |

`PollingManager` 确保：
1. 同一 key 不会重复注册（已存在的先清除再新建）。
2. **串行模式**：使用递归 `setTimeout`，上一个 tick 完全结束后再调度下一个周期，消除 `setInterval` 与重试的竞争。
3. 所有轮询在应用进入后台时通过 `EntryAbility.onBackground()` → `PollingManager.suspendAll()` 暂停。
4. 应用回到前台时通过 `EntryAbility.onForeground()` → `PollingManager.resumeAll()` 恢复。
5. 在 `Navigation` 中，若页面移出路由栈销毁，在 `aboutToDisappear` 中注销所属轮询；若仅压栈隐藏，轮询继续后台执行以保持最新缓存。

### 共享状态管理

- 所有网络请求结果通过 `@State` 局部状态持有，不共享跨页面全局状态。
- API Key 与 Base URL 通过模块级常量持有。
- 设备选择结果通过全局共享的 `AppStorage.selectedDeviceId` 双向绑定同步。
- `CacheManager` 作为模块级单例，在 Service 层共享缓存数据。

---

## 设计决策

### 决策 1：服务层独立于 UI 层

**选择**：所有 HTTP 交互封装在 `services/` 目录下独立的类中，页面不直接调用底层网络模块。

**理由**：
- ArkTS 不支持继承体系，但支持模块级导入和函数导出，Service 以模块级实例（单例）方式暴露给页面。
- Service 的职责边界清晰，便于单元测试和替换（如后续切换为 WebSocket）。
- 页面仅需关注状态和 UI 渲染，降低页面代码复杂度。

### 决策 2：`PollingManager` 集中管理轮询

**选择**：使用 `PollingManager` 统一管理所有轮询任务，而非各页面各自 `setInterval`。

**理由**：
- ArkTS 中 `setInterval` 的 ID 无法被其他页面感知，页面切换时旧页面的定时器可能残留。
- 集中管理可以统一响应应用前后台切换事件（`EntryAbility.onBackground/onForeground`）。
- 符合单一职责原则：轮询调度逻辑不与 UI 生命周期耦合。

### 决策 3：数据模型使用 `interface` 而非 `class`

**选择**：使用 ArkTS `interface` 定义所有数据模型。

**理由**：
- API 返回的 JSON 直接通过 `JSON.parse()` 解析为普通对象，天然匹配 `interface` 的结构化类型。
- ArkTS 中 `class` 需要额外构造函数和序列化/反序列化代码，对纯数据传输场景过度设计。
- `interface` 在编译期提供类型检查，运行时无开销。

### 决策 4：组件通过 `@Prop` / `@Link` 实现数据流

**选择**：父 → 子用 `@Prop`（只读），父子双向用 `@Link`（通过 `$variable` 语法传递引用）。

**理由**：
- ArkUI 的设计范式要求组件的输入通过装饰器显式声明，这与 `@Prop` / `@Link` 的语义一致。
- `SensorCard` 等展示型组件只需要 `@Prop`（父→子单向数据流）。
- `ControlButton` 需要乐观 UI 翻转，使用 `@Link` 使子组件具备修改父组件状态的能力。

### 决策 5：采用 AppStorage 进行设备状态同步

**选择**：不使用路由参数传递设备 ID，各组件及页面双向绑定全局键 `AppStorage.selectedDeviceId`。

**理由**：
- 鸿蒙 App 虽小，但由于 `Navigation` 导航下多视图并存且存在堆栈遮挡，路由传参在 `pop()` 回退时无法通知之前的页面更新设备 ID。
- `AppStorage` 天然提供跨组件和跨页面的双向数据同步，在一处修改可以同步触发所有活跃页面的级联数据刷新。

### 决策 6：告警轮询使用 SensorService + alarm_flag 位掩码

**选择**：轮询调用 `SensorService.getLatest()` 并通过 `alarm_flag` 位掩码解析告警，而非通过 `AdvisoryService`。

**理由**：
- 后端传感器快照数据已天然包含 `alarm_flag` 位掩码字段（8 位分别对应高温/低温/高湿/低湿/低光照/高 CO2/低氮/低磷报警）。
- 避免额外的告警接口调用，减少服务端负载和网络消耗。
- 位掩码解析由 `utils.parseAlarmFlag()` 纯函数完成，逻辑轻量且可测试。
- 10s 轮询间隔下，传感器快照数据可同时满足环境显示和告警检测的双重需求。

### 决策 7：命令下发采取乐观 UI 更新与异步状态确认闭环

**选择**：按钮点击后进入 Pending 加载状态并乐观切换目标值，在 API 返回 sent 后，启动微型 1s 周期轮询抓取 `control_logs` 直至检测到最终执行结果，确认成败后退出 Pending 态；如遇最终执行失败则自动回滚状态并发出 Toast。

**理由**：
- 解决异步控制指令下发的"状态假象"——发送成功（sent）不等于设备执行成功（success），强行乐观 UI 极易造成设备卡死但前端显示正常的虚假状态。
- 通过简短的状态轮询闭环，能在 2-3 秒内自动确定设备的实际执行响应，提供更稳健、更可靠的控制回路。

### 决策 8：`api.ets` 与 `HttpClient` 的两层 HTTP 封装

**选择**：保留 `common/api.ets` 作为 `@ohos.net.http` 和 `@ohos.request` 的原始封装，`services/HttpClient.ets` 在其基础上构建业务门面。

**理由**：
- 避免将 `@ohos.net.http` 的原始 API（`createHttp`/`destroy`/`RequestMethod`）暴露到 Service 层，`api.ets` 承担适配器角色。
- `HttpClient` 专注于业务语义（认证、路径、JSON、错误码），不关注传输细节。图片上传使用系统原生 `@ohos.request` 在 `api.ets` 中单独封装为 `uploadFile` 供 `ImageService` 调用，避开了 `HttpClient` 的 JSON 序列化限制。

### 决策 9：`ImageService` 与生产免签图片访问策略

**选择**：`ImageViewer` 采用"主路径 + 降级路径"双路径方案。主路径直连 `baseURL + image_path` 渲染，前提是服务端对图片静态目录 `/images/...` 免除 `X-API-Key` 鉴权；降级路径在 Image 触发 `onError` 时通过 `getRaw` 接口下载 ArrayBuffer 并转换为 `PixelMap` 渲染。

**理由**：
- 彻底规避 ArkUI 原生 `Image` 无法在网络 GET 请求中注入自定义安全 Header（如 `X-API-Key`）的问题。
- 服务端免除图片目录的鉴权，使鸿蒙端直连 URL 成为最省电、最节省内存和 CPU 的首选路径，仅在静态直连由于网络或路径失效报错时走降级流，确保了方案的弱网高韧性。

### 决策 10：弱网韧性及安全隔离策略

**选择**：配置重试与内存缓存作为 `common` 层基础设施，并强制引入组件级 `isDestroyed` 保护标志。

**理由**：
- 避免重试和缓存逻辑在各 Service 重复编写。
- 页面销毁后若仍有 Pending 中的重试 Promise 回调，修改被销毁组件的 `@State` 变量会引发运行时异常，因此引入 `isDestroyed` 门哨以确保组件内存及状态更新的安全。

### 决策 11：`PollingManager` 串行模式治理轮询与重试竞争

**选择**：`PollingManager` 使用递归 `setTimeout` 替代 `setInterval`，确保上一个 tick（含重试）完全结束后再调度下一个。

**理由**：
- `setInterval` 不等待回调完成，与 `HttpClient` 的指数退避重试存在竞争（并发请求、UI 状态竞争、带宽浪费、缓存竞争）。
- 串行模式消除竞争：每个轮询 tick 是一个 Promise 链，resolve 后调度下一个 10s，适用于 IoT 弱网场景，避免重试与轮询的累积效应。

### 决策 12：`DiseaseService` 的方法签名一致性

`DiseaseService` 的 `getStats()` 和 `getHeatmap()` 在核心抽象中显式定义，与 `SensorService.getDaily()` 的方法签名模式一致。`getList()` 接受 `DiseaseListFilters` 接口参数。

### 决策 13：采用 Navigation 架构进行路由设计

**选择**：废弃 `router` 模块，改用官方推荐的 `Navigation` + `NavDestination` 作为组件间跳转方案。

**理由**：
- `router` 在 HarmonyOS NEXT 中已被停止升级且不推荐在新项目中使用。
- `Navigation` 具备无限制页面栈、深度组件状态保存、一多适配以及优越的转场性能，更符合现代化声明式 UI 开发范式。
- 完美解决 `router.back()` 时无法刷新前置页面的跨页面通信痛点。

### 决策 14：告警基于传感器 alarm_flag 位掩码（v1.0 简化设计）

**选择**：告警检测复用 `SensorSnapshot.alarm_flag` 字段的位掩码，通过位运算提取各维度报警状态。

**理由**：
- `alarm_flag` 是后端传感器数据表的原生字段，无需额外服务端接口。
- 位掩码设计具备扩展性（最多支持 8 种报警类型，当前使用 8 位，参见 `constants.ets` 中 `ALARM_FLAG_*` 常量）。
- `utils.parseAlarmFlag()` 纯函数将位掩码转为人类可读的标签数组，与 UI 层解耦。
