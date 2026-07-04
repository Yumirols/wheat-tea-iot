# 农眼卫士 FarmEye Guard v1.0 — 鸿蒙移动应用 OOD 设计方案（v6）

## 概述

鸿蒙 App 作为"端-云-台"三层架构中的表现层，承担农户移动端监控与远程控制职责。设计核心目标是在 ArkTS + ArkUI 的声明式框架约束下，实现数据展示、设备控制、告警推送、记录浏览、图像管理五大功能域的内聚组织。

**整体架构思路**：采用"服务层（Service Layer）+ 页面层（View Layer）+ 公共层（Common Layer）"三层次架构：

- **服务层**将 HTTP API 交互封装为具有明确职责的 Service 类，页面通过 Service 获取数据，不直接操作 `http` 模块
- **页面层**遵循 ArkUI 的 `@Entry` + `@Component` 范式，每个页面为一个 struct，内部按职责拆分为子组件
- **公共层**承载数据模型定义（`interface`）、HTTP 原始封装、共享常量、工具函数、弱网韧性基础设施，被所有页面和服务引用

**依赖方向**：页面层 → 服务层 → 公共层。页面层仅依赖服务层的接口抽象，不依赖实现细节；服务层依赖公共层的数据模型定义、HTTP 原始封装和韧性基础设施。

---

## 模块划分

### 模块边界

```
harmony-app/entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets          # Ability 生命周期管理，加载首页；onBackground 统一暂停轮询

├── pages/                         # 视图层：5 个 @Entry 页面
│   ├── IndexPage.ets             # 首页：设备列表 + 环境快照概览 + 最近告警 + 传感器数据轮询
│   ├── DashboardPage.ets         # 仪表盘：传感器卡片 + 实时曲线
│   ├── DiseaseRecordsPage.ets    # 病虫害记录：列表 + 筛选 + 详情
│   ├── ControlPage.ets           # 远程控制：设备执行机构操作面板
│   └── AdvisoryPage.ets          # 防治建议：AI 决策建议展示

├── components/                    # 可复用 UI 组件
│   ├── SensorCard.ets            # 传感器参数卡片（温度/湿度/光照/CO2/NPK 共用），含数据时间戳
│   ├── ChartView.ets             # 历史趋势图表组件，通过 ChartRendererAPI 切换渲染器
│   ├── LineChartRenderer.ets     # 折线图渲染器（v1.0 最小可用：单 Y 轴单折线，无触摸交互）
│   ├── BarChartRenderer.ets      # 柱状图渲染器（v1.0 预留架构，非必须）
│   ├── DeviceSelector.ets        # 设备选择器：@Link selectedDeviceId + onDeviceChange 回调
│   ├── AlarmBanner.ets           # 告警横幅（实时告警推送展示，支持点击跳转/关闭）
│   ├── ControlButton.ets         # 控制按钮（ON/OFF 双态按钮，@Link 同步父组件状态，含乐观 UI + 回滚）
│   ├── SeverityBadge.ets         # 严重度徽标（Mild/Moderate/Severe 三色）
│   ├── PaginatedList.ets         # 分页列表容器（封装分页加载逻辑）
│   ├── ImageViewer.ets           # 病虫害图片查看器（URL 路径：直接 Image(src) 加载）
│   ├── ConnectivityIndicator.ets # 连接状态指示器（页面顶部细条，绿/黄/红三色）
│   └── LoadingState.ets          # 统一加载状态占位（骨架屏 / 加载指示器 / 错误重试）

├── services/                      # 服务层：API 交互封装
│   ├── HttpClient.ets            # HTTP 客户端——业务级门面（baseURL、API Key、JSON 解析、错误码映射、指数退避重试）
│   ├── SensorService.ets         # 传感器数据查询（latest / history / daily）：含轻量级内存缓存
│   ├── DiseaseService.ets        # 病虫害记录查询（list / stats / heatmap）
│   ├── CommandService.ets        # 设备控制命令下发（send / logs）：失败路径发送缓存失效信号
│   ├── AdvisoryService.ets       # 防治建议拉取
│   ├── DeviceService.ets         # 设备列表与在线状态：含模块级缓存（getCachedDevices / refreshDevices）
│   ├── ImageService.ets          # 图像上传与获取（通过 HttpClient multipart 模式 + getRaw 路径）
│   └── PollingManager.ets        # 轮询调度器（统一管理各模块的轮询生命周期，串行/跳略模式）

├── common/
│   ├── models.ets                # 数据模型：响应结构、业务实体 interface 定义（含 PollingCallback 显式类型）
│   ├── api.ets                   # HTTP 原始封装——@ohos.net.http 生命周期管理 + requestRaw 二进制路径 + buildFormData/requestMultipart
│   ├── constants.ets             # 常量定义（API 基础路径、轮询间隔、命令枚举等）
│   ├── RetryPolicy.ets           # 重试策略定义（maxRetries, baseDelayMs, maxDelayMs, retryOn, timeoutMs）
│   ├── CacheManager.ets          # 通用内存缓存管理器（CacheEntry<T>，TTL 控制，过期失效）
│   └── utils.ets                 # 工具函数（格式化、位掩码解析、时间处理）
```

### 模块职责

| 模块 | 职责 | 依赖 |
|------|------|------|
| `pages/` | 页面编排、UI 状态管理（含 isLoading/errorMessage/connectivityStatus）、用户交互事件响应 | `services/`, `components/`, `common/` |
| `components/` | 可复用 UI 部件的渲染和局部状态管理 | 仅 `common/models.ets`（类型引用） |
| `services/` | 封装业务 HTTP 请求逻辑、数据响应解析、业务预处理、本地缓存管理 | `common/`（特别是 `common/api.ets` 和 `models.ets`） |
| `common/` | 数据模型定义、HTTP 原始封装、弱网韧性基础设施（RetryPolicy、CacheManager）、工具函数 | 无内部依赖 |

### 模块间依赖方向

```
pages/ ──→ services/ ──→ common/
  │                        ↑
  └──────── components/ ───┘
```

- `pages/` 依赖 `services/` 获取数据，依赖 `components/` 渲染子 UI
- `services/` 依赖 `common/` 进行 HTTP 通信和类型引用
- `components/` 仅引用 `common/models.ets` 中的类型定义

### `common/api.ets` 与 `services/HttpClient.ets` 的职责分工

`api.ets` 和 `HttpClient.ets` 处于不同的抽象层次，形成"原始传输层 → 业务门面层"的两层 HTTP 封装结构：

| 层次 | 文件 | 职责范围 | 使用者 |
|------|------|---------|--------|
| **原始传输层** | `common/api.ets` | 封装 `@ohos.net.http` 的生命周期管理（`createHttp()`/`destroy()`）、请求超时设置、基础请求头注入、网络异常原生错误捕获、HTTP 状态码判断；新增 `requestRaw()` 返回 `ArrayBuffer`；新增 `buildFormData()` 和 `requestMultipart()` 支持 multipart 传输。返回 `TextResult` / `BinaryResult` 联合类型 | 仅供 `HttpClient` 调用 |
| **业务门面层** | `services/HttpClient.ets` | 在 `api.ets` 基础上叠加业务语义：注入 `X-API-Key` 认证头、拼接 API 基础路径（`/api/v1`）、JSON 序列化/反序列化、通用业务错误码（1001–5000）映射、统一的 `ApiResponse<T>` 解析、指数退避重试。提供 `get<T>()` / `post<T>()` 泛型方法和 `getRaw()` 二进制获取方法 | 供所有 `*Service` 调用 |

**关于现有 `common/api.ets` 的迁移策略**：设计假设现有 `api.ets` 为纯传输层实现（管理 `@ohos.net.http` 生命周期），不包含认证头注入、JSON 解析或路径拼接等业务语义。若实际实现与假设不一致（如现有 `api.ets` 已包含 `X-API-Key` 注入或 JSON 解析），采取增量剥离策略——将业务语义逐步迁移至 `HttpClient`，`api.ets` 保留纯传输职责，迁移过程中两个模块的职责重叠通过适配层兼容，不要求一次性重写。

### `common/RetryPolicy.ets` 和 `common/CacheManager.ets` 的定位

`RetryPolicy` 和 `CacheManager` 位于 `common/` 层，作为弱网韧性基础设施被 `HttpClient` 和各 Service 使用：

- **RetryPolicy** 定义重试策略的配置结构，被 `HttpClient` 在 `get<T>()` / `post<T>()` 内部用于判断是否重试、退避间隔等。非幂等 POST（命令下发）不做重试
- **CacheManager** 提供泛型内存缓存能力，被各 Service（特别是 `SensorService`、`DeviceService`）用于缓存最后一次成功获取的数据，网络失败时返回缓存值

---

## 核心抽象

### 1. `api.ets` — HTTP 原始传输封装

**角色**：`@ohos.net.http` 的轻量适配器。

**职责**：
- 管理 `http.createHttp()` 和 `destroy()` 的完整生命周期（每次请求创建新实例，请求完成后销毁）
- 提供原始 `request(url, options)` 函数，接收 URL、请求方法和头部、请求体
- 新增 `requestRaw(url, options)` 方法，内部设置 `expectDataType: http.HttpDataType.ARRAY_BUFFER`，返回二进制响应体
- 新增 `buildFormData(fields)` 辅助函数，内部调用 `http.createMultipartFormData().addPart()`，返回 `http.MultiFormData` 实例
- 新增 `requestMultipart(url, formData, options)` 方法，内部设置 `extraData: formData` 和 `Content-Type: multipart/form-data`
- 设置全局超时（如 10s）
- 捕获网络层异常（无网络、超时、DNS 解析失败）并转换为结构化的失败信号
- 不解析 JSON、不注入业务头部、不处理业务错误码

**协作方式**：被 `HttpClient` 调用。`HttpClient` 负责拼装完整 URL、注入 `X-API-Key`、序列化请求体，然后根据是否为二进制或多部分请求选择 `request()` / `requestRaw()` / `requestMultipart()`。

**类型形态选择理由**：选择为纯函数导出（而非类），因为传输层是一组无状态的工具函数，不需要持有内部状态，ArkTS 的模块级函数导出即可满足。

### 2. `HttpClient` — HTTP 业务门面（含重试逻辑）

**角色**：服务层 HTTP 通信的统一入口单例。

**职责**：
- 持有 API 基础 URL（通过常量模块获取）和 `X-API-Key` 认证令牌
- 在 `api.ets` 返回的原始响应上叠加业务处理：JSON 解析 → 检查 `code` 字段 → 映射为 `ApiResponse<T>`
- 提供 `get<T>(path, params)` / `post<T>(path, body, multipart?)` 泛型方法，返回已解析的 `ApiResponse<T>` 或抛出业务异常
- 提供 `getRaw(path, params?)` 方法，返回 `ArrayBuffer`，专用于二进制响应（如图片）获取，绕过 JSON 解析路径
- `post` 方法新增 `multipart?` 可选参数；当 `multipart` 存在时，调用 `api.ets` 的 `requestMultipart()` 路径，而非 JSON 序列化路径
- 实现指数退避重试：对网络异常（catch 捕获）和 HTTP 408/429/502/503/504 进行重试，baseDelayMs=1000, maxDelayMs=10000, maxRetries=3；非幂等请求（POST 命令下发）不做重试

**协作方式**：所有 `*Service` 通过 `HttpClient` 发起请求，不直接调用 `api.ets`。JSON API 场景使用 `get<T>()` / `post<T>()` 泛型方法；`ImageService` 获取图片二进制时使用 `getRaw(path)` 方法；`ImageService` 上传图片时通过 `post()` 的 `multipart` 参数走请求 `requestMultipart()` 路径。

**类型形态选择理由**：选择为模块级变量实现的单例，因为 API Key 和基础 URL 全局唯一且配置一次后不再变化，模块级 `export const` 天然实现单例语义，无需类构造。

### 3. `SensorService` — 传感器数据获取（含本地缓存）

**角色**：环境监测数据的统一查询入口。

**职责**：
- 封装最新快照、历史数据、日聚合三种查询的 HTTP 请求逻辑和响应解析
- 提供 `getLatest(deviceId)`、`getHistory(deviceId, start, end, page?, pageSize?)`、`getDaily(deviceId, start, end, page?, pageSize?)` 方法
- `getLatest(deviceId)`：`deviceId` 为空时返回所有设备的最新快照列表（对应 API 不传 `device_id` 的行为）；`deviceId` 非空时返回该设备的最新一条快照；若调用方传入空字符串或 undefined，视为"查询全部"，Service 不拼接 `device_id` 查询参数
- 返回经过类型断言后的结构化数据（而非裸 JSON）
- 不持有 UI 状态，仅做数据获取和转换
- 实现轻量级内存缓存：成功获取数据后存入 `CacheManager`，设默认 TTL 30s；网络失败时优先返回缓存数据，调用方可根据数据时间戳展示"数据可能非最新"提示

**协作方式**：被 `IndexPage`（最新快照卡片 + 10s 传感器轮询）、`DashboardPage`（历史趋势图表）调用。

### 4. `DiseaseService` — 病虫害记录服务

**角色**：病虫害检测记录的数据访问层。

**职责**：
- 封装记录列表（`getList(filters)`）、统计（`getStats()`）、热力图（`getHeatmap()`）三类查询
- 将筛选参数（时间范围、作物类型、严重度）映射为 URL query 参数
- 返回分页封装的数据结构

**协作方式**：被 `DiseaseRecordsPage` 调用，支持分页加载。

### 5. `CommandService` — 设备控制命令下发

**角色**：远程设备控制的操作入口。

**职责**：
- 封装 `POST /command/send` 的下发逻辑
- 封装 `GET /command/logs` 的查询逻辑
- 在下发前通过 `DeviceService` 前置检查设备在线状态（若本地缓存的设备状态为离线则提前拒绝，避免无效请求）
- 下发失败路径（`code=1003` 或网络异常）：发送缓存失效信号给 `DeviceService`，触发缓存刷新，避免后续请求基于过期的在线状态

**协作方式**：被 `ControlPage` 调用。调用前需通过 `DeviceService.getCachedDevices()` 检查设备在线状态。

**已知耦合说明**：`CommandService` 在失败路径中直接调用 `DeviceService.refreshDevices()`——这是跨 Service 的硬编码引用。当前 v1.0 阶段此耦合可接受（两个 Service 同属一个模块层，且设备状态失效后立即刷新是强时序相关性操作）。后续架构升级时可通过事件机制解耦（如发布 Channel 事件让 DeviceService 自行订阅）。

### 6. `AdvisoryService` — 防治建议服务

**角色**：AI 决策建议的拉取入口。

**职责**：
- 封装 `GET /advisory` 的请求和响应解析
- 解析建议详情、环境联动分析、自动动作标记等嵌套结构

**协作方式**：被 `AdvisoryPage` 调用，同时被 `PollingManager` 周期性轮询以触发告警通知。

### 7. `DeviceService` — 设备管理服务（含模块级缓存）

**角色**：设备列表与在线状态的查询入口。

**职责**：
- 封装 `GET /device/list` 的查询
- 维护模块级缓存：`let cachedDevices: DeviceInfo[]` 和 `let lastFetchTime: number`
- 提供 `getDeviceList()` 强制远程查询、`getCachedDevices(): DeviceInfo[]` 返回缓存值（不强制刷新）、`refreshDevices(): Promise<DeviceInfo[]>` 强制刷新
- 提供设备在线状态的判断依据（返回的 `online` 布尔字段）

**协作方式**：被 `IndexPage`（设备选择器）和 `ControlPage`（控制前检查在线状态）调用。`CommandService` 在失败路径中调用 `DeviceService.refreshDevices()` 更新缓存。

### 8. `ImageService` — 图像上传与获取

**角色**：病虫害图片资源的传输管理入口。

**职责**：
- 封装 `POST /image/upload` 的 multipart/form-data 上传逻辑：组装 `fields` 结构（文件 URI + 可选参数），通过 `HttpClient.post()` 的 `multipart` 参数走 `api.ets` 的 `requestMultipart()` 路径
- 封装 `GET /image/{image_id}` 的二进制流获取逻辑：调用 `HttpClient.getRaw(path)` 获取 `ArrayBuffer`，返回给页面层
- 不处理图片裁剪、压缩、缓存等非传输层职责

**协作方式**：
- 被 `DiseaseRecordsPage`（查看病虫害记录中的图片）和未来的图片上传页面调用
- 图片上传：通过 `HttpClient.post()` 的 `multipart` 参数，内部调用 `api.ets.requestMultipart()`，绕开 JSON 序列化路径
- 图片获取：通过 `HttpClient.getRaw(path)` 获取 `ArrayBuffer`，避开 `ApiResponse<T>` 的 JSON 解析路径
- 图片传输的两条路径（上传 + 获取）均经由 `HttpClient` 门面

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
- 定义重试策略的配置结构：`maxRetries`, `baseDelayMs`, `maxDelayMs`, `retryOn`（可重试 HTTP 状态码列表）, `timeoutMs`
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

**缓存键命名约定**：为避免多 Service 使用同一 `CacheManager` 实例时的键空间冲突，约定各 Service 使用统一前缀命名空间作为缓存键前缀（如 `sensor_latest_`、`device_list_`、`advisory_` 等）。

### 12. 页面组件（`IndexPage` / `DashboardPage` / `DiseaseRecordsPage` / `ControlPage` / `AdvisoryPage`）

**角色**：ArkUI 视图层的 `@Entry` 页面。

**职责**：
- 声明 `@State` 装饰的本地状态（UI 渲染数据）：每个页面增加 `@State private isLoading: boolean`、`@State private errorMessage: string | null`、`@State private connectivityStatus: 'loading' | 'online' | 'offline'`（初始值为 `'online'`，`aboutToAppear` 中短暂设为 `'loading'`），以及 `@State private alarmMessage: string` 和 `@State private alarmSeverity: 'mild' | 'moderate' | 'severe'`（用于 AlertBanner 展示）
- `connectivityStatus` 状态转换：初始值 `'online'` → `aboutToAppear` 中设置为 `'loading'` → `loadData()` 成功设为 `'online'` → 网络异常重试耗尽设为 `'offline'` → 后续成功调用恢复为 `'online'`
- 在同步的 `aboutToAppear()` 中通过非 async 方式触发 `loadData()` 异步方法：
  ```
  aboutToAppear() {
    this.connectivityStatus = 'loading'
    this.isLoading = true
    this.loadData().catch((err: BusinessError) => {
      this.isLoading = false
      this.errorMessage = '数据加载失败'
      promptAction.showToast({ message: '加载失败，请下拉刷新', duration: 2000 })
    })
  }
  ```
- `loadData()` 统一返回 `Promise<void>`，函数体内部的 try-catch 捕获同步段异常并转为 `Promise.reject`
- `loadData()` 统一 catch 中的 `connectivityStatus` 维护规则：
  - 每次 Service 调用成功 → `this.connectivityStatus = 'online'`
  - 网络异常且 HttpClient 重试耗尽 → `this.connectivityStatus = 'offline'`
  - 业务错误（API code ≠ 0）→ 保持当前值不变
- `build()` 中根据 `isLoading` / `errorMessage` / `connectivityStatus` 条件渲染加载指示器、错误状态（含重新加载按钮）、连接状态指示器或数据内容
- 在 `aboutToDisappear` 中停止所属轮询
- 将子组件所需的 `@Link` / `@Prop` 状态向下传递
- 页面间通过 `router.pushUrl()` / `router.replaceUrl()` 导航

**协作方式**：通过 Service 获取数据，通过子组件完成具体 UI 渲染。

### 13. `SensorCard` — 传感器参数卡片（含数据时间戳）

**角色**：环境参数的单值展示组件。

**职责**：
- 接收参数名、数值、单位、告警状态、数据时间戳作为属性
- 按数值范围和告警状态切换背景高亮色
- 展示数值的单位后缀
- 展示数据来源时间戳（帮助用户判断数据新鲜度）

**协作方式**：被 `DashboardPage` 和 `IndexPage` 复用。通过 `@Prop` 接收父组件的参数值。

### 14. `ChartView` — 历史趋势图表

**角色**：传感器历史数据的可视化组件。

**职责**：
- 通过 `@Prop chartType: 'line' | 'bar'` 切换渲染器实例
- 通过 `ChartRendererAPI` 接口委托实际绘制逻辑给具体渲染器
- 接收数据点数组作为输入

**协作方式**：被 `DashboardPage` 调用，数据源来自 `SensorService.getHistory()`。`ChartView` 不直接依赖 Canvas 操作，通过 `ChartRendererAPI` 接口与渲染器解耦。v1.0 最小可用版本：仅实现 `LineChartRenderer`（单 Y 轴单折线，无触摸交互），`BarChartRenderer` 预留架构后续实现。

### 15. `ChartRendererAPI` — 图表渲染器接口

**角色**：图表渲染策略的行为契约。

**职责**：定义渲染器的统一接口，包括 `render(ctx, data, width, height)` 绘制方法和可选的 `onTouch(x, y)` 交互方法。

`LineChartRenderer` 和 `BarChartRenderer` 分别实现此接口，`ChartView` 通过 `@Prop chartType` 切换渲染器实例。

### 16. `ControlButton` — 双态控制按钮（含乐观 UI 回滚）

**角色**：设备 ON/OFF 控制的操作组件。

**职责**：
- 通过 `@Link isOn: boolean` 接收并同步父组件状态——点击后立即执行 `this.isOn = targetState` 实现乐观 UI 翻转，此修改直接反映到父组件的对应 `@State` 变量
- 操作前保存当前状态到 `@State private previousState: boolean`
- 乐观 UI：点击后立即切换为目标状态并显示加载态
- 显示当前状态文案（"已开启"/"已关闭"）
- 失败时回滚：恢复为 `this.previousState`，根据错误类型展示差异化 toast（"设备离线" vs "操作失败"）
- 错误时通过 `promptAction.showToast()` 反馈

**`@Link` 决策说明**：选择 `@Link` 而非 `@Prop` 的理由是——`@Prop` 在 ArkUI 中为只读属性，子组件无法对其赋值；乐观 UI 要求点击后立即翻转状态，需要子组件具备直接修改父组件状态的能力。`@Link` 通过 `$isOn` 语法传递引用引用，`this.isOn = targetState` 即向父组件的 `@State` 写入，语义明确。此方案不依赖 `aboutToUpdate`（ArkUI API 21 不存在此生命周期）。

**协作方式**：被 `ControlPage` 复用，每个实例对应一个执行机构（喷淋/灌溉/蜂鸣器/LED）。

### 17. `AlarmBanner` — 告警横幅

**角色**：页面顶部实时告警展示组件。

**职责**：
- 通过 `@Prop message: string` 接收告警消息文本
- 通过 `@Prop severity: 'mild' | 'moderate' | 'severe'` 控制横幅颜色（绿/橙/红）
- 自动展示最新一条告警信息，支持滚动多行文本显示
- 用户点击横幅时触发跳转（`router.pushUrl({ url: 'pages/AdvisoryPage' })`），查看完整建议详情
- 用户可点击关闭按钮解除当前告警展示（仅隐藏展示，不消除服务端告警记录）
- 当 `message` 为空字符串时，组件自身不渲染（visibility hidden）

**协作方式**：被 `IndexPage` 和 `DashboardPage` 使用，数据源来自轮询回调更新的 `@State alarmMessage/alarmSeverity`。

### 18. `PaginatedList` — 分页列表容器

**角色**：支持无限滚动的分页列表组件。

**职责**：
- 接收分页加载回调函数作为属性
- 管理加载更多、加载中、无更多数据三种状态
- 在滚动到底部时自动触发下一页加载

**协作方式**：被 `DiseaseRecordsPage` 使用，加载函数指向 `DiseaseService.getList()`。

### 19. `ImageViewer` — 病虫害图片查看器

**角色**：病虫害记录关联图片的展示组件。

**职责**：
- **主路径（直接 URL 加载）**：`DiseaseRecord.image_path` 为服务端返回的 URL 相对路径（如 `/images/2026/07/03/img_xxx.jpg`），API 文档（§2.4.1）明确标注 `image_path` 为"公开 URL"，可通过 `baseURL + image_path` 拼接为完整 URL 供 `Image` 组件直接加载
- 接收图片 URL 作为 `@Prop` 属性
- 在图片容器中使用 `<Image src={fullImageUrl}>` 渲染网络图片，ArkUI 原生支持
- 展示加载中、加载失败、空状态三种占位效果
- **降级路径**：若 `Image` 组件加载失败（`onError` 回调），采用备用路径——调用 `ImageService.getImagePixelMap(imageId)` 完成 `ArrayBuffer` → `ImageSource` → `PixelMap` 解码链，`ImageViewer` 通过 `@Prop` 接收 `PixelMap` 对象渲染
- `imageId` 从 `image_path` 的文件名部分提取（如 `/images/2026/07/03/img_20260703_061500_021.jpg` 中提取 `img_20260703_061500_021`），对应 `GET /image/{image_id}` 二进制流端点（API 文档 §2.4.2）

**协作方式**：被 `DiseaseRecordsPage` 中的记录详情区域调用，图片源来自 `DiseaseRecord.image_path` 拼接后的完整 URL。

### 20. `ConnectivityIndicator` — 连接状态指示器

**角色**：网络连接状态的 UI 表现组件。

**职责**：
- 接收 `@Prop status: 'loading' | 'online' | 'offline'` 属性
- 渲染页面顶部细条（绿色/黄色/红色），直观展示连接状态
- 提供 `@Builder` 供页面直接嵌入 `build()` 布局

### 21. 数据模型接口（`common/models.ets`）

**角色**：业务数据的类型定义集合。

**核心接口**：

| 接口 | 描述 | 对应 API |
|------|------|---------|
| `DeviceInfo` | 设备信息（device_id, device_name, online, last_seen） | `/device/list` |
| `SensorSnapshot` | 最新环境数据快照（temperature, humidity, light, co2, soil_n/p/k, rssi, alarm_flag） | `/sensor/latest` |
| `SensorHistory` | 历史传感器数据记录（含 timestamp 和所有环境字段） | `/sensor/history` |
| `DailyAggregation` | 日聚合数据（avg/max/min 各环境指标） | `/sensor/daily` |
| `DiseaseRecord` | 病虫害记录（crop_type, disease_type, confidence, severity, linkage_risk_level, linkage_detail?, image_path） | `/disease/list` |
| `DiseaseStats` | 多维度统计（by_crop, by_severity, by_disease） | `/disease/stats` |
| `HeatmapData` | 热力图点数据 | `/disease/heatmap` |
| `CommandRequest` | 控制命令请求结构体 | `/command/send` 请求体 |
| `CommandLog` | 控制日志记录 | `/command/logs` |
| `Advisory` | 防治建议（latest_detection, current_env, env_disease_linkage, advisory） | `/advisory` |
| `ImageUploadResult` | 图片上传结果（image_id, image_path, file_size） | `/image/upload` |
| `TextResult` | 文本响应封装（statusCode, headers, rawBody: string） | `api.ets` 内部返回给 `HttpClient`（JSON 场景） |
| `BinaryResult` | 二进制响应封装（statusCode, headers, rawBody: ArrayBuffer） | `api.ets` 内部返回给 `HttpClient`（图片场景） |
| `ApiResponse<T>` | 通用 API 响应外层（code, message, data） | 所有接口 |
| `PaginatedData<T>` | 分页数据结构（pagination, records） | 分页接口 |
| `RetryPolicy` | 重试策略配置（maxRetries, baseDelayMs, maxDelayMs, retryOn, timeoutMs） | — |
| `CacheEntry<T>` | 缓存条目（data, timestamp, ttl） | — |
| `PollingCallback` | 轮询回调类型（`type PollingCallback = () => Promise<void>`） | — |

`NetworkResult` 拆分为 `TextResult` 和 `BinaryResult` 联合类型，`api.ets` 的 `request()` 返回 `TextResult`，`requestRaw()` 返回 `BinaryResult`。

---

## 关键行为契约

### 场景 A：首页加载 → 环境快照展示 + 传感器轮询 + 告警轮询

```
IndexPage.aboutToAppear()  [同步初始化]
  └─ connectivityStatus = 'loading'
  └─ isLoading = true
  └─ loadData() [异步，catch 捕获异常]
       ├─ DeviceService.getDeviceList() → 获取设备列表 → connectivityStatus = 'online' → 渲染 DeviceSelector
       ├─ SensorService.getLatest(deviceId) → 获取最新快照 → 分发至 SensorCard 组件群
       └─ PollingManager.start('index_sensor', 10000)
       │    └─ 每 10s（串行 setTimeout）: SensorService.getLatest(deviceId) → 更新 @State → render
       └─ PollingManager.start('index_alarm', 10000)
            └─ 每 10s: AdvisoryService.getAdvisory() → 解析告警 → @State alarmMessage / alarmSeverity → build() → AlarmBanner 显示

catch(e: BusinessError) 中的 connectivityStatus 维护:
  └─ 网络异常且 HttpClient 重试耗尽 → connectivityStatus = 'offline'
  └─ 业务错误（API code ≠ 0）→ 保持当前值不变

build() 条件渲染:
  ├─ isLoading=true → LoadingState 骨架屏
  ├─ errorMessage!=null → 错误状态含重新加载按钮
  └─ 正常 → 数据内容 + ConnectivityIndicator
```

### 场景 B：远程设备控制（含乐观 UI 回滚）

```
用户点击 ControlPage 的 ControlButton
  ├─ [保存前状态] @State private previousState = this.isOn
  ├─ [乐观 UI] 立即执行 this.isOn = targetState（@Link 直接写入父 @State） + 显示加载态
  ├─ [前置检查] DeviceService.getCachedDevices() 检查设备 online：
  │    ├─ 离线 → 回滚：恢复 this.isOn = previousState → toast"设备离线，无法执行操作"
  │    └─ 在线 → 继续下发
  ├─ CommandService.send(deviceId, command)
  │    ├─ HttpClient.POST('/command/send', payload)
  │    ├─ 解析响应:
  │    │    ├─ code=0 → 确认新状态（保持 @Link 当前值不变）
  │    │    ├─ code=1003 → 回滚：恢复 this.isOn = previousState → DeviceService.refreshDevices() → toast"设备离线"
  │    │    └─ 其他非0 → 回滚：恢复 this.isOn = previousState → toast"操作失败，请重试"
  │    └─ 无论成败 → 结束 ControlButton 加载态
  └─ CommandService.getLogs(deviceId) → 刷新控制日志列表
```

### 场景 C：病虫害记录分页浏览 + 图片查看

```
DiseaseRecordsPage.aboutToAppear()
  ├─ isLoading = true
  ├─ 初始化筛选条件（默认最近7天，全部类型）
  ├─ loadData() [异步]
  │    ├─ DiseaseService.getList(filters, page=1) → 加载第一页
  │    │    ├─ 响应含 pagination.total → 设置列表总条目数
  │    │    └─ 渲染 PaginatedList → ForEach → DiseaseRecord 列表
  │    └─ isLoading = false
  ├─ 用户点击某条记录 → 展开详情
  │    └─ 若有 image_path → ImageViewer { src: baseURL + image_path } 直接渲染
  └─ 用户滚动到底部 → PaginatedList 触发 getList(filters, nextPage)
       └─ 追加至现有记录列表
```

### 场景 D：仪表盘实时数据刷新

```
DashboardPage.aboutToAppear()
  ├─ isLoading = true
  ├─ loadData() [异步]
  │    ├─ SensorService.getLatest(deviceId) → SensorCard 群组刷新（含数据时间戳）
  │    ├─ SensorService.getHistory(deviceId, timeRange) → ChartView 折线图渲染（LineChartRenderer）
  │    └─ isLoading = false
  └─ PollingManager.start('dashboard_sensor', 10000)
       └─ 每 10s（串行 setTimeout）: SensorService.getLatest() → 更新 @State → SensorCard 刷新
```

### 场景 E：页面切换与轮询生命周期管理

```
页面 A → router.pushUrl('pages/B')
  ├─ 页面 A [不触发 aboutToDisappear] → 轮询继续运行（key 不同，与 B 共存）
  ├─ 页面 B.aboutToAppear() → PollingManager.start('B相关key')
  └─ PollingManager 允许多 key 共存

页面 A → router.replaceUrl('pages/B') 或 router.back()
  ├─ 页面 A.aboutToDisappear() → PollingManager.stop('A相关key')
  └─ 页面 B.aboutToAppear() → PollingManager.start('B相关key')

应用进入后台: EntryAbility.onBackground() → PollingManager.suspendAll() 暂停所有轮询
应用回到前台: EntryAbility.onForeground() → PollingManager.resumeAll() 恢复所有轮询
```

### 场景 F：设备切换级联刷新

```
DeviceSelector 触发 onDeviceChange(newDeviceId)
  ├─ 更新父页面 @State selectedDeviceId = newDeviceId
  ├─ 重新调用依赖 device_id 的 Service:
  │    ├─ SensorService.getLatest(newDeviceId) → 更新 SensorCard 群组
  │    ├─ SensorService.getHistory(newDeviceId, timeRange) → 更新 ChartView [DashboardPage]
  │    ├─ DiseaseService.getList({deviceId: newDeviceId}) → 刷新记录列表 [DiseaseRecordsPage]
  │    ├─ AdvisoryService.getAdvisory(newDeviceId) → 刷新建议 [AdvisoryPage]
  │    └─ CommandService.getLogs(newDeviceId) → 刷新控制日志 [ControlPage]
  ├─ PollingManager 重启依赖 device_id 的轮询（使用新 device_id）
  └─ 跨页面传递：device_id 变更后通过 router.replaceUrl({ params: { deviceId: newId } }) 携带新 ID，
     目标页面在 aboutToAppear 中从 router.getParams() 获取最新 device_id
```

---

## 错误处理策略

### 错误分类

| 类别 | 来源 | 处理方式 |
|------|------|---------|
| **网络连接失败** | `http.request()` 抛出异常（无网络、超时、DNS 解析失败） | 在 `api.ets` 层统一 `catch` 为结构化错误，`HttpClient` 触发指数退避重试（幂等请求至多 3 次，非幂等不做重试）；重试耗尽后传递至 Service 层；页面层根据 `connectivityStatus` 展示离线 UI |
| **HTTP 非 200 状态码** | 服务端返回 4xx/5xx | `HttpClient` 根据状态码映射为 `ApiResponse` 中的 `code` 字段；408/429/502/503/504 触发重试（需在 `RetryPolicy.retryOn` 中） |
| **业务错误码** | API `response.code ≠ 0`，具体码值：1001（参数校验失败）、1002（资源不存在）、1003（设备离线）明确提示；1004（API Key 无效）、1005（频率限制）、2001（数据库错误）、3001（IoTDA 调用失败）、5000（服务器内部错误）统一提示"服务异常，请稍后重试" |
| **JSON 解析失败** | 响应体非预期格式 | `HttpClient` 层 `try-catch`，返回格式错误信号，页面层提示"数据格式异常" |
| **图片格式异常** | 图片数据非预期格式或损坏 | `ImageService` 返回失败信号，`ImageViewer` 组件展示"图片加载失败"占位 |
| **UI 操作错误** | 用户快速重复点击、在离线状态下操作 | 组件层防重复点击（加载态禁用按钮）+ 操作前通过 `DeviceService` 检查设备状态 |

### 弱网韧性策略

| 维度 | 策略 |
|------|------|
| **请求重试** | `HttpClient` 实现指数退避重试（baseDelayMs=1000, maxDelayMs=10000, maxRetries=3），仅幂等 GET 请求重试，非幂等 POST 不做重试 |
| **本地缓存** | `CacheManager` 提供通用内存缓存，各 Service 在成功获取数据后缓存；网络失败时优先返回缓存数据并标记"数据可能非最新"；传感器数据默认 TTL 30s |
| **离线 UI** | 每个页面增加 `@State connectivityStatus`，`ConnectivityIndicator` 在页面顶部展示绿/黄/红细条；`SensorCard` 展示数据时间戳帮助判断新鲜度 |
| **轮询与重试交互** | `PollingManager` 采用串行模式（递归 `setTimeout`），上一个 tick 完全结束后再调度下一个；轮询回调中的重试在写入缓存时检查页面销毁标记 |

### `connectivityStatus` 状态转换矩阵

| 当前状态 | 触发事件 | 下一状态 | 说明 |
|---------|---------|---------|------|
| `'online'` | 页面 `aboutToAppear` | `'loading'` | 开始加载数据，`ConnectivityIndicator` 显示黄色 |
| `'loading'` | Service 调用成功 | `'online'` | 数据获取成功，恢复在线标识（绿色） |
| `'loading'` | 网络异常 + 重试耗尽 | `'offline'` | 连续失败，标记离线（红色） |
| `'offline'` | 后续 Service 调用成功 | `'online'` | 网络恢复，标记重新在线（绿色） |
| `'offline'` | 后续 Service 再次失败 | `'offline'` | 连续离线，保持离线标识 |
| `'loading'` / `'online'` / `'offline'` | 业务错误（API code ≠ 0） | 保持当前值不变 | 业务错误不影响连接状态判定 |

**转换规则**：
- 初始值：`'online'`（避免启动时闪白）；`aboutToAppear` 中设置为 `'loading'`
- `loadData()` 中每个 Service 调用成功后设置 `'online'`
- `catch((err: BusinessError)` 中判断：err 为网络异常（`@ohos.net.http` 抛出的原生错误）且 HttpClient 重试耗尽 → `'offline'`；err 为业务错误码（API 返回的非 0 code）→ 保持当前值
- 状态转换仅在每个页面的 `loadData()` 统一 catch 中维护，拒绝模块级 `globalConnectivity` 方案

### 用户反馈策略

- **网络/服务异常**：`promptAction.showToast({ message: '网络异常，请检查连接', duration: 2000 })`
- **设备离线**：`promptAction.showToast({ message: '设备离线，无法执行操作', duration: 2000 })`
- **操作成功**：`promptAction.showToast({ message: '{命令}已{开启/关闭}', duration: 1500 })`
- **乐观 UI 回滚（设备离线）**：`promptAction.showToast({ message: '设备离线，操作未能执行', duration: 2000 })`
- **乐观 UI 回滚（其他失败）**：`promptAction.showToast({ message: '操作失败，请重试', duration: 2000 })`
- **数据为空**：在 UI 上展示空状态占位图，而非 toast
- **操作进行中**：按钮内嵌 `Progress` 组件，禁用重复点击

---

## 并发设计

### 线程模型

ArkTS 运行在 ArkUI 的主 UI 线程上，所有 UI 操作和状态更新必须在主线程执行。网络请求通过 `@ohos.net.http` 的回调异步模型处理。

- **网络请求**：使用 `async/await` 语法，不阻塞 UI 线程
- **轮询**：`PollingManager` 内部使用递归 `setTimeout` 串行调度，每个回调函数内部 `await` 网络请求，上一个 tick（含重试）完全结束后再调度下一个
- **重试**：`HttpClient` 内部的指数退避重试使用 `setTimeout` 延迟执行，不阻塞轮询的串行调度
- **状态更新**：所有 `@State` 变量的修改在 `await` 之后恢复的同步上下文中执行，天然在主线程

### 轮询调度约束

| 页面 | 轮询key | 间隔 | 触发条件 | 停止条件 |
|------|---------|------|---------|---------|
| IndexPage | `index_alarm` | 10s | 页面出现 | 页面消失（replaceUrl/back） |
| IndexPage | `index_sensor` | 10s | 页面出现 | 页面消失 |
| DashboardPage | `dashboard_sensor` | 10s | 页面出现 | 页面消失 |
| AdvisoryPage | `advisory_refresh` | 10s | 页面出现 | 页面消失 |

`PollingManager` 确保：
1. 同一 key 不会重复注册（已存在的先清除再新建）
2. **串行模式**：使用递归 `setTimeout`，上一个 tick 完全结束后再调度下一个周期，消除 `setInterval` 与重试的竞争
3. 所有轮询在应用进入后台时通过 `EntryAbility.onBackground()` → `PollingManager.suspendAll()` 暂停
4. 应用回到前台时通过 `EntryAbility.onForeground()` → `PollingManager.resumeAll()` 恢复
5. `pushUrl` 场景下页面隐藏但未销毁，轮询继续运行（key 不同允许多 key 共存）；`replaceUrl`/`back` 场景下触发销毁，停止对应轮询

### 共享状态管理

- 所有网络请求结果通过 `@State` 局部状态持有，不共享跨页面全局状态
- API Key 通过模块级常量持有（只在 `HttpClient` 初始化时读取一次）
- 设备选择结果通过 `@Link selectedDeviceId` 双向绑定 + `router` 的 URL 参数传递（多设备场景下跨页面共享设备 ID）
- `CacheManager` 作为模块级单例，在 Service 层共享缓存数据

---

## 设计决策

### 决策 1：服务层独立于 UI 层

**选择**：所有 HTTP 交互封装在 `services/` 目录下独立的类中，页面不直接调用 `@ohos.net.http`。

**理由**：
- ArkTS 不支持继承体系，但支持模块级导入和函数导出，Service 以模块级实例（单例）方式暴露给页面
- Service 的职责边界清晰，便于单元测试和替换（如后续切换为 WebSocket）
- 页面仅需关注状态和 UI 渲染，降低页面代码复杂度

### 决策 2：`PollingManager` 集中管理轮询

**选择**：使用 `PollingManager` 统一管理所有轮询任务，而非各页面各自 `setInterval`。

**理由**：
- ArkTS 中 `setInterval` 的 ID 无法被其他页面感知，页面切换时旧页面的定时器可能残留
- 集中管理可以统一响应应用前后台切换事件（`EntryAbility.onBackground/onForeground`）
- 符合单一职责原则：轮询调度逻辑不与 UI 生命周期耦合

### 决策 3：数据模型使用 `interface` 而非 `class`

**选择**：使用 ArkTS `interface` 定义所有数据模型。

**理由**：
- API 返回的 JSON 直接通过 `JSON.parse()` 解析为普通对象，天然匹配 `interface` 的结构化类型
- ArkTS 中 `class` 需要额外构造函数和序列化/反序列化代码，对纯数据传输场景过度设计
- `interface` 在编译期提供类型检查，运行时无开销

### 决策 4：组件通过 `@Prop` / `@Link` 实现数据流

**选择**：父 → 子用 `@Prop`（只读），父子双向用 `@Link`（通过 `$variable` 语法传递引用）。

**理由**：
- ArkUI 的设计范式要求组件的输入通过装饰器显式声明，这与 `@Prop` / `@Link` 的语义一致
- `SensorCard` 等展示型组件只需要 `@Prop`（父→子单向数据流）
- `ControlButton` 需要乐观 UI 翻转，使用 `@Link` 使子组件具备修改父组件状态的能力

### 决策 5：`@State` 本地状态而非全局状态管理

**选择**：不使用跨页面状态管理库，每个页面独立管理自己的状态。

**理由**：
- 鸿蒙 App 页面数有限（5页），页面间共享状态少（主要是 device_id 的选择）
- 跨页面共享的 device_id 通过 `router.pushUrl({ params: { deviceId } })` 的参数传递 + `DeviceSelector` 的 `@Link selectedDeviceId` 双向绑定
- 引入全局状态管理（如类似 Redux 的模式）在 ArkTS 中缺乏成熟支持，且对此规模项目过度设计

### 决策 6：告警轮询使用 AdvisoryService 而非独立告警接口

**选择**：轮询调用 `GET /advisory` 而非创建专门的告警接口。

**理由**：
- 后端 API 设计通过 `/advisory` 综合返回最新检测和建议
- 省去额外的告警端点，减少服务端部署复杂度
- 一次请求即可同时获取告警状态和防治建议，适合 10s 间隔的轮询

### 决策 7：命令下发采取乐观 UI 更新（含设备状态漂移回滚）

**选择**：点击控制按钮后立即将 UI 切换为目标状态，再等待服务端响应；失败时回滚并更新缓存。

**理由**：
- 减少用户感知延迟，提高操作响应感
- 操作前保存 `@State previousState`，失败时回滚并向 `DeviceService.refreshDevices()` 发送缓存失效信号
- 与参考项目 `DisplayPage.ets` 中灯控制的模式一致

### 决策 8：`api.ets` 与 `HttpClient` 的两层 HTTP 封装

**选择**：保留 `common/api.ets` 作为 `@ohos.net.http` 的原始封装，`services/HttpClient.ets` 在其基础上构建业务门面。

**理由**：
- 避免将 `@ohos.net.http` 的原始 API（`createHttp`/`destroy`/`RequestMethod`）暴露到 Service 层，`api.ets` 承担适配器角色
- 若鸿蒙 SDK 的 `@ohos.net.http` API 发生 breaking change，修改仅限 `api.ets`
- `HttpClient` 专注于业务语义（认证、路径、JSON、错误码），不关注传输细节
- 两者之间的调用关系清晰可测：单元测试时可直接 mock `api.ets` 层验证 `HttpClient` 的业务逻辑

### 决策 9：`ImageService` 独立于传输架构 + `image_path` 双路径方案

**选择**：`ImageViewer` 采用"主路径 + 降级路径"双路径方案。主路径基于 `Image(src)` 直接加载 `baseURL + image_path`（API 文档 §2.4.1 明确 `image_path` 为"公开 URL"），降级路径在 `Image` 组件 `onError` 时通过 `GET /image/{image_id}` 获取二进制流 → `PixelMap` 解码链渲染。`ImageService` 通过 `HttpClient` 的 `multipart` 参数执行上传。

**理由**：
- API 文档（§2.4.1 上传响应注释）明确说明"系统会自动将该记录的 `image_path` 字段更新为上传图片的公开 URL"，是支持直接 URL 加载的直接证据；`GET /image/{image_id}`（§2.4.2）作为二进制流备用端点存在
- 主路径零额外复杂度：若 `image_path` 可公开访问，`ImageViewer` 无需 `ImageService.getImage()`，无需 `ArrayBuffer` → `PixelMap` 解码链
- 降级路径提升韧性：`Image(src)` 可能因 CDN 配置、路径变更等不可控因素失败，`onError` 后通过 `image_id` 从二进制端点获取确保可用性
- `image_id` 可从 `image_path` 的文件名段解析（如 `img_20260703_061500_021`），无需额外 API 字段
- 图片上传的 `multipart/form-data` 格式与 JSON API 在请求体构建和 Content-Type 上有本质差异，不适合复用通用 JSON 序列化路径
- `HttpClient` 的 `post()` 方法新增 `multipart` 可选参数，当 `ImageService` 调用时传入，内部走 `api.ets.requestMultipart()` 路径

### 决策 10：弱网韧性基础设施独立于业务层

**选择**：`RetryPolicy` 和 `CacheManager` 位于 `common/` 层，作为基础设施被 `HttpClient` 和各 Service 使用。

**理由**：
- `RetryPolicy` 的重试逻辑与 `HttpClient` 的业务门面职责耦合——重试关注的是传输失败的恢复策略，应在 `HttpClient` 内部实现，`RetryPolicy` 仅提供配置结构
- `CacheManager` 作为通用缓存管理器，可被多个 Service 复用（`SensorService` 缓存传感器数据、`DeviceService` 缓存设备列表），避免各 Service 重复实现缓存逻辑
- 独立于业务层意味着缓存和重试策略的修改不影响业务 Service 的接口和调用方

### 决策 11：`PollingManager` 串行模式治理轮询与重试竞争

**选择**：`PollingManager` 使用递归 `setTimeout` 替代 `setInterval`，确保上一个 tick（含重试）完全结束后再调度下一个。

**理由**：
- `setInterval` 不等待回调完成，与 `HttpClient` 的指数退避重试存在竞争（并发请求、UI 状态竞争、带宽浪费、缓存竞争）
- 串行模式消除竞争：每个轮询 tick 是一个 Promise 链，resolve 后调度下一个 10s
- 适用于 IoT 弱网场景，避免重试与轮询的累积效应

### 决策 12：`DiseaseService` 的方法签名一致性

`DiseaseService` 的 `getStats()` 和 `getHeatmap()` 在核心抽象中显式定义，与 `SensorService.getDaily()` 的方法签名模式一致。

### 决策 13：`ControlButton` 选用 `@Link` 而非 `@Prop` 实现乐观 UI

**选择**：`ControlButton` 通过 `@Link` 接收 `isOn` 状态，乐观 UI 通过 `this.isOn = targetState` 直接修改父组件状态。

**理由**：
- ArkUI API 21 中 `@Prop` 为只读装饰器，子组件无法对其赋值；乐观 UI 需要子组件主动翻转状态，`@Prop` 语义不匹配
- `@Link` 通过 `$isOn` 传递引用，子组件写入即反映到父组件的 `@State`，语义清晰且无间接开销
- 不依赖 `aboutToUpdate`（ArkUI API 21 不存在此生命周期）

### 决策 14：纯页面级 `connectivityStatus` 状态管理

**选择**：每个页面独立维护 `@State connectivityStatus`，采用统一的状态转换矩阵，拒绝模块级 `globalConnectivity` 方案。

**理由**：
- 每个页面的网络数据独立性较强（不同页面调用不同 Service），全局状态无法反映单个页面的实际网络可达性
- 页面级 `@State` 转换矩阵规则统一（均在 `loadData()` 的 catch 中维护），行为可预测
- 避免了全局状态引入的跨页面状态同步复杂度

### 决策 15：`CommandService` → `DeviceService.refreshDevices()` 硬耦合

**选择**：`CommandService` 失败路径直接调用 `DeviceService.refreshDevices()` 更新缓存。

**理由**：
- 设备状态失效后立即刷新是强时序相关性操作——若通过事件解耦，刷新可能延迟导致后续操作仍基于过期状态
- 两个 Service 同属 `services/` 层，跨 Service 直接调用在 v1.0 阶段可接受
- 后续架构升级时可通过事件机制解耦（如发布 Channel 事件让 DeviceService 自行订阅）

---

## 修订说明（v5）

| 审查意见 | 修改措施 |
|---------|---------|
| **N1**: `ControlButton` 乐观 UI 状态管理机制未闭合（`@Prop` 为只读） | 核心抽象 §16 `ControlButton`：`@Prop isOn` 改为 `@Link isOn`，乐观 UI 通过 `this.isOn = targetState` 直接修改父组件状态；补充 `@Link` 决策说明（决策 13）；移除 `aboutToUpdate` 引用；同步更新场景 B 中乐观 UI 翻转描述 |
| **N2**: 各页面 `connectivityStatus` 完整状态转换闭环未定义 | 错误处理策略中新增完整的「`connectivityStatus` 状态转换矩阵」（含 loading→online→offline→online 闭环）；核心抽象 §12 统一 catch 中补充三条转换规则；初始值从 `'loading'` 改为 `'online'`，`aboutToAppear` 设为 `'loading'`；决策 14 记录此选择 |
| **N3**: `AlarmBanner` 缺少核心抽象定义 | 新增核心抽象 §17 `AlarmBanner`：定义 `@Prop message: string`、`@Prop severity: 'mild' \| 'moderate' \| 'severe'`、告警展示逻辑和点击跳转/可关闭交互行为 |
| **N4**: `PollingManager` 串行模式定时漂移行为未标注 | 核心抽象 §9 `PollingManager` 职责描述中补充串行定时策略说明：每个 tick 完成后以 `setTimeout(fn, interval)` 调度下一个；标注有效轮询频率公式和弱网场景下的设计意图 |
| **N5**: 页面核心抽象中 `@State alarmMessage/alarmSeverity` 缺失声明 | 核心抽象 §12 页面组件的 `@State` 列表中补充 `@State private alarmMessage: string` 和 `@State private alarmSeverity: 'mild' \| 'moderate' \| 'severe'` |
| **N6**: `catch((err: Error)` 不符 ArkTS 约定 | 核心抽象 §12 中 `catch((err: Error)` 统一替换为 `catch((err: BusinessError)`；场景 A 同步更新；`BusinessError` 从 `@kit.BasicServicesKit` 导入 |
| **M1**: `PollingCallback` 显式类型定义缺失 | 核心抽象 §9 `PollingManager.start(key, fn, interval)` 中 `fn` 参数标注为 `PollingCallback` 类型；`common/models.ets` 中新增 `export type PollingCallback = () => Promise<void>` 显式导出定义 |
| **S1**: `CacheManager` 缓存键空间共享冲突 | 核心抽象 §11 `CacheManager` 中补充缓存键命名约定：各 Service 使用统一前缀命名空间（如 `sensor_latest_`、`device_list_`、`advisory_` 等） |
| **S3**: `DiseaseRecord` 模型缺少 `linkage_detail` 字段 | 核心抽象 §21 `DiseaseRecord` 接口描述中补充 `linkage_detail?: string` 可选字段 |
| **S4**: `SensorService.getLatest()` 未注明 `deviceId` 可选行为 | 核心抽象 §3 `SensorService.getLatest(deviceId)` 中补充 `deviceId` 为空时的行为约定：空值视为"查询全部"，Service 不拼接 `device_id` 查询参数 |
| **S6**: `CommandService` 硬引用 `DeviceService.refreshDevices()` 的 ad-hoc 耦合 | 核心抽象 §5 `CommandService` 中补充已知耦合说明；新增决策 15 记录此耦合在 v1.0 阶段可接受并标注后续事件解耦方向 |

---

## 修订说明（v6）

| 审查意见 | 修改措施 |
|---------|---------|
| **问题 1（一般 — §12 `connectivityStatus` 类型不匹配）**：`@State connectivityStatus: 'online' \| 'offline'` 类型定义未包含 `'loading'` 状态值，但 `aboutToAppear` 中赋值 `'loading'`，ArkTS 编译器报错 | 将核心抽象 §12 中 `connectivityStatus` 类型声明从 `'online' \| 'offline'` 修正为 `'loading' \| 'online' \| 'offline'`；同步确保 `ConnectivityIndicator` §20 的 `@Prop status` 类型与此一致（原设计已正确为 `'loading' \| 'online' \| 'offline'`，无需修改）；状态转换矩阵中所有引用保持统一 |
| **问题 2（一般 — §19 `image_path` URL 直接访问假设未充分验证）**：设计假设 `baseURL + image_path` 可被 `Image(src)` 直接加载，但 API 文档（§2.4.2）提供了 `GET /image/{image_id}` 二进制流端点，未明确 `image_path` 是否可直接公开访问 | 将 §19 `ImageViewer` 从单一路径改为"主路径 + 降级路径"双路径方案：主路径保留 `Image(src)` 直接加载（API 文档 §2.4.1 明确标注 `image_path` 为"公开 URL"）；降级路径在 `onError` 时通过 `image_id` 从 `GET /image/{image_id}` 二进制端点获取 `PixelMap`；同步更新决策 9 补充双路径理由，标注 `image_id` 从 `image_path` 文件名段解析 |

---

```
DESIGN_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\a_v3_design_v2.md
主Agent请勿阅读产出文件内容，直接将路径转发给相关方。
```
