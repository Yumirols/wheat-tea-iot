# 农眼卫士 FarmEye Guard v1.0 — 鸿蒙移动应用 OOD 设计方案

## 概述

鸿蒙 App 作为"端-云-台"三层架构中的表现层，承担农户移动端监控与远程控制职责。设计核心目标是在 ArkTS + ArkUI 的声明式框架约束下，实现数据展示、设备控制、告警推送、记录浏览四大功能域的内聚组织。

**整体架构思路**：采用"服务层（Service Layer）+ 页面层（View Layer）+ 公共层（Common Layer）"三层次架构：

- **服务层**将 HTTP API 交互封装为具有明确职责的 Service 类，页面通过 Service 获取数据，不直接操作 `http` 模块
- **页面层**遵循 ArkUI 的 `@Entry` + `@Component` 范式，每个页面为一个 struct，内部按职责拆分为子组件
- **公共层**承载数据模型定义（`interface`）、共享常量、工具函数，被所有页面和服务引用

**依赖方向**：页面层 → 服务层 → 公共层。页面层仅依赖服务层的接口抽象，不依赖实现细节；服务层依赖公共层的数据模型定义。

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
│   └── PaginatedList.ets         # 分页列表容器（封装分页加载逻辑）
│
├── services/                      # 服务层：API 交互封装
│   ├── HttpClient.ets            # HTTP 客户端单例（基础 URL、API Key、通用错误处理）
│   ├── SensorService.ets         # 传感器数据查询（latest / history / daily）
│   ├── DiseaseService.ets        # 病虫害记录查询（list / stats / heatmap）
│   ├── CommandService.ets        # 设备控制命令下发（send / logs）
│   ├── AdvisoryService.ets       # 防治建议拉取
│   ├── DeviceService.ets         # 设备列表与在线状态
│   └── PollingManager.ets        # 轮询调度器（统一管理各模块的轮询生命周期）
│
├── common/
│   ├── models.ets                # 数据模型：响应结构、业务实体 interface 定义
│   ├── api.ets                   # HTTP 请求封装（原始实现如需求所述使用 @ohos.net.http）
│   ├── constants.ets             # 常量定义（API 基础路径、轮询间隔、命令枚举等）
│   └── utils.ets                 # 工具函数（格式化、位掩码解析、时间处理）
```

### 模块职责

| 模块 | 职责 | 依赖 |
|------|------|------|
| `pages/` | 页面编排、UI 状态管理、用户交互事件响应 | `services/`, `components/`, `common/` |
| `components/` | 可复用 UI 部件的渲染和局部状态管理 | 仅 `common/models.ets`（类型引用） |
| `services/` | 封装 HTTP 请求逻辑、数据响应解析、业务预处理 | `common/` |
| `common/` | 数据模型定义、HTTP 基础封装、工具函数 | 无内部依赖 |

### 模块间依赖方向

```
pages/ ──→ services/ ──→ common/
  │                        ↑
  └──────── components/ ───┘
```

- `pages/` 依赖 `services/` 获取数据，依赖 `components/` 渲染子 UI
- `services/` 依赖 `common/` 进行 HTTP 通信和类型引用
- `components/` 仅引用 `common/models.ets` 中的类型定义

---

## 核心抽象

### 1. `HttpClient` — HTTP 通信门面

**角色**：封装 `@ohos.net.http` 的服务层入口。

**职责**：
- 持有 API 基础 URL 和 `X-API-Key` 认证令牌
- 提供 `GET` / `POST` 方法的通用请求接口，返回预解析后的业务数据
- 统一处理通用业务错误码（1001–5000），将错误映射为统一的失败信号
- 管理 HTTP 会话生命周期（`createHttp()` / `destroy()`）

**协作方式**：所有 Service 通过 `HttpClient` 发起请求，不直接调用 `http.createHttp()`。`HttpClient` 返回解析后的 `ApiResponse<T>` 泛型结构。

**类型形态选择理由**：选择为独立的单例类而非混入页面或组件，因为 HTTP 配置（baseURL、API Key）全局唯一且需要在多个 Service 间共享，单例模式在 ArkTS 中可通过模块级变量自然实现。

### 2. `SensorService` — 传感器数据获取

**角色**：环境监测数据的统一查询入口。

**职责**：
- 封装最新快照、历史数据、日聚合三种查询的 HTTP 请求逻辑和响应解析
- 返回经过类型断言后的结构化数据（而非裸 JSON）
- 不持有 UI 状态，仅做数据获取和转换

**协作方式**：被 `IndexPage`（最新快照卡片）和 `DashboardPage`（历史趋势图表）调用。

### 3. `DiseaseService` — 病虫害记录服务

**角色**：病虫害检测记录的数据访问层。

**职责**：
- 封装记录列表、统计、热力图三类查询
- 将筛选参数（时间范围、作物类型、严重度）映射为 URL query 参数
- 返回分页封装的数据结构

**协作方式**：被 `DiseaseRecordsPage` 调用，支持分页加载。

### 4. `CommandService` — 设备控制命令下发

**角色**：远程设备控制的操作入口。

**职责**：
- 封装 `POST /command/send` 的下发逻辑
- 封装 `GET /command/logs` 的查询逻辑
- 在校验设备在线状态后才执行下发

**协作方式**：被 `ControlPage` 调用。调用前需通过 `DeviceService` 检查设备在线状态。

### 5. `AdvisoryService` — 防治建议服务

**角色**：AI 决策建议的拉取入口。

**职责**：
- 封装 `GET /advisory` 的请求和响应解析
- 解析建议详情、环境联动分析、自动动作标记等嵌套结构

**协作方式**：被 `AdvisoryPage` 调用，同时被 `PollingManager` 周期性轮询以触发告警通知。

### 6. `DeviceService` — 设备管理服务

**角色**：设备列表与在线状态的查询入口。

**职责**：
- 封装 `GET /device/list` 的查询
- 提供设备在线状态的判断依据

**协作方式**：被 `IndexPage`（设备选择器）和 `ControlPage`（控制前检查在线状态）调用。

### 7. `PollingManager` — 轮询调度器

**角色**：统一管理所有轮询任务的生命周期。

**职责**：
- 维护一个轮询任务注册表，每个任务包含：轮询函数、间隔、是否活跃
- 提供 `start(key, fn, interval)` / `stop(key)` / `stopAll()` 接口
- 在页面 `aboutToAppear` / `aboutToDisappear` 生命周期中控制轮询的启动与停止
- 避免多个页面各自创建 `setInterval` 导致的资源浪费和竞争

**类型形态选择理由**：选择为独立管理器而非分散在各页面的 `setInterval`，因为多个页面（IndexPage 的告警轮询、AdvisoryPage 的建议轮询、DashboardPage 的数据刷新）需要集中管理，且需要在页面切换时统一停止/恢复。

### 8. 页面组件（`IndexPage` / `DashboardPage` / `DiseaseRecordsPage` / `ControlPage` / `AdvisoryPage`）

**角色**：ArkUI 视图层的 `@Entry` 页面。

**职责**：
- 声明 `@State` 装饰的本地状态（UI 渲染数据）
- 在 `aboutToAppear` 中调用对应 Service 初始化数据
- 在 `aboutToDisappear` 中停止所属轮询
- 将子组件所需的 `@Link` 状态向下传递

**协作方式**：通过 Service 获取数据，通过子组件完成具体 UI 渲染。页面间通过 `router.pushUrl()` / `router.replaceUrl()` 导航。

### 9. `SensorCard` — 传感器参数卡片

**角色**：环境参数的单值展示组件。

**职责**：
- 接收参数名、数值、单位、告警状态作为属性
- 按数值范围和告警状态切换背景高亮色
- 展示数值的单位后缀

**协作方式**：被 `DashboardPage` 和 `IndexPage` 复用。通过 `@Prop` 接收父组件的参数值。

### 10. `ChartView` — 历史趋势图表

**角色**：传感器历史数据的可视化组件。

**职责**：
- 接收数据点数组和图表类型（折线/柱状）作为属性
- 在 ArkUI 的 `Canvas` 或 `Chart` 组件上绘制趋势图
- 支持触摸交互（查看数据点详情）

**协作方式**：被 `DashboardPage` 调用，数据源来自 `SensorService.getHistory()`。

### 11. `ControlButton` — 双态控制按钮

**角色**：设备 ON/OFF 控制的操作组件。

**职责**：
- 接收当前状态（on/off）、设备 ID、命令类型作为属性
- 显示当前状态文案（"已开启"/"已关闭"）
- 点击时触发命令下发回调，显示加载态（`Progress` 组件）
- 错误时通过 `promptAction.showToast()` 反馈

**协作方式**：被 `ControlPage` 复用，每个实例对应一个执行机构（喷淋/灌溉/蜂鸣器/LED）。

### 12. `PaginatedList` — 分页列表容器

**角色**：支持无限滚动的分页列表组件。

**职责**：
- 接收分页加载回调函数作为属性
- 管理加载更多、加载中、无更多数据三种状态
- 在滚动到底部时自动触发下一页加载

**协作方式**：被 `DiseaseRecordsPage` 使用，加载函数指向 `DiseaseService.getList()`。

### 13. 数据模型接口（`common/models.ets`）

**角色**：业务数据的类型定义集合。

**核心接口**：

| 接口 | 描述 | 对应 API |
|------|------|---------|
| `DeviceInfo` | 设备信息（device_id, device_name, online, last_seen） | `/device/list` |
| `SensorSnapshot` | 最新环境数据快照（temperature, humidity, light, co2, soil_n/p/k, rssi, alarm_flag） | `/sensor/latest` |
| `SensorHistory` | 历史传感器数据记录（含 timestamp 和所有环境字段） | `/sensor/history` |
| `DailyAggregation` | 日聚合数据（avg/max/min 各环境指标） | `/sensor/daily` |
| `DiseaseRecord` | 病虫害记录（crop_type, disease_type, confidence, severity, linkage_risk_level） | `/disease/list` |
| `DiseaseStats` | 多维度统计（by_crop, by_severity, by_disease） | `/disease/stats` |
| `HeatmapData` | 热力图点数据 | `/disease/heatmap` |
| `CommandRequest` | 控制命令请求结构体 | `/command/send` 请求体 |
| `CommandLog` | 控制日志记录 | `/command/logs` |
| `Advisory` | 防治建议（latest_detection, current_env, env_disease_linkage, advisory） | `/advisory` |
| `ImageUploadResult` | 图片上传结果 | `/image/upload` |
| `ApiResponse<T>` | 通用 API 响应外层（code, message, data） | 所有接口 |
| `PaginatedData<T>` | 分页数据结构（pagination, records） | 分页接口 |

---

## 关键行为契约

### 场景 A：首页加载 → 环境快照展示 + 告警轮询

```
IndexPage.aboutToAppear()
  ├─ DeviceService.getDeviceList() → 获取设备列表 → 渲染 DeviceSelector
  ├─ SensorService.getLatest(deviceId) → 获取最新快照 → 分发至 SensorCard 组件群
  └─ PollingManager.start('alarm', 10000)
       └─ 每 10s: AdvisoryService.getAdvisory() → 检测新告警 → 如有重度告警 → AlarmBanner 显示
```

### 场景 B：远程设备控制

```
用户点击 ControlPage 的 ControlButton
  ├─ CommandService.send(deviceId, command)
  │    ├─ HttpClient.POST('/command/send', payload)
  │    ├─ 解析响应: 
  │    │    ├─ code=0 → 更新 ControlButton 状态为新的 ON/OFF
  │    │    ├─ code=1003 → 提示"设备离线"
  │    │    └─ 其他非0 → 提示操作失败 + 保持原状态
  │    └─ 无论成败 → 结束 ControlButton 加载态
  └─ CommandService.getLogs(deviceId) → 刷新控制日志列表
```

### 场景 C：病虫害记录分页浏览

```
DiseaseRecordsPage.aboutToAppear()
  ├─ 初始化筛选条件（默认最近7天，全部类型）
  ├─ DiseaseService.getList(filters, page=1) → 加载第一页
  │    ├─ 响应含 pagination.total → 设置列表总条目数
  │    └─ 渲染 PaginatedList → DiseaseRecord 列表
  └─ 用户滚动到底部 → PaginatedList 触发 getList(filters, nextPage)
       └─ 追加至现有记录列表
```

### 场景 D：仪表盘实时数据刷新

```
DashboardPage.aboutToAppear()
  ├─ SensorService.getLatest(deviceId) → SensorCard 群组刷新
  ├─ SensorService.getHistory(deviceId, timeRange) → ChartView 折线图渲染
  └─ PollingManager.start('dashboard', 10000)
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
| **网络连接失败** | `http.request()` 抛出异常（无网络、超时、DNS 解析失败） | 在 `HttpClient` 层统一 `catch`，转换为统一错误信号返回；页面层根据返回状态决定是否展示 toast |
| **HTTP 非 200 状态码** | 服务端返回 4xx/5xx | `HttpClient` 根据状态码映射为 `ApiResponse` 中的 `code` 字段 |
| **业务错误码** | API `response.code ≠ 0` | 各 Service 按场景处理：1003（设备离线）明确提示；2001/5000 统一提示"服务异常，请稍后重试" |
| **JSON 解析失败** | 响应体非预期格式 | `HttpClient` 层 `try-catch`，返回格式错误信号，页面层提示"数据格式异常" |
| **UI 操作错误** | 用户快速重复点击、在离线状态下操作 | 组件层防重复点击（加载态禁用按钮）+ 操作前检查设备状态 |

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
