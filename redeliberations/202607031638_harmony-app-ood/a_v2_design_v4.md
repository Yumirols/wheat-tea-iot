# 农眼卫士 FarmEye Guard v1.0 — 鸿蒙移动应用 OOD 设计方案（v4）

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
│   ├── AlarmBanner.ets           # 告警横幅（实时告警推送展示）
│   ├── ControlButton.ets         # 控制按钮（ON/OFF 双态按钮，含加载态和 previousState 保存）
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
│   ├── models.ets                # 数据模型：响应结构、业务实体 interface 定义
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
- 在页面 `aboutToAppear` / `aboutToDisappear` 生命周期中控制轮询的启动与停止
- **串行模式**：使用递归 `setTimeout` 替代 `setInterval`，上一个 tick（含重试）完全结束后再调度下一个周期
- 同一 key 不会重复注册（已存在的先清除再新建）
- 每个 tick 通过 try-catch 包裹回调执行
- 在 `EntryAbility.onBackground()` / `onForeground()` 中统一暂停和恢复所有轮询

### 10. `RetryPolicy` — 重试策略定义（v4 新增）

**角色**：弱网韧性基础设施的配置定义。

**职责**：
- 定义重试策略的配置结构：`maxRetries`, `baseDelayMs`, `maxDelayMs`, `retryOn`（可重试 HTTP 状态码列表）, `timeoutMs`
- 被 `HttpClient` 用于实现指数退避重试逻辑

**类型形态选择理由**：选择为纯类型定义（interface）+ 默认值常量导出，因为重试策略是纯配置结构，无需行为逻辑。

### 11. `CacheManager` — 通用内存缓存管理器（v4 新增）

**角色**：通用内存缓存基础设施。

**职责**：
- 提供 `CacheEntry<T>` 结构（`data: T, timestamp: number, ttl: number`）
- 提供 `set(key, data, ttl?)` / `get(key)` / `invalidate(key)` / `clear()` 接口
- 自动失效超过 TTL 的缓存项
- 被各 Service 用于缓存最后一次成功获取的数据

**类型形态选择理由**：选择为模块级管理器的单例形态，因为缓存数据需要在 Service 的多次方法调用间共享，模块级导出天然满足。

### 12. 页面组件（`IndexPage` / `DashboardPage` / `DiseaseRecordsPage` / `ControlPage` / `AdvisoryPage`）

**角色**：ArkUI 视图层的 `@Entry` 页面。

**职责**：
- 声明 `@State` 装饰的本地状态（UI 渲染数据）：每个页面增加 `@State private isLoading: boolean`、`@State private errorMessage: string | null`、`@State private connectivityStatus: 'loading' | 'online' | 'offline'`
- 在同步的 `aboutToAppear()` 中通过非 async 方式触发 `loadData()` 异步方法：
  ```
  aboutToAppear() {
    this.isLoading = true
    this.loadData().catch((err: Error) => {
      this.isLoading = false
      this.errorMessage = '数据加载失败'
      promptAction.showToast({ message: '加载失败，请下拉刷新', duration: 2000 })
    })
  }
  ```
- `loadData()` 统一返回 `Promise<void>`，函数体内部的 try-catch 捕获同步段异常并转为 `Promise.reject`
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

### 14. `ChartView` — 历史趋势图表（v4 重构：渲染器分离架构）

**角色**：传感器历史数据的可视化组件。

**职责**：
- 通过 `@Prop chartType: 'line' | 'bar'` 切换渲染器实例
- 通过 `ChartRendererAPI` 接口委托实际绘制逻辑给具体渲染器
- 接收数据点数组作为输入

**协作方式**：被 `DashboardPage` 调用，数据源来自 `SensorService.getHistory()`。`ChartView` 不直接依赖 Canvas 操作，通过 `ChartRendererAPI` 接口与渲染器解耦。v1.0 最小可用版本：仅实现 `LineChartRenderer`（单 Y 轴单折线，无触摸交互），`BarChartRenderer` 预留架构后续实现。

### 15. `ChartRendererAPI` — 图表渲染器接口（v4 新增）

**角色**：图表渲染策略的行为契约。

**职责**：定义渲染器的统一接口，包括 `render(ctx, data, width, height)` 绘制方法和可选的 `onTouch(x, y)` 交互方法。

`LineChartRenderer` 和 `BarChartRenderer` 分别实现此接口，`ChartView` 通过 `@Prop chartType` 切换渲染器实例。

### 16. `ControlButton` — 双态控制按钮（含乐观 UI 回滚）

**角色**：设备 ON/OFF 控制的操作组件。

**职责**：
- 接收当前状态（on/off）、设备 ID、命令类型作为属性
- 操作前保存当前状态到 `@State private previousState: boolean`
- 乐观 UI：点击后立即切换为目标状态并显示加载态
- 显示当前状态文案（"已开启"/"已关闭"）
- 失败时回滚：恢复为 `previousState`，根据错误类型展示差异化 toast（"设备离线" vs "操作失败"）
- 错误时通过 `promptAction.showToast()` 反馈

**协作方式**：被 `ControlPage` 复用，每个实例对应一个执行机构（喷淋/灌溉/蜂鸣器/LED）。

### 17. `PaginatedList` — 分页列表容器

**角色**：支持无限滚动的分页列表组件。

**职责**：
- 接收分页加载回调函数作为属性
- 管理加载更多、加载中、无更多数据三种状态
- 在滚动到底部时自动触发下一页加载

**协作方式**：被 `DiseaseRecordsPage` 使用，加载函数指向 `DiseaseService.getList()`。

### 18. `ImageViewer` — 病虫害图片查看器（v4 明确 URL 路径）

**角色**：病虫害记录关联图片的展示组件。

**职责**：
- **基于 API 文档确认的假设**：`DiseaseRecord.image_path` 为服务端返回的 URL 路径（如 `/images/2026/07/03/img_xxx.jpg`），可通过 `baseURL + image_path` 拼接为完整 URL 供 `Image` 组件直接加载
- 接收图片 URL 作为 `@Prop` 属性
- 在图片容器中使用 `<Image src={fullImageUrl}>` 渲染网络图片，ArkUI 原生支持
- 展示加载中、加载失败、空状态三种占位效果
- 此路径下无需 `ImageService.getImage()`，无需 `ArrayBuffer` → `PixelMap` 解码链，零额外复杂度

**备用路径**（若后端改为 image_id 语义）：需增加 `ImageService.getImagePixelMap(imageId)` 完成 `ArrayBuffer` → `ImageSource` → `PixelMap` 解码链，`ImageViewer` 通过 `@Prop` 接收 `PixelMap` 对象。当前设计基于 URL 路径，备用路径作为设计预留。

**协作方式**：被 `DiseaseRecordsPage` 中的记录详情区域调用，图片源来自 `DiseaseRecord.image_path` 拼接后的完整 URL。

### 19. `ConnectivityIndicator` — 连接状态指示器（v4 新增）

**角色**：网络连接状态的 UI 表现组件。

**职责**：
- 接收 `@Prop status: 'loading' | 'online' | 'offline'` 属性
- 渲染页面顶部细条（绿色/黄色/红色），直观展示连接状态
- 提供 `@Builder` 供页面直接嵌入 `build()` 布局

### 20. 数据模型接口（`common/models.ets`）

**角色**：业务数据的类型定义集合。

**核心接口**：

| 接口 | 描述 | 对应 API |
|------|------|---------|
| `DeviceInfo` | 设备信息（device_id, device_name, online, last_seen） | `/device/list` |
| `SensorSnapshot` | 最新环境数据快照（temperature, humidity, light, co2, soil_n/p/k, rssi, alarm_flag） | `/sensor/latest` |
| `SensorHistory` | 历史传感器数据记录（含 timestamp 和所有环境字段） | `/sensor/history` |
| `DailyAggregation` | 日聚合数据（avg/max/min 各环境指标） | `/sensor/daily` |
| `DiseaseRecord` | 病虫害记录（crop_type, disease_type, confidence, severity, linkage_risk_level, image_path） | `/disease/list` |
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

`NetworkResult` 拆分为 `TextResult` 和 `BinaryResult` 联合类型，`api.ets` 的 `request()` 返回 `TextResult`，`requestRaw()` 返回 `BinaryResult`。

---

## 关键行为契约

### 场景 A：首页加载 → 环境快照展示 + 传感器轮询 + 告警轮询

```
IndexPage.aboutToAppear()  [同步初始化]
  └─ isLoading = true
  └─ loadData() [异步，catch 捕获异常]
       ├─ DeviceService.getDeviceList() → 获取设备列表 → 渲染 DeviceSelector
       ├─ SensorService.getLatest(deviceId) → 获取最新快照 → 分发至 SensorCard 组件群
       ├─ PollingManager.start('index_sensor', 10000)   [v4 新增]
       │    └─ 每 10s（串行 setTimeout）: SensorService.getLatest(deviceId) → 更新 @State → render
       └─ PollingManager.start('index_alarm', 10000)
            └─ 每 10s: AdvisoryService.getAdvisory() → 解析告警 → @State alarmMessage / alarmSeverity → build() → AlarmBanner 显示

build() 条件渲染:
  ├─ isLoading=true → LoadingState 骨架屏
  ├─ errorMessage!=null → 错误状态含重新加载按钮
  └─ 正常 → 数据内容 + ConnectivityIndicator
```

### 场景 B：远程设备控制（含乐观 UI 回滚）

```
用户点击 ControlPage 的 ControlButton
  ├─ [保存前状态] @State private previousState = this.isOn
  ├─ [乐观 UI] 立即切换 ControlButton 为目标状态 + 显示加载态（Progress 组件内嵌）
  ├─ [前置检查] DeviceService.getCachedDevices() 检查设备 online：
  │    ├─ 离线 → 回滚：恢复 previousState → toast"设备离线，无法执行操作"
  │    └─ 在线 → 继续下发
  ├─ CommandService.send(deviceId, command)
  │    ├─ HttpClient.POST('/command/send', payload)
  │    ├─ 解析响应:
  │    │    ├─ code=0 → 确认 ControlButton 新状态
  │    │    ├─ code=1003 → 回滚：恢复 previousState → DeviceService.refreshDevices() 更新缓存 → toast"设备离线"
  │    │    └─ 其他非0 → 回滚：恢复 previousState → toast"操作失败，请重试"
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
  │    │    └─ 渲染 PaginatedList → ForEach → DiseaseRecord 列表 [L2: ForEach 显式引用]
  │    └─ isLoading = false
  ├─ 用户点击某条记录 → 展开详情
  │    └─ 若有 image_path → ImageViewer { src: baseURL + image_path } 直接渲染 [H1: URL 路径]
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
  │    │    [H2: v1.0 仅单 Y 轴折线，ChartRendererAPI 接口预留柱状图]
  │    └─ isLoading = false
  └─ PollingManager.start('dashboard_sensor', 10000)
       └─ 每 10s（串行 setTimeout）: SensorService.getLatest() → 更新 @State → SensorCard 刷新
```

### 场景 E：页面切换与轮询生命周期管理（v4 修正版）

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

### 场景 F：设备切换级联刷新（v4 新增）

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
- `ControlButton` 需要展示加载态和执行结果反馈，使用 `@Link` 实现父子状态同步

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

### 决策 9：`ImageService` 独立于传输架构 + `image_path` URL 假设

**选择**：基于 API 文档确认 `DiseaseRecord.image_path` 为 URL 相对路径，`ImageViewer` 采用 `<Image src={baseURL + image_path}>` 直接加载。`ImageService` 通过 `HttpClient` 的 `multipart` 参数执行上传。

**理由**：
- 若 `image_path` 为 URL 路径，`ImageViewer` 无需 `ImageService.getImage()`，无需 `ArrayBuffer` → `PixelMap` 解码链，零额外复杂度
- 图片上传的 `multipart/form-data` 格式与 JSON API 在请求体构建和 Content-Type 上有本质差异，不适合复用通用 JSON 序列化路径
- `HttpClient` 的 `post()` 方法新增 `multipart` 可选参数，当 `ImageService` 调用时传入，内部走 `api.ets.requestMultipart()` 路径
- 备用路径（image_id 语义）作为设计预留，若后端变更需增加 `ImageService.getImagePixelMap(imageId)` + `PixelMap` 解码链

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

---

## 修订说明（v4）

| 审查意见 | 修改措施 |
|---------|---------|
| **H1**: `ImageViewer` 图片展示路径未明确 `image_path` 语义 | 核心抽象 §18（ImageViewer）中明确采纳 URL 路径假设（基于 API 文档 `image_path` 为 `/images/YYYY/MM/DD/img_xxx.jpg` 格式），`ImageViewer` 采用 `<Image src={baseURL + image_path}>` 直接加载，零额外复杂度；同时标注备用路径（image_id → PixelMap 解码链）作为设计预留；场景 C 同步修正为 URL 路径流程 |
| **H2**: `ChartView` 缺少原生图表组件，Canvas 实现复杂度未评估 | 新增 `ChartRendererAPI` 接口（核心抽象 §15）定义渲染器契约；新增 `LineChartRenderer`（v1.0 最小可用：单 Y 轴单折线，无触摸交互）和 `BarChartRenderer`（架构预留）；`ChartView` 核心抽象 §14 重构为通过 `@Prop chartType` 切换渲染器实例；在场景 D 中标注 v1.0 仅折线图 |
| **H3**: `ImageService` multipart/form-data 上传路径在错误层次 | 修正为 `common/api.ets` 新增 `buildFormData()` + `requestMultipart()`；`HttpClient.post()` 新增 `multipart?` 可选参数，当存在时走 `requestMultipart()` 路径；`ImageService.upload()` 内部组装 `fields` 结构调用 `HttpClient.post()` 的 multipart 模式 |
| **H4**: `api.ets` 缺少二进制响应路径 | `api.ets` 新增 `requestRaw(url, options)` 方法（`expectDataType: ARRAY_BUFFER`）；`NetworkResult` 拆分为 `TextResult{rawBody: string}` / `BinaryResult{rawBody: ArrayBuffer}` 联合类型；`HttpClient.getRaw()` 通过 `requestRaw()` 获取 `ArrayBuffer` |
| **H5**: `aboutToAppear` 同步约束 + `pushUrl` 不触发 `aboutToDisappear` | 核心抽象 §12（页面组件）补充 `@State isLoading` / `@State errorMessage` / `@State connectivityStatus`；`aboutToAppear` 通过非 async 方式触发 `loadData()` 并 catch 异常；`loadData()` 内部 try-catch 捕获同步段异常转为 `Promise.reject`；场景 E 修正：`pushUrl` 不停止轮询（页面未销毁），`replaceUrl`/`back` 停止；`EntryAbility.onBackground()` 统一 `suspendAll()` |
| **H6**: 设备切换级联刷新路径未定义 | `DeviceSelector` 补充 `@Link selectedDeviceId` + `onDeviceChange` 回调定义；新增场景 F（设备切换级联刷新）完整契约；定义跨页面 device_id 传递策略（`router.replaceUrl` + `aboutToAppear` 获取） |
| **H8**: 乐观 UI 回滚未覆盖设备状态漂移 | `ControlButton` 核心抽象补充操作前保存 `@State previousState`；场景 B 补充回滚路径：`code=1003` → 恢复 `previousState` → `DeviceService.refreshDevices()` 更新缓存 → 差异化 toast；`CommandService` 失败路径补充缓存失效信号 |
| **H9**: IndexPage 首页缺少传感器数据轮询 | 场景 A 补充 `PollingManager.start('index_sensor', 10000)`；轮询调度约束表新增 `index_sensor` 条目（10s 间隔）；`IndexPage` 核心抽象描述补充传感器轮询职责 |
| **H10**: 弱网韧性完全未覆盖 | 新增 `RetryPolicy` 配置定义（`common/RetryPolicy.ets`，核心抽象 §10）；新增 `CacheManager` 通用缓存管理器（`common/CacheManager.ets`，核心抽象 §11）；`SensorService` 补充内存缓存策略（TTL 30s）；每个页面新增 `@State connectivityStatus` + `ConnectivityIndicator` 组件；`PollingManager` 采用串行模式（递归 `setTimeout`）治理与重试的竞争；`HttpClient` 实现指数退避重试；完整的弱网韧性策略表合并 RetryPolicy、CacheManager、离线 UI、轮询交互约束 |
| **H11**: 现有 `common/api.ets` 与两层 HTTP 架构兼容性未评估 | 在「模块划分」的职责分工表中补充现有 `api.ets` 的实际角色迁移策略（增量剥离，不要求一次性重写）；明确设计假设（现有 `api.ets` 为纯传输层）及若不一致时的处理策略 |
| **M1**: 轮询告警转 UI 传播路径未定义 | 定义 `PollingCallback` 类型签名（`() => Promise<void>`），标注回调必须为箭头函数；场景 A 补充"轮询回调 → 更新 `@State alarmMessage/alarmSeverity` → `build()` → `AlarmBanner`"完整链路；`PollingManager` 每个 tick 通过 try-catch 包裹回调执行；标注 `stop(key)` 为 Must-Invoke |
| **M2**: `SensorService` 遗漏 `getDaily()` 方法签名 | 核心抽象 §3 补充 `getDaily(deviceId, start, end, page?, pageSize?)` 方法签名 |
| **M3**: `CommandService` 与 `DeviceService` 缺少缓存层定义 | `DeviceService` 核心抽象 §7 补充模块级缓存（`cachedDevices[]`、`lastFetchTime`）、`getCachedDevices()`、`refreshDevices()` 方法；`CommandService.send()` 前调用 `getCachedDevices()` 做预检；失败路径调用 `refreshDevices()` 更新缓存 |
| **M5**: 弱网请求重试机制缺失 | 与 H10 整合：`HttpClient` 实现指数退避重试（幂等请求重试，非幂等不做）；`RetryPolicy` 作为配置结构归属 H10 的完整弱网韧性方案 |
| **L1**: `constants.ets` 命令枚举未显式定义 | `constants.ets` 补充 `Command` 联合类型或枚举定义（`'led ON' | 'led OFF' | 'beep ON' | 'beep OFF' | 'spray ON' | 'spray OFF' | 'irrig ON' | 'irrig OFF'`） |
| **L2**: 循环渲染 `ForEach` 未引用 | 场景 C 中 DiseaseRecordsPage 的列表渲染补充 `ForEach` 示例标注 |
| **L3**: 弱网本地缓存策略 | 与 H10/L3 整合：`SensorService` 实现轻量级内存缓存（`CacheManager`），失败时返回最后一次成功数据；`SensorCard` 展示数据时间戳标记新鲜度 |
| **质询补充 1**: `DiseaseService.getStats()` / `getHeatmap()` 同样缺少显式方法签名 | 核心抽象 §4 补充 `getStats()` 和 `getHeatmap()` 方法描述；在设计决策 §12 中记录方法签名一致性原则 |
| **质询补充 2**: H10/M5 内容重叠 | RetryPolicy 统一归属于 H10 的完整弱网韧性方案（核心抽象 §10 + 错误处理策略弱网韧性表），M5 作为 H10 的子引用，M5 中不再独立定义重试策略 |

---

```
DESIGN_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\a_v2_design_v4.md
主Agent请勿阅读产出文件内容，直接将路径转发给相关方。
```
