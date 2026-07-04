# 农眼卫士 FarmEye Guard v1.0 — 鸿蒙移动应用 OOD 设计方案（v3）

## 概述

鸿蒙 App 作为"端-云-台"三层架构中的表现层，承担农户移动端监控与远程控制职责。设计核心目标是在 ArkTS + ArkUI 的声明式框架约束下，实现数据展示、设备控制、告警推送、记录浏览、图像管理五大功能域的内聚组织。

**整体架构思路**：采用"服务层（Service Layer）+ 页面层（View Layer）+ 公共层（Common Layer）"三层次架构：

- **服务层**将 HTTP API 交互封装为具有明确职责的 Service 类，页面通过 Service 获取数据，不直接操作 `http` 模块
- **页面层**遵循 ArkUI 的 `@Entry` + `@Component` 范式，每个页面为一个 struct，内部按职责拆分为子组件
- **公共层**承载数据模型定义（`interface`）、HTTP 原始封装、共享常量、工具函数，被所有页面和服务引用

**依赖方向**：页面层 → 服务层 → 公共层。页面层仅依赖服务层的接口抽象，不依赖实现细节；服务层依赖公共层的数据模型定义和 HTTP 原始封装。

---

## 模块划分

### 模块边界

```
harmony-app/entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets          # Ability 生命周期管理，加载首页
│
├── pages/                         # 视图层：5 个 @Entry 页面
│   ├── IndexPage.ets             # 首页：设备列表 + 环境快照概览 + 最近告警
│   ├── DashboardPage.ets         # 仪表盘：传感器卡片 + 实时曲线
│   ├── DiseaseRecordsPage.ets    # 病虫害记录：列表 + 筛选 + 详情
│   ├── ControlPage.ets           # 远程控制：设备执行机构操作面板
│   └── AdvisoryPage.ets          # 防治建议：AI 决策建议展示
│
├── components/                    # 可复用 UI 组件
│   ├── SensorCard.ets            # 传感器参数卡片（温度/湿度/光照/CO2/NPK 共用）
│   ├── ChartView.ets             # 历史趋势图表（折线图/柱状图）
│   ├── DeviceSelector.ets        # 设备选择器（多设备场景下拉选择）
│   ├── AlarmBanner.ets           # 告警横幅（实时告警推送展示）
│   ├── ControlButton.ets         # 控制按钮（ON/OFF 双态按钮，含加载态）
│   ├── SeverityBadge.ets         # 严重度徽标（Mild/Moderate/Severe 三色）
│   ├── PaginatedList.ets         # 分页列表容器（封装分页加载逻辑）
│   └── ImageViewer.ets           # 病虫害图片查看器（加载与展示）
│
├── services/                      # 服务层：API 交互封装
│   ├── HttpClient.ets            # HTTP 客户端——业务级门面（baseURL、API Key、JSON 解析、错误码映射）
│   ├── SensorService.ets         # 传感器数据查询（latest / history / daily）
│   ├── DiseaseService.ets        # 病虫害记录查询（list / stats / heatmap）
│   ├── CommandService.ets        # 设备控制命令下发（send / logs）
│   ├── AdvisoryService.ets       # 防治建议拉取
│   ├── DeviceService.ets         # 设备列表与在线状态
│   ├── ImageService.ets          # 图像上传与获取（multipart/form-data、二进制流）
│   └── PollingManager.ets        # 轮询调度器（统一管理各模块的轮询生命周期）
│
├── common/
│   ├── models.ets                # 数据模型：响应结构、业务实体 interface 定义
│   ├── api.ets                   # HTTP 原始封装——@ohos.net.http 生命周期管理（createHttp/destroy/超时/基础头）
│   ├── constants.ets             # 常量定义（API 基础路径、轮询间隔、命令枚举等）
│   └── utils.ets                 # 工具函数（格式化、位掩码解析、时间处理）
```

### 模块职责

| 模块 | 职责 | 依赖 |
|------|------|------|
| `pages/` | 页面编排、UI 状态管理、用户交互事件响应 | `services/`, `components/`, `common/` |
| `components/` | 可复用 UI 部件的渲染和局部状态管理 | 仅 `common/models.ets`（类型引用） |
| `services/` | 封装业务 HTTP 请求逻辑、数据响应解析、业务预处理 | `common/`（特别是 `common/api.ets` 和 `models.ets`） |
| `common/` | 数据模型定义、HTTP 原始封装、工具函数 | 无内部依赖 |

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

`api.ets` 和 `HttpClient.ets` 处于不同的抽象层次，形成"原始传输 → 业务门面"的两层 HTTP 封装结构：

| 层次 | 文件 | 职责范围 | 使用者 |
|------|------|---------|--------|
| **原始传输层** | `common/api.ets` | 封装 `@ohos.net.http` 的生命周期管理（`createHttp()`/`destroy()`）、请求超时设置、基础请求头注入、网络异常原生错误捕获、HTTP 状态码判断。返回原始 `http.HttpResponse` 或统一的 `NetworkResult` 结构 | 仅供 `HttpClient` 调用 |
| **业务门面层** | `services/HttpClient.ets` | 在 `api.ets` 基础上叠加业务语义：注入 `X-API-Key` 认证头、拼接 API 基础路径（`/api/v1`）、JSON 序列化/反序列化、通用业务错误码（1001–5000）映射、统一的 `ApiResponse<T>` 解析。为上层 Service 提供 `get<T>()` / `post<T>()` 泛型方法 | 供所有 `*Service` 调用 |

这种两层结构的设计理由：

1. `api.ets` 聚焦纯传输层关注点（连接创建/销毁、超时、原生异常），保持与 `@ohos.net.http` 的最小映射关系，不掺杂任何业务语义。当鸿蒙 SDK 升级导致 `@ohos.net.http` API 变化时，修改范围仅限 `api.ets`
2. `HttpClient` 承担业务门面职责，将认证、路径拼接、JSON 解析、业务错误码映射从各 Service 中集中提升至此，避免每个 Service 重复处理这些通用逻辑
3. `HttpClient` 预留 `Content-Type` 覆盖能力，供 `ImageService` 在构造 `multipart/form-data` 请求时替换默认的 `application/json`
4. 若后续需要切换网络库（如升级至 WebSocket），仅需修改 `api.ets` 的传输实现，业务门面和 Service 层不受影响

---

## 核心抽象

### 1. `api.ets` — HTTP 原始传输封装

**角色**：`@ohos.net.http` 的轻量适配器。

**职责**：
- 管理 `http.createHttp()` 和 `destroy()` 的完整生命周期（每次请求创建新实例，请求完成后销毁）
- 提供原始 `request(url, options)` 函数，接收 URL、请求方法和头部、请求体
- 设置全局超时（如 10s）
- 捕获网络层异常（无网络、超时、DNS 解析失败）并转换为结构化的失败信号
- 不解析 JSON、不注入业务头部、不处理业务错误码

**协作方式**：被 `HttpClient` 调用。`HttpClient` 负责拼装完整 URL、注入 `X-API-Key`、序列化请求体，然后交由 `api.ets` 执行实际传输。

**类型形态选择理由**：选择为纯函数导出（而非类），因为传输层是一组无状态的工具函数，不需要持有内部状态，ArkTS 的模块级函数导出即可满足。

### 2. `HttpClient` — HTTP 业务门面

**角色**：服务层 HTTP 通信的统一入口单例。

**职责**：
- 持有 API 基础 URL（通过常量模块获取）和 `X-API-Key` 认证令牌
- 在 `api.ets` 返回的原始响应上叠加业务处理：JSON 解析 → 检查 `code` 字段 → 映射为 `ApiResponse<T>`
- 提供 `get<T>(path, params)` / `post<T>(path, body, contentType?)` 泛型方法，返回已解析的 `ApiResponse<T>` 或抛出业务异常
- 提供 `getRaw(path, params?)` 方法，返回 `ArrayBuffer`，专用于二进制响应（如图片）获取，绕过 JSON 解析路径
- `post` 方法预留 `contentType?` 可选参数，允许 `ImageService` 覆盖为 `multipart/form-data`

**协作方式**：所有 `*Service` 通过 `HttpClient` 发起请求，不直接调用 `api.ets`。JSON API 场景使用 `get<T>()` / `post<T>()` 泛型方法；`ImageService` 获取图片二进制时使用 `getRaw(path)` 方法，返回 `ArrayBuffer`，绕过 JSON 解析路径。

**类型形态选择理由**：选择为模块级变量实现的单例，因为 API Key 和基础 URL 全局唯一且配置一次后不再变化，模块级 `export const` 天然实现单例语义，无需类构造。

### 3. `SensorService` — 传感器数据获取

**角色**：环境监测数据的统一查询入口。

**职责**：
- 封装最新快照、历史数据、日聚合三种查询的 HTTP 请求逻辑和响应解析
- 返回经过类型断言后的结构化数据（而非裸 JSON）
- 不持有 UI 状态，仅做数据获取和转换

**协作方式**：被 `IndexPage`（最新快照卡片）和 `DashboardPage`（历史趋势图表）调用。

### 4. `DiseaseService` — 病虫害记录服务

**角色**：病虫害检测记录的数据访问层。

**职责**：
- 封装记录列表、统计、热力图三类查询
- 将筛选参数（时间范围、作物类型、严重度）映射为 URL query 参数
- 返回分页封装的数据结构

**协作方式**：被 `DiseaseRecordsPage` 调用，支持分页加载。

### 5. `CommandService` — 设备控制命令下发

**角色**：远程设备控制的操作入口。

**职责**：
- 封装 `POST /command/send` 的下发逻辑
- 封装 `GET /command/logs` 的查询逻辑
- 在下发前通过 `DeviceService` 前置检查设备在线状态（若本地缓存的设备状态为离线则提前拒绝，避免无效请求）

**协作方式**：被 `ControlPage` 调用。调用前需通过 `DeviceService` 检查设备在线状态。

### 6. `AdvisoryService` — 防治建议服务

**角色**：AI 决策建议的拉取入口。

**职责**：
- 封装 `GET /advisory` 的请求和响应解析
- 解析建议详情、环境联动分析、自动动作标记等嵌套结构

**协作方式**：被 `AdvisoryPage` 调用，同时被 `PollingManager` 周期性轮询以触发告警通知。

### 7. `DeviceService` — 设备管理服务

**角色**：设备列表与在线状态的查询入口。

**职责**：
- 封装 `GET /device/list` 的查询
- 提供设备在线状态的判断依据（返回的 `online` 布尔字段）

**协作方式**：被 `IndexPage`（设备选择器）和 `ControlPage`（控制前检查在线状态）调用。

### 8. `ImageService` — 图像上传与获取（v2 新增）

**角色**：病虫害图片资源的传输管理入口。

**职责**：
- 封装 `POST /image/upload` 的 multipart/form-data 上传逻辑：构建 FormData（文件二进制 + 可选参数 `disease_record_id` / `device_id`），通过 `HttpClient.post()` 传入 `contentType: 'multipart/form-data'` 覆盖默认 JSON 类型
- 封装 `GET /image/{image_id}` 的二进制流获取逻辑：调用 `HttpClient.getRaw(path)` 获取 `ArrayBuffer`，返回给页面层
- 不处理图片裁剪、压缩、缓存等非传输层职责

**协作方式**：
- 被 `DiseaseRecordsPage`（查看病虫害记录中的图片）和未来的图片上传页面调用
- 图片上传：通过 `HttpClient.post()` 的 `contentType` 覆盖机制（传入 `'multipart/form-data'`），绕开 JSON 序列化路径，直接构建并发送 FormData
- 图片获取：通过 `HttpClient.getRaw(path)` 获取 `ArrayBuffer`，避开 `ApiResponse<T>` 的 JSON 解析路径。`getRaw` 返回的原始二进制数据由 `ImageViewer` 组件负责渲染
- 图片传输的两条路径（上传 + 获取）均经由 `HttpClient` 门面，不绕过也不直接调用 `api.ets`

**类型形态选择理由**：选择为独立 Service 而非混入 `DiseaseService`，是因为（1）图像上传使用 `multipart/form-data` 格式，请求体构建方式和 Content-Type 与 JSON API 完全不同，独立的 Service 可清晰承载差异化的传输逻辑；（2）图像获取返回二进制流而非 JSON，解析路径与数据 Service 不同；（3）遵循单一职责原则——图像传输与病虫害记录查询是两类不同职责。

### 9. `PollingManager` — 轮询调度器

**角色**：统一管理所有轮询任务的生命周期。

**职责**：
- 维护一个轮询任务注册表，每个任务包含：轮询函数、间隔、是否活跃
- 提供 `start(key, fn, interval)` / `stop(key)` / `stopAll()` 接口
- 在页面 `aboutToAppear` / `aboutToDisappear` 生命周期中控制轮询的启动与停止
- 在 `EntryAbility.onBackground()` / `onForeground()` 中统一暂停和恢复所有轮询
- 避免多个页面各自创建 `setInterval` 导致的资源浪费和竞争

**类型形态选择理由**：选择为独立管理器而非分散在各页面的 `setInterval`，因为多个页面（IndexPage 的告警轮询、AdvisoryPage 的建议轮询、DashboardPage 的数据刷新）需要集中管理，且需要在页面切换时统一停止/恢复。

### 10. 页面组件（`IndexPage` / `DashboardPage` / `DiseaseRecordsPage` / `ControlPage` / `AdvisoryPage`）

**角色**：ArkUI 视图层的 `@Entry` 页面。

**职责**：
- 声明 `@State` 装饰的本地状态（UI 渲染数据）
- 在 `aboutToAppear` 中调用对应 Service 初始化数据
- 在 `aboutToDisappear` 中停止所属轮询
- 将子组件所需的 `@Link` / `@Prop` 状态向下传递

**协作方式**：通过 Service 获取数据，通过子组件完成具体 UI 渲染。页面间通过 `router.pushUrl()` / `router.replaceUrl()` 导航。

### 11. `SensorCard` — 传感器参数卡片

**角色**：环境参数的单值展示组件。

**职责**：
- 接收参数名、数值、单位、告警状态作为属性
- 按数值范围和告警状态切换背景高亮色
- 展示数值的单位后缀

**协作方式**：被 `DashboardPage` 和 `IndexPage` 复用。通过 `@Prop` 接收父组件的参数值。

### 12. `ChartView` — 历史趋势图表

**角色**：传感器历史数据的可视化组件。

**职责**：
- 接收数据点数组和图表类型（折线/柱状）作为属性
- 在 ArkUI 的 `Canvas` 或 `Chart` 组件上绘制趋势图
- 支持触摸交互（查看数据点详情）

**协作方式**：被 `DashboardPage` 调用，数据源来自 `SensorService.getHistory()`。

### 13. `ControlButton` — 双态控制按钮

**角色**：设备 ON/OFF 控制的操作组件。

**职责**：
- 接收当前状态（on/off）、设备 ID、命令类型作为属性
- 显示当前状态文案（"已开启"/"已关闭"）
- 点击时触发命令下发回调，显示加载态（`Progress` 组件）
- 错误时通过 `promptAction.showToast()` 反馈

**协作方式**：被 `ControlPage` 复用，每个实例对应一个执行机构（喷淋/灌溉/蜂鸣器/LED）。

### 14. `PaginatedList` — 分页列表容器

**角色**：支持无限滚动的分页列表组件。

**职责**：
- 接收分页加载回调函数作为属性
- 管理加载更多、加载中、无更多数据三种状态
- 在滚动到底部时自动触发下一页加载

**协作方式**：被 `DiseaseRecordsPage` 使用，加载函数指向 `DiseaseService.getList()`。

### 15. `ImageViewer` — 病虫害图片查看器（v2 新增）

**角色**：病虫害记录关联图片的展示组件。

**职责**：
- 接收图片 URL（或图片二进制数据）作为属性
- 在图片容器中渲染网络图片（使用 `Image` 组件的网络源能力）
- 展示加载中、加载失败、空状态三种占位效果

**协作方式**：被 `DiseaseRecordsPage` 中的记录详情区域调用，图片源来自 `DiseaseRecord.image_path`，通过 `ImageService.getImage(imageId)` 获取。

### 16. 数据模型接口（`common/models.ets`）

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
| `NetworkResult` | 原始网络响应封装（statusCode, headers, rawBody: string） | `api.ets` 内部返回给 `HttpClient` |
| `ApiResponse<T>` | 通用 API 响应外层（code, message, data） | 所有接口 |
| `PaginatedData<T>` | 分页数据结构（pagination, records） | 分页接口 |

---

## 关键行为契约

### 场景 A：首页加载 → 环境快照展示 + 告警轮询

```
IndexPage.aboutToAppear()
  ├─ DeviceService.getDeviceList() → 获取设备列表 → 渲染 DeviceSelector
  ├─ SensorService.getLatest(deviceId) → 获取最新快照 → 分发至 SensorCard 组件群
  └─ PollingManager.start('index_alarm', 10000)
       └─ 每 10s: AdvisoryService.getAdvisory() → 检测新告警 → 如有重度告警 → AlarmBanner 显示
```

### 场景 B：远程设备控制

```
用户点击 ControlPage 的 ControlButton
  ├─ [前置检查] DeviceService 中缓存的设备 online 状态：
  │    ├─ 离线 → 提示"设备离线"，直接返回
  │    └─ 在线 → 继续下发
  ├─ CommandService.send(deviceId, command)
  │    ├─ HttpClient.POST('/command/send', payload)
  │    ├─ 解析响应: 
  │    │    ├─ code=0 → 更新 ControlButton 状态为新的 ON/OFF
  │    │    ├─ code=1003 → 提示"设备离线"
  │    │    └─ 其他非0 → 提示操作失败 + 保持原状态
  │    └─ 无论成败 → 结束 ControlButton 加载态
  └─ CommandService.getLogs(deviceId) → 刷新控制日志列表
```

### 场景 C：病虫害记录分页浏览 + 图片查看

```
DiseaseRecordsPage.aboutToAppear()
  ├─ 初始化筛选条件（默认最近7天，全部类型）
  ├─ DiseaseService.getList(filters, page=1) → 加载第一页
  │    ├─ 响应含 pagination.total → 设置列表总条目数
  │    └─ 渲染 PaginatedList → DiseaseRecord 列表
  ├─ 用户点击某条记录 → 展开详情
  │    └─ 若有 image_path → ImageService.getImage(imageId) → ImageViewer 渲染
  └─ 用户滚动到底部 → PaginatedList 触发 getList(filters, nextPage)
       └─ 追加至现有记录列表
```

### 场景 D：仪表盘实时数据刷新

```
DashboardPage.aboutToAppear()
  ├─ SensorService.getLatest(deviceId) → SensorCard 群组刷新
  ├─ SensorService.getHistory(deviceId, timeRange) → ChartView 折线图渲染
  └─ PollingManager.start('dashboard_sensor', 10000)
       └─ 每 10s: SensorService.getLatest() → 更新 SensorCard
```

### 场景 E：页面切换与轮询生命周期管理

```
页面 A → router.pushUrl('pages/B')
  ├─ 页面 A.aboutToDisappear() → PollingManager.stop('A相关key')
  ├─ 页面 B.aboutToAppear() → PollingManager.start('B相关key')
  └─ 用户返回 → 类似的生命周期恢复
```

页面切换不影响非活跃页面的轮询（由各页面的生命周期自行管理）。

---

## 错误处理策略

### 错误分类

| 类别 | 来源 | 处理方式 |
|------|------|---------|
| **网络连接失败** | `http.request()` 抛出异常（无网络、超时、DNS 解析失败） | 在 `api.ets` 层统一 `catch` 为结构化错误，`HttpClient` 识别并传递至 Service 层；页面层根据返回状态决定是否展示 toast |
| **HTTP 非 200 状态码** | 服务端返回 4xx/5xx | `HttpClient` 根据状态码映射为 `ApiResponse` 中的 `code` 字段 |
| **业务错误码** | API `response.code ≠ 0`，具体码值：1001（参数校验失败）、1002（资源不存在）、1003（设备离线）明确提示；1004（API Key 无效）、1005（频率限制）、2001（数据库错误）、3001（IoTDA 调用失败）、5000（服务器内部错误）统一提示"服务异常，请稍后重试" |
| **JSON 解析失败** | 响应体非预期格式 | `HttpClient` 层 `try-catch`，返回格式错误信号，页面层提示"数据格式异常" |
| **图片格式异常** | 图片数据非预期格式或损坏 | `ImageService` 返回失败信号，`ImageViewer` 组件展示"图片加载失败"占位 |
| **UI 操作错误** | 用户快速重复点击、在离线状态下操作 | 组件层防重复点击（加载态禁用按钮）+ 操作前通过 `DeviceService` 检查设备状态 |

### 用户反馈策略

- **网络/服务异常**：`promptAction.showToast({ message: '网络异常，请检查连接', duration: 2000 })`
- **设备离线**：`promptAction.showToast({ message: '设备离线，无法执行操作', duration: 2000 })`
- **操作成功**：`promptAction.showToast({ message: '{命令}已{开启/关闭}', duration: 1500 })`
- **数据为空**：在 UI 上展示空状态占位图，而非 toast
- **操作进行中**：按钮内嵌 `Progress` 组件，禁用重复点击

---

## 并发设计

### 线程模型

ArkTS 运行在 ArkUI 的主 UI 线程上，所有 UI 操作和状态更新必须在主线程执行。网络请求通过 `@ohos.net.http` 的回调异步模型处理。

- **网络请求**：使用 `async/await` 语法，不阻塞 UI 线程
- **轮询**：使用 `setInterval()` 在 UI 线程中调度，回调函数内部 `await` 网络请求
- **状态更新**：所有 `@State` 变量的修改在 `await` 之后恢复的同步上下文中执行，天然在主线程

### 轮询调度约束

| 页面 | 轮询key | 间隔 | 触发条件 | 停止条件 |
|------|---------|------|---------|---------|
| IndexPage | `index_alarm` | 10s | 页面出现 | 页面消失 |
| DashboardPage | `dashboard_sensor` | 10s | 页面出现 | 页面消失 |
| AdvisoryPage | `advisory_refresh` | 10s | 页面出现 | 页面消失 |

`PollingManager` 确保：
1. 同一 key 不会重复注册（已存在的先 `clearInterval` 再新建）
2. 所有轮询在应用进入后台时通过 `EntryAbility.onBackground()` → `PollingManager.suspendAll()` 暂停
3. 应用回到前台时通过 `EntryAbility.onForeground()` → `PollingManager.resumeAll()` 恢复

### 共享状态管理

- 所有网络请求结果通过 `@State` 局部状态持有，不共享跨页面全局状态
- API Key 通过模块级常量持有（只在 `HttpClient` 初始化时读取一次）
- 设备选择结果通过 `router` 的 URL 参数传递（多设备场景下跨页面共享设备 ID）

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
- 跨页面共享的 device_id 通过 `router.pushUrl({ params: { deviceId } })` 的参数传递
- 引入全局状态管理（如类似 Redux 的模式）在 ArkTS 中缺乏成熟支持，且对此规模项目过度设计

### 决策 6：告警轮询使用 AdvisoryService 而非独立告警接口

**选择**：轮询调用 `GET /advisory` 而非创建专门的告警接口。

**理由**：
- 后端 API 设计通过 `/advisory` 综合返回最新检测和建议
- 省去额外的告警端点，减少服务端部署复杂度
- 一次请求即可同时获取告警状态和防治建议，适合 10s 间隔的轮询

### 决策 7：命令下发采取乐观 UI 更新

**选择**：点击控制按钮后立即将 UI 切换为目标状态，再等待服务端响应；失败时回滚。

**理由**：
- 减少用户感知延迟，提高操作响应感
- 实现的复杂度可控：在 `catch` 或错误返回时恢复 `@State` 到操作前状态
- 与参考项目 `DisplayPage.ets` 中灯控制的模式一致

### 决策 8：`api.ets` 与 `HttpClient` 的两层 HTTP 封装（v2 补充）

**选择**：保留 `common/api.ets` 作为 `@ohos.net.http` 的原始封装，`services/HttpClient.ets` 在其基础上构建业务门面。

**理由**：
- 避免将 `@ohos.net.http` 的原始 API（`createHttp`/`destroy`/`RequestMethod`）暴露到 Service 层，`api.ets` 承担适配器角色
- 若鸿蒙 SDK 的 `@ohos.net.http` API 发生 breaking change，修改仅限 `api.ets`
- `HttpClient` 专注于业务语义（认证、路径、JSON、错误码），不关注传输细节
- 两者之间的调用关系清晰可测：单元测试时可直接 mock `api.ets` 层验证 `HttpClient` 的业务逻辑

### 决策 9：`ImageService` 独立于传输架构（v2 新增，v3 补充二进制获取路径）

**选择**：`ImageService` 通过 `HttpClient` 的 `contentType` 覆盖机制执行上传，通过 `HttpClient.getRaw()` 获取二进制图片。

**理由**：
- 图片上传的 `multipart/form-data` 格式与 JSON API 在请求体构建和 Content-Type 上有本质差异，不适合复用通用 JSON 序列化路径
- `HttpClient` 的 `post<T>()` 方法预留 `contentType` 可选参数，当 `ImageService` 调用时传入 `'multipart/form-data'`，绕开 JSON 序列化逻辑，改为构建 FormData 对象
- 图片获取返回二进制流，与 `ApiResponse<T>` 的 JSON 结构不兼容，因此在 `HttpClient` 上新增 `getRaw()` 方法，返回 `ArrayBuffer`，`ImageService` 通过此路径获取图片数据
- 这种设计保持了 `HttpClient` 对多数 JSON 请求的通用路径不变，同时为二进制场景提供了独立的非 JSON 获取路径
- `getRaw()` 方法不进行 JSON 解析，直接返回原始 `ArrayBuffer`，使 `ImageService` 保持对 `HttpClient` 的依赖，不绕过业务门面层

---

## 修订说明（v2）

| 审查意见 | 修改措施 |
|---------|---------|
| `common/api.ets` 与 `services/HttpClient.ets` 职责边界不清晰，设计未阐明两者关系和分工 | 在「模块划分」中新增 `api.ets` 与 `HttpClient` 职责分工表，明确两者为"原始传输层 → 业务门面层"的两层 HTTP 封装结构；在核心抽象中分别定义两个模块的角色和协作方式；在设计决策中新增「决策 8」记录选择理由 |
| 未覆盖图像上传/下载功能对应的服务抽象，缺少 `ImageService` | 新增 `services/ImageService.ets`（核心抽象 §8），涵盖 `POST /image/upload`（multipart/form-data）和 `GET /image/{image_id}`（二进制流）两个接口的封装；新增 `components/ImageViewer.ets` 组件用于图片渲染展示；在 `common/models.ets` 的接口表中补充 `ImageUploadResult`；在设计决策中新增「决策 9」记录 `ImageService` 独立设计的理由；在关键行为契约的场景 C 中补充图片查看的协作流程 |

---

## 修订说明（v3）

| 审查意见 | 修改措施 |
|---------|---------|
| 场景 A 中 `PollingManager` key 为 `'alarm'`，场景 D 中 key 为 `'dashboard'`，与轮询调度约束表中的 `'index_alarm'` / `'dashboard_sensor'` 不一致 | 场景 A：`PollingManager.start('alarm', ...)` → `PollingManager.start('index_alarm', ...)`；场景 D：`PollingManager.start('dashboard', ...)` → `PollingManager.start('dashboard_sensor', ...)`。场景描述与调度表 key 命名完全对齐 |
| `ImageService` 获取二进制图片的路径未定义：`HttpClient` 仅提供返回 `ApiResponse<T>` 的 `get<T>()`，无法承载二进制响应 | 在 `HttpClient` 核心抽象中新增 `getRaw(path, params?)` 方法定义，返回 `ArrayBuffer`，专用于二进制响应获取。`ImageService.getImage(imageId)` 的协作路径明确为：`HttpClient.getRaw('/image/{imageId}')` → `ArrayBuffer` → `ImageViewer` 渲染。选择此方案的理由：保持 `ImageService` 对 `HttpClient` 的依赖，不绕过业务门面层；不破坏现有 JSON `get<T>()` 泛型方法签名（对应审查建议的方案 A） |
| 错误码范围表述不精确（设计描述为"通用业务错误码 1001–5000"，实际为非连续分布） | 在错误处理策略中精确列出每个业务错误码：1001（参数校验失败）、1002（资源不存在）、1003（设备离线，明确提示）、1004（API Key 无效）、1005（频率限制）、2001（数据库错误）、3001（IoTDA 调用失败）、5000（服务器内部错误），明确区分处理行为 |
| `NetworkResult` 类型在 `api.ets` 描述中出现但未在 `common/models.ets` 类型定义表中列出 | 在核心接口表中新增 `NetworkResult`（statusCode, headers, rawBody: string）条目 |

---

```
DESIGN_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\a_v1_design_v3.md
主Agent请勿阅读产出文件内容，直接将路径转发给相关方。
```
