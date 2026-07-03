# 设计规格（R1 r2）

## 概述

实现 FarmEye Guard 鸿蒙应用的最小可编译骨架，固化 `common/` 层（类型 + 常量 + 工具 + 原始 HTTP 封装 + 缓存 + 重试策略）和 `services/HttpClient` 业务门面层，并改造 `EntryAbility` 接入 `PollingManager` 暂停/恢复钩子。

**范围**：
- 6 个 `common/` 文件：models、constants、RetryPolicy、CacheManager、utils、api
- 2 个 `services/` 文件：HttpClient、PollingManager（占位）
- 1 个 `entryability/` 文件：EntryAbility（改造 onForeground/onBackground）

**非范围**（后续轮次实现）：
- 业务 Service（SensorService / DiseaseService / CommandService / AdvisoryService / DeviceService / ImageService）
- 组件层（SensorCard / ChartView / ControlButton / AlarmBanner / PaginatedList / ImageViewer / ConnectivityIndicator / LoadingState / DeviceSelector / SeverityBadge / LineChartRenderer / BarChartRenderer）
- 页面层（Index 改造 / DashboardPage / DiseaseRecordsPage / ControlPage / AdvisoryPage）
- PollingManager 实际调度逻辑（递归 setTimeout、串行模式）

---

## 文件规划

| 文件路径 | 操作 | 职责 |
|---------|------|------|
| `harmony-app/entry/src/main/ets/common/models.ets` | 新建 | 全部业务数据模型 interface + type 定义 |
| `harmony-app/entry/src/main/ets/common/constants.ets` | 新建 | 全部常量定义（URL、Key、超时、轮询间隔、TTL、命令、错误码、报警位、缓存前缀） |
| `harmony-app/entry/src/main/ets/common/RetryPolicy.ets` | 新建 | 仅导出 `DEFAULT_RETRY` 常量（`RetryPolicyConfig` 类型在 models.ets） |
| `harmony-app/entry/src/main/ets/common/CacheManager.ets` | 新建 | 泛型内存缓存（set/get/invalidate/clear），TTL 自动失效 |
| `harmony-app/entry/src/main/ets/common/utils.ets` | 新建 | 工具函数（formatTimestamp、parseAlarmFlag、sleep、buildQueryString、isNetworkError、nowMs） |
| `harmony-app/entry/src/main/ets/common/api.ets` | 新建 | 原始传输层函数（request、requestRaw、uploadFile） |
| `harmony-app/entry/src/main/ets/services/HttpClient.ets` | 新建 | 业务门面（get/post/getRaw）+ 指数退避重试 |
| `harmony-app/entry/src/main/ets/services/PollingManager.ets` | 新建 | **占位**：导出空方法 start/stop/stopAll/suspendAll/resumeAll |
| `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets` | 改造 | 注入 PollingManager 暂停/恢复钩子 |
| `harmony-app/entry/src/main/ets/pages/Index.ets` | 不变 | 保留 Hello World |
| `harmony-app/entry/src/main/resources/base/profile/main_pages.json` | 不变 | 仅含 pages/Index |
| `harmony-app/entry/src/main/module.json5` | 不变 | — |

---

## 类型定义

### DeviceInfo

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：描述后端 `/device/list` 返回的设备实体。
```typescript
export interface DeviceInfo {
  id: number;
  device_id: string;
  device_name: string;
  mac_addr: string;
  ip_addr: string;
  registered_at: string;
  last_seen: string;
  online: boolean;
  created_at: string;
}
```

### SensorSnapshot

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/sensor/latest` 单条快照实体。
```typescript
export interface SensorSnapshot {
  id: number;
  device_id: string;
  mac_addr: string;
  timestamp: string;
  temperature: number;
  humidity: number;
  light: number;
  co2: number;
  soil_n: number;
  soil_p: number;
  soil_k: number;
  distance: number;
  rssi: number;
  ip_addr: string;
  alarm_flag: number;
  created_at: string;
}
```

### SensorHistory

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/sensor/history` 历史记录实体。
```typescript
export interface SensorHistory {
  id: number;
  device_id: string;
  timestamp: string;
  temperature: number;
  humidity: number;
  light: number;
  co2: number;
  soil_n: number;
  soil_p: number;
  soil_k: number;
  distance: number;
  rssi: number;
  ip_addr: string;
  alarm_flag: number;
}
```

### DailyAggregation

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/sensor/daily` 日聚合实体。
```typescript
export interface DailyAggregation {
  id: number;
  device_id: string;
  agg_date: string;
  avg_temperature: number;
  max_temperature: number;
  min_temperature: number;
  avg_humidity: number;
  max_humidity: number;
  min_humidity: number;
  avg_light: number;
  max_light: number;
  min_light: number;
  avg_co2: number;
  max_co2: number;
  min_co2: number;
  record_count: number;
  created_at: string;
}
```

### DiseaseRecord

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/disease/list` 病虫害记录实体。
```typescript
export interface DiseaseRecord {
  id: number;
  device_id: string;
  timestamp: string;
  crop_type: string;
  disease_type: string;
  confidence: number;
  severity: string;
  severity_code: number;
  linkage_risk_level: string;
  linkage_detail: string;
  image_path: string;
  action_taken: string;
  created_at: string;
}
```

### DiseaseStats

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/disease/stats` 统计响应。
```typescript
export interface DiseaseStats {
  total_detections: number;
  by_crop: Record<string, number>;
  by_severity: Record<string, number>;
  by_disease: Record<string, number>;
}
```

### HeatmapData

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/disease/heatmap` 热力图响应。
```typescript
export interface HeatmapPoint {
  device_id: string;
  disease_type: string;
  severity: string;
  timestamp: string;
  crop_type: string;
}

export interface HeatmapSummary {
  active_disease_types: number;
  affected_devices: number;
  total_records: number;
}

export interface HeatmapData {
  heatmap_points: HeatmapPoint[];
  summary: HeatmapSummary;
}
```

### CommandRequest

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/command/send` 请求体。
```typescript
export interface CommandRequest {
  device_id: string;
  command: string;
  source?: string;
  operator?: string;
}
```

### CommandResponse

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/command/send` 成功响应 `data` 字段实体（`docs/3_client-api-reference.md` §2.5.1）。
```typescript
export interface CommandResponse {
  command_id: string;
  device_id: string;
  command: string;
  status: string;
}
```

### CommandLog

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/command/logs` 控制日志实体。
```typescript
export interface CommandLog {
  id: number;
  device_id: string;
  command_id: string;
  timestamp: string;
  command: string;
  source: string;
  operator: string;
  result_code: number;
  result_msg: string;
}
```

### Advisory

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/advisory` 综合防治建议响应。
```typescript
export interface AdvisoryDetection {
  crop_type: string;
  disease_type: string;
  severity: string;
  severity_code: number;
  confidence: number;
  timestamp: string;
}

export interface AdvisoryEnv {
  temperature: number;
  humidity: number;
  light: number;
  co2: number;
}

export interface AdvisoryLinkage {
  risk_level: string;
  matched_conditions: string[];
  recommendation: string;
}

export interface AdvisoryAction {
  action: string;
  description: string;
  auto_action_triggered: boolean;
  auto_action: string | null;
}

export interface Advisory {
  latest_detection: AdvisoryDetection | null;
  current_env: AdvisoryEnv | null;
  env_disease_linkage: AdvisoryLinkage | null;
  advisory: AdvisoryAction | null;
}
```

### ImageUploadResult

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`/image/upload` 上传结果。
```typescript
export interface ImageUploadResult {
  image_id: string;
  image_path: string;
  file_size: number;
  uploaded_at: string;
}
```

### TextResult

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`api.ets` 的 `request()` 原始响应封装（JSON 场景）。
```typescript
export interface TextResult {
  statusCode: number;
  headers: Record<string, string>;
  rawBody: string;
}
```

### BinaryResult

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：`api.ets` 的 `requestRaw()` 原始响应封装（二进制场景）。
```typescript
export interface BinaryResult {
  statusCode: number;
  headers: Record<string, string>;
  rawBody: ArrayBuffer;
}
```

### ApiResponse

**形态**：`interface`（泛型）
**包路径**：`common/models.ets`
**职责**：通用 API 响应外层结构。
```typescript
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T | null;
}
```

### PaginatedData

**形态**：`interface`（泛型）
**包路径**：`common/models.ets`
**职责**：分页数据结构。
```typescript
export interface Pagination {
  total: number;
  page: number;
  page_size: number;
}

export interface PaginatedData<T> {
  pagination: Pagination;
  records: T[];
}
```

### CacheEntry

**形态**：`interface`（泛型）
**包路径**：`common/models.ets`
**职责**：缓存条目。
```typescript
export interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number;
}
```

### RetryPolicyConfig

**形态**：`interface`
**包路径**：`common/models.ets`
**职责**：重试策略配置结构（实际常量 `DEFAULT_RETRY` 在 `common/RetryPolicy.ets`）。
```typescript
export interface RetryPolicyConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  retryOn: number[];
  timeoutMs: number;
}
```

### PollingCallback

**形态**：`type`
**包路径**：`common/models.ets`
**职责**：轮询回调签名。
```typescript
export type PollingCallback = () => Promise<void>;
```

### ConnectivityStatus

**形态**：`type`
**包路径**：`common/models.ets`
**职责**：页面连接状态联合类型。
```typescript
export type ConnectivityStatus = 'loading' | 'online' | 'offline';
```

---

## 错误处理

### 错误类型

- **网络层原生异常**：`@ohos.net.http` 的 `request()` 抛出（无网络、超时、DNS 失败）。`api.ets` 内部 `try-catch (err: BusinessError)` 后抛出标准 `Error` 对象，`message` 包含原始 `code` 与 `message`。
- **HTTP 非 200 状态码**：`api.ets` 将 `response.responseCode` 原样塞入 `TextResult.statusCode` 返回，由 `HttpClient` 决定是否触发重试。
- **业务错误码**：`ApiResponse<T>.code !== 0`。`HttpClient` 不抛出异常，调用方根据 `code` 自行判断。
- **JSON 解析失败**：`HttpClient` `try-catch` `JSON.parse` 抛出标准 `Error`，`message = 'JSON parse error'`。

### 错误传播链

```
api.ets (原生异常) → Error
  └─ HttpClient 重试判定（catch + retryOn 匹配）
       └─ 重试耗尽后抛出 Error
            └─ Service 层接住 → CacheManager 缓存回退或向上抛
                 └─ Page 层 catch → 更新 connectivityStatus / 错误提示
```

### 业务错误码常量

定义于 `common/constants.ets`，枚举名称 `ErrorCode`（数字联合类型），值见下方常量清单。

---

## 行为契约

### common/models.ets

- **前置条件**：无
- **后置条件**：仅类型导出，无运行时副作用
- **调用顺序**：任意
- **状态变化**：无

### common/constants.ets

- **前置条件**：无
- **后置条件**：模块加载时一次性求值，`API_KEY` 等敏感值（开发调试）硬编码
- **调用顺序**：任意
- **状态变化**：无

### common/RetryPolicy.ets

- **前置条件**：无
- **后置条件**：导出 `DEFAULT_RETRY: RetryPolicyConfig` 常量
- **调用顺序**：被 `HttpClient` 内部消费
- **状态变化**：无

### common/CacheManager.ets

- **前置条件**：键为字符串，值为任意 JSON 兼容对象
- **后置条件**：
  - `set(key, data, ttl?)`：写入或覆盖键空间，ttl 默认走 `CACHE_DEFAULT_TTL_MS`
  - `get(key)`：返回 `T | null`，过期或不存在返回 `null`
  - `invalidate(key)`：删除指定键
  - `clear()`：清空所有键
- **调用顺序**：先 `set` 后 `get`
- **状态变化**：内部维护 `Map<string, CacheEntry<unknown>>`

### common/utils.ets

- **前置条件**：无
- **后置条件**：纯函数，无副作用
- **调用顺序**：任意
- **状态变化**：无

### common/api.ets

- **前置条件**：`url` 必须是带协议的完整 URL（`api.ets` 不拼接前缀）
- **后置条件**：
  - `request()`：返回 `Promise<TextResult>`，请求完成后销毁内部 `http.HttpRequest` 实例
  - `requestRaw()`：返回 `Promise<BinaryResult>`
  - `uploadFile()`：返回 `Promise<ApiResponse<ImageUploadResult>>`（已 JSON 解析）
- **调用顺序**：被 `HttpClient` / 后续 `ImageService` 独占调用
- **状态变化**：每次请求创建/销毁 `HttpRequest` 实例

### services/HttpClient.ets

- **前置条件**：模块已加载，依赖 `common/api.ets`、`common/constants.ets`、`common/RetryPolicy.ets`、`common/utils.ets`
- **后置条件**：
  - `get<T>(path, params?)`：执行 `GET baseURL + path + queryString`，注入 `X-Api-Key`，JSON 解析，重试 3 次
  - `post<T>(path, body?)`：执行 `POST baseURL + path`，注入 `X-Api-Key`，JSON 解析，**不重试**
  - `getRaw(path, params?)`：调用 `api.requestRaw()`，注入 `X-Api-Key`，返回 `Promise<ArrayBuffer>`，重试 3 次
- **调用顺序**：被 `*Service` 调用
- **状态变化**：模块级持有 `baseURL: string`、`apiKey: string` 常量

### services/PollingManager.ets（占位）

- **前置条件**：无
- **后置条件**：
  - `start(key, fn, interval)`：将 `{ running: true }` 存入 `tasks: Map<string, PollingTask>`，同一 key 覆盖
  - `stop(key)`：从 `tasks` 删除指定 key
  - `stopAll()`：`tasks.clear()`
  - `suspendAll()`：将 `tasks` 中所有条目的 `running` 置 `false`
  - `resumeAll()`：将 `tasks` 中所有条目的 `running` 置 `true`
  - **本轮不实现**：递归 `setTimeout` 调度、回调实际调用、try-catch 包裹
- **调用顺序**：被页面与 `EntryAbility` 调用
- **状态变化**：仅维护 `tasks` Map

### entryability/EntryAbility.ets

- **前置条件**：`PollingManager` 已导出 `suspendAll` / `resumeAll`
- **后置条件**：
  - `onForeground()`：追加调用 `PollingManager.resumeAll()`
  - `onBackground()`：追加调用 `PollingManager.suspendAll()`
- **调用顺序**：与模板基类方法共存
- **状态变化**：依赖 `PollingManager` 内部状态

---

## 依赖关系

### 模块依赖图

```
entryability/EntryAbility.ets
    └─→ services/PollingManager.ets（占位）

services/HttpClient.ets
    ├─→ common/api.ets
    ├─→ common/constants.ets（API_BASE_URL, API_KEY, DEFAULT_TIMEOUT_MS）
    ├─→ common/RetryPolicy.ets（DEFAULT_RETRY）
    ├─→ common/utils.ets（isNetworkError, sleep）
    └─→ common/models.ets（ApiResponse, TextResult, BinaryResult, RetryPolicyConfig）

common/api.ets
    ├─→ common/models.ets（TextResult, BinaryResult, ApiResponse, ImageUploadResult）
    ├─→ common/constants.ets（HEADER_API_KEY, DEFAULT_TIMEOUT_MS, UPLOAD_TIMEOUT_MS）
    └─→ @kit.BasicServicesKit（BusinessError，仅用于 try-catch 类型守卫）

common/CacheManager.ets
    ├─→ common/models.ets（CacheEntry）
    └─→ common/constants.ets（CACHE_DEFAULT_TTL_MS）

common/utils.ets
    ├─→ common/models.ets（无显式依赖，使用基础类型）
    └─→ common/constants.ets（ALARM_FLAG_*）

common/RetryPolicy.ets
    └─→ common/models.ets（RetryPolicyConfig）

common/constants.ets → 无依赖
common/models.ets → 无依赖
```

### 暴露给后续任务的公开接口

| 来源 | 导出 | 后续消费者 |
|------|------|-----------|
| `common/models.ets` | 全部 interface + type（含 `CommandResponse`） | 全部 Service / Page / Component |
| `common/constants.ets` | 全部常量 | HttpClient / Service / utils |
| `common/RetryPolicy.ets` | `DEFAULT_RETRY` | HttpClient |
| `common/CacheManager.ets` | `CacheManager` 模块单例 | 全部 Service（未来） |
| `common/utils.ets` | 全部工具函数（含 `isNetworkError`、`sleep`） | Service / Page |
| `common/api.ets` | `request`、`requestRaw`、`uploadFile` | HttpClient / ImageService（未来） |
| `services/HttpClient.ets` | `get`、`post`、`getRaw` + `BASE_URL` / `API_KEY` getter | 全部 Service（未来） |
| `services/PollingManager.ets` | `start`、`stop`、`stopAll`、`suspendAll`、`resumeAll` | 全部 Page（未来） |

---

## 文件级实现规格

### 1. `harmony-app/entry/src/main/ets/common/models.ets`（新建）

**导入语句**：
```typescript
// 无外部导入（纯类型定义）
```

**完整导出清单**（按类别）：

#### 业务实体
- `DeviceInfo`
- `SensorSnapshot`
- `SensorHistory`
- `DailyAggregation`
- `DiseaseRecord`
- `DiseaseStats`
- `HeatmapPoint`
- `HeatmapSummary`
- `HeatmapData`
- `CommandRequest`
- `CommandResponse`  ← **R2 新增**（`POST /command/send` 响应 `data` 字段类型）
- `CommandLog`
- `AdvisoryDetection`
- `AdvisoryEnv`
- `AdvisoryLinkage`
- `AdvisoryAction`
- `Advisory`
- `ImageUploadResult`

#### 响应封装
- `TextResult`
- `BinaryResult`
- `ApiResponse<T>`
- `Pagination`
- `PaginatedData<T>`

#### 基础设施
- `CacheEntry<T>`
- `RetryPolicyConfig`

#### 行为类型
- `PollingCallback` = `() => Promise<void>`
- `ConnectivityStatus` = `'loading' | 'online' | 'offline'`

---

### 2. `harmony-app/entry/src/main/ets/common/constants.ets`（新建）

**导入语句**：
```typescript
// 无外部导入
```

**完整常量清单**：

#### HTTP 配置
| 常量名 | 类型 | 值 | 说明 |
|--------|------|----|----|
| `API_BASE_URL` | `string` | `http://<VPS_IP>:8000` | 后端基础 URL（不含 `/api/v1`，由 HttpClient 拼接） |
| `API_PATH_PREFIX` | `string` | `/api/v1` | 接口路径前缀（HttpClient 拼接用） |
| `API_KEY` | `string` | `farmeye_dev_key_001` | 测试 API Key |
| `HEADER_API_KEY` | `string` | `X-Api-Key` | 请求头字段名 |
| `DEFAULT_TIMEOUT_MS` | `number` | `10000` | HTTP 请求超时（10s） |
| `UPLOAD_TIMEOUT_MS` | `number` | `60000` | 文件上传超时（60s） |

#### 轮询间隔
| 常量名 | 类型 | 值 | 说明 |
|--------|------|----|----|
| `POLL_INTERVAL_INDEX_SENSOR_MS` | `number` | `10000` | 首页传感器轮询（10s） |
| `POLL_INTERVAL_INDEX_ALARM_MS` | `number` | `10000` | 首页告警轮询（10s） |
| `POLL_INTERVAL_DASHBOARD_MS` | `number` | `10000` | 仪表盘轮询（10s） |
| `POLL_INTERVAL_ADVISORY_MS` | `number` | `10000` | 建议页轮询（10s） |
| `CONTROL_POLL_INTERVAL_MS` | `number` | `1000` | 控制命令确认轮询（1s） |
| `CONTROL_POLL_MAX_TIMES` | `number` | `5` | 控制确认最大轮询次数 |

#### 缓存 TTL
| 常量名 | 类型 | 值 | 说明 |
|--------|------|----|----|
| `CACHE_DEFAULT_TTL_MS` | `number` | `30000` | 通用缓存默认 TTL（30s） |
| `CACHE_TTL_SENSOR_MS` | `number` | `30000` | 传感器数据 TTL（30s） |
| `CACHE_TTL_DEVICE_MS` | `number` | `60000` | 设备列表 TTL（60s） |
| `CACHE_TTL_DISEASE_MS` | `number` | `60000` | 病虫害数据 TTL（60s） |
| `CACHE_TTL_ADVISORY_MS` | `number` | `30000` | 建议数据 TTL（30s） |

#### 缓存键前缀
| 常量名 | 类型 | 值 | 说明 |
|--------|------|----|----|
| `CACHE_KEY_PREFIX_SENSOR_LATEST` | `string` | `sensor_latest_` | 单设备最新快照 |
| `CACHE_KEY_PREFIX_SENSOR_ALL_LATEST` | `string` | `sensor_all_latest` | 全设备最新快照 |
| `CACHE_KEY_PREFIX_SENSOR_HISTORY` | `string` | `sensor_history_` | 历史数据 |
| `CACHE_KEY_PREFIX_SENSOR_DAILY` | `string` | `sensor_daily_` | 日聚合 |
| `CACHE_KEY_PREFIX_DEVICE_LIST` | `string` | `device_list_` | 设备列表 |
| `CACHE_KEY_PREFIX_DISEASE_LIST` | `string` | `disease_list_` | 病虫害列表 |
| `CACHE_KEY_PREFIX_DISEASE_STATS` | `string` | `disease_stats` | 病虫害统计 |
| `CACHE_KEY_PREFIX_DISEASE_HEATMAP` | `string` | `disease_heatmap` | 热力图 |
| `CACHE_KEY_PREFIX_ADVISORY` | `string` | `advisory_` | 防治建议 |
| `CACHE_KEY_PREFIX_COMMAND_LOGS` | `string` | `command_logs_` | 控制日志 |

#### 命令字符串
| 常量名 | 类型 | 值 | 说明 |
|--------|------|----|----|
| `CMD_LED_ON` | `string` | `led ON` | 开 LED |
| `CMD_LED_OFF` | `string` | `led OFF` | 关 LED |
| `CMD_BEEP_ON` | `string` | `beep ON` | 开蜂鸣器 |
| `CMD_BEEP_OFF` | `string` | `beep OFF` | 关蜂鸣器 |
| `CMD_SPRAY_ON` | `string` | `spray ON` | 开喷淋 |
| `CMD_SPRAY_OFF` | `string` | `spray OFF` | 关喷淋 |
| `CMD_IRRIG_ON` | `string` | `irrig ON` | 开灌溉 |
| `CMD_IRRIG_OFF` | `string` | `irrig OFF` | 关灌溉 |
| `COMMAND_SOURCE_MANUAL_APP` | `string` | `manual_app` | 来源：鸿蒙端手动 |
| `COMMAND_SOURCE_MANUAL_PC` | `string` | `manual_pc` | 来源：上位机手动 |
| `COMMAND_SOURCE_AUTO` | `string` | `auto` | 来源：自动控制 |
| `COMMAND_STATUS_SENT` | `string` | `sent` | 命令已下发 |
| `COMMAND_STATUS_SUCCESS` | `number` | `0` | 设备执行成功 result_code |

#### 业务错误码（ErrorCode 联合类型）
| 常量名 | 类型 | 值 | 说明 |
|--------|------|----|----|
| `ERR_CODE_SUCCESS` | `number` | `0` | 成功 |
| `ERR_CODE_INVALID_PARAM` | `number` | `1001` | 参数无效 |
| `ERR_CODE_NOT_FOUND` | `number` | `1002` | 资源不存在 |
| `ERR_CODE_DEVICE_OFFLINE` | `number` | `1003` | 设备离线 |
| `ERR_CODE_INVALID_API_KEY` | `number` | `1004` | API Key 无效 |
| `ERR_CODE_RATE_LIMIT` | `number` | `1005` | 频率限制 |
| `ERR_CODE_DB_ERROR` | `number` | `2001` | 数据库错误 |
| `ERR_CODE_IOTDA_ERROR` | `number` | `3001` | IoTDA 错误 |
| `ERR_CODE_INTERNAL` | `number` | `5000` | 内部错误 |

#### 报警位掩码
| 常量名 | 类型 | 值 | 说明 |
|--------|------|----|----|
| `ALARM_FLAG_HIGH_TEMP` | `number` | `0x01` | 高温 |
| `ALARM_FLAG_LOW_TEMP` | `number` | `0x02` | 低温 |
| `ALARM_FLAG_HIGH_HUMIDITY` | `number` | `0x04` | 高湿 |
| `ALARM_FLAG_LOW_HUMIDITY` | `number` | `0x08` | 低湿 |
| `ALARM_FLAG_LOW_LIGHT` | `number` | `0x10` | 低光照 |
| `ALARM_FLAG_HIGH_CO2` | `number` | `0x20` | 高 CO2 |
| `ALARM_FLAG_LOW_NITROGEN` | `number` | `0x40` | 低氮 |
| `ALARM_FLAG_LOW_PHOSPHORUS` | `number` | `0x80` | 低磷 |

#### 重试相关
| 常量名 | 类型 | 值 | 说明 |
|--------|------|----|----|
| `RETRY_STATUS_CODES` | `number[]` | `[408, 429, 502, 503, 504]` | 触发重试的 HTTP 状态码 |
| `RETRY_BASE_DELAY_MS` | `number` | `1000` | 重试基础延迟（1s） |
| `RETRY_MAX_DELAY_MS` | `number` | `10000` | 重试最大延迟（10s） |
| `RETRY_MAX_RETRIES` | `number` | `3` | GET 最大重试次数 |

**导出形式**：
- 字符串/数字常量：`export const ...`
- 数组常量：`export const RETRY_STATUS_CODES: number[] = [...]`
- 错误码另提供 `export type ErrorCode = 0 | 1001 | 1002 | 1003 | 1004 | 1005 | 2001 | 3001 | 5000`

---

### 3. `harmony-app/entry/src/main/ets/common/RetryPolicy.ets`（新建）

**导入语句**：
```typescript
import { RetryPolicyConfig } from './models';
import { RETRY_BASE_DELAY_MS, RETRY_MAX_DELAY_MS, RETRY_MAX_RETRIES, RETRY_STATUS_CODES, DEFAULT_TIMEOUT_MS } from './constants';
```

**导出常量**：
```typescript
export const DEFAULT_RETRY: RetryPolicyConfig = {
  maxRetries: RETRY_MAX_RETRIES,
  baseDelayMs: RETRY_BASE_DELAY_MS,
  maxDelayMs: RETRY_MAX_DELAY_MS,
  retryOn: RETRY_STATUS_CODES,
  timeoutMs: DEFAULT_TIMEOUT_MS
};
```

**职责边界**：仅导出 `DEFAULT_RETRY`，不包含任何类或函数。

**`timeoutMs` 字段语义说明**（R2 修订）：
- `RetryPolicyConfig.timeoutMs` 当前作为"配置契约字段"保留，**当前重试循环（`HttpClient.withRetry`）未直接消费**该字段进行超时调整。
- `DEFAULT_RETRY.timeoutMs = DEFAULT_TIMEOUT_MS = 10000` 是为了让 `RetryPolicyConfig` 的所有"时长相关字段"具有统一的数值基线，便于后续演进（如按重试次数退避调整超时、或向 `api.ets` 透传以覆盖其内部默认超时）。
- 当前实现下 HTTP 超时由 `api.ets` 内部直接使用 `DEFAULT_TIMEOUT_MS` 常量；该字段保留是为后续动态超时策略预留接口，避免后续演进时修改 `RetryPolicyConfig` 形态破坏 `HttpClient` 与其它 Service 的依赖契约。

---

### 4. `harmony-app/entry/src/main/ets/common/CacheManager.ets`（新建）

**导入语句**：
```typescript
import { CacheEntry } from './models';
import { CACHE_DEFAULT_TTL_MS } from './constants';
```

**模块级状态**：
```typescript
const store: Map<string, CacheEntry<unknown>> = new Map();
```

**公开 API**：

| 方法 | 签名 | 行为 |
|------|------|------|
| `set<T>` | `set<T>(key: string, data: T, ttl?: number): void` | 写入缓存，`ttl` 默认 `CACHE_DEFAULT_TTL_MS`；内部存 `{ data, timestamp: nowMs(), ttl }` |
| `get<T>` | `get<T>(key: string): T \| null` | 读取并检查 TTL，过期则自动 `invalidate` 并返回 `null`；不存在返回 `null` |
| `invalidate` | `invalidate(key: string): void` | 删除指定键 |
| `clear` | `clear(): void` | 清空 `store` |

**导出形式**：
```typescript
export const CacheManager = {
  set, get, invalidate, clear
};
```

**行为契约**：
- `get` 内部时间判断使用 `utils.nowMs()`
- 过期判定：`nowMs() - entry.timestamp > entry.ttl`

---

### 5. `harmony-app/entry/src/main/ets/common/utils.ets`（新建）

**导入语句**：
```typescript
import { ALARM_FLAG_HIGH_TEMP, ALARM_FLAG_LOW_TEMP, ALARM_FLAG_HIGH_HUMIDITY, ALARM_FLAG_LOW_HUMIDITY, ALARM_FLAG_LOW_LIGHT, ALARM_FLAG_HIGH_CO2, ALARM_FLAG_LOW_NITROGEN, ALARM_FLAG_LOW_PHOSPHORUS } from './constants';
```

**工具函数签名**：

| 函数 | 签名 | 行为 |
|------|------|------|
| `formatTimestamp` | `formatTimestamp(iso: string): string` | 将 ISO 时间字符串格式化为 `YYYY-MM-DD HH:mm:ss`；异常时返回原串 |
| `parseAlarmFlag` | `parseAlarmFlag(flag: number): string[]` | 按位与 `ALARM_FLAG_*` 掩码，返回激活的报警名数组（如 `['高温', '低光照']`） |
| `sleep` | `sleep(ms: number): Promise<void>` | 返回 `setTimeout` 包装的 Promise |
| `buildQueryString` | `buildQueryString(params: Record<string, string \| number \| undefined>): string` | 将参数对象转为 `?k=v&k2=v2`；空对象返回 `''`；`undefined` 值跳过 |
| `isNetworkError` | `isNetworkError(err: unknown): boolean` | 判断 `err` 是否为原生网络层错误（`err` 含 `code` 属性且 `code` 为数字）；用于区分网络异常与业务错误 |
| `nowMs` | `nowMs(): number` | 返回 `Date.now()` |

**导出形式**：
```typescript
export function formatTimestamp(...): string { ... }
// 全部以命名导出
```

---

### 6. `harmony-app/entry/src/main/ets/common/api.ets`（新建）

**导入语句**：
```typescript
import { http } from '@kit.NetworkKit';
import { request as ohRequest } from '@kit.RequestKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { TextResult, BinaryResult, ApiResponse, ImageUploadResult } from './models';
import { HEADER_API_KEY, DEFAULT_TIMEOUT_MS, UPLOAD_TIMEOUT_MS } from './constants';
```

> **R2 修订要点**：`@kit.RequestKit` 的导入重命名为 `ohRequest`，避免与本文件导出的 `request` 函数同名冲突。`uploadFile` 实现中相应使用 `ohRequest.uploadFile(...)` / `ohRequest.agent.create()`。

> **注意**：ArkTS 中 `@ohos.net.http` 对应 `@kit.NetworkKit`；`@ohos.request` 对应 `@kit.RequestKit`；`UIAbility` 的 `context` 类型为 `common.UIAbilityContext`（来自 `@kit.AbilityKit`）。具体模块名以编译期为准（如失败回退到 `@ohos.net.http` / `@ohos.request`）。

**公开 API**：

#### `request`
```typescript
export function request(url: string, options: RequestOptions): Promise<TextResult>
```

**参数**：
- `url: string` — 完整 URL（不含 `X-Api-Key` 注入，由 `HttpClient` 负责）
- `options.method: 'GET' | 'POST'`
- `options.headers?: Record<string, string>`
- `options.body?: string` — POST JSON 字符串

**实现逻辑（伪代码）**：
1. 创建 `http.createHttp()`
2. 配置 `connectTimeout = DEFAULT_TIMEOUT_MS`、`readTimeout = DEFAULT_TIMEOUT_MS`
3. 调用 `httpRequest.request(url, { method, headerData, extraData })`
4. `try-catch (err: BusinessError)` 捕获原生异常，统一 `throw new Error(...)` 包装
5. `finally` 调用 `httpRequest.destroy()`
6. 返回 `{ statusCode: response.responseCode, headers: response.header, rawBody: response.result as string }`

**`RequestOptions` 类型**（在文件内定义）：
```typescript
interface RequestOptions {
  method: 'GET' | 'POST';
  headers?: Record<string, string>;
  body?: string;
}
```

#### `requestRaw`
```typescript
export function requestRaw(url: string, options: RequestOptions): Promise<BinaryResult>
```

**区别于 `request`**：
- 在调用 `httpRequest.request()` 时设置 `expectDataType: http.HttpDataType.ARRAY_BUFFER`
- `response.result` 强转为 `ArrayBuffer` 赋给 `rawBody`

#### `uploadFile`
```typescript
export function uploadFile(
  context: common.UIAbilityContext,
  url: string,
  filePath: string,
  header: Record<string, string>,
  data: Record<string, string>
): Promise<ApiResponse<ImageUploadResult>>
```

**实现逻辑（伪代码）**：
1. 构造 `ohRequest.agent.create()` 上传配置对象：
   - `method: 'POST'`
   - `url`
   - `header`
   - `files: [{ name: 'file', uri: 'file://' + filePath, type: 'jpg' }]`
   - `data`（form 字段）
2. 调用 `ohRequest.uploadFile(context, config)` 拿到 `task` 对象
3. 监听 `task.on('complete', ...)` 与 `task.on('failed', ...)`，包装成 Promise
4. 任务完成后 `task.delete()` 释放
5. 解析响应 JSON 为 `ApiResponse<ImageUploadResult>`

**职责边界**：
- **不**注入 `X-Api-Key`（由调用方在 `header` 中传入）
- **不**解析 JSON（除 `uploadFile` 返回业务结果）
- **不**拼接 `/api/v1` 前缀
- **不**处理业务错误码

**`BusinessError` 使用说明**（R2 修订）：
- `api.ets` 在 `request` / `requestRaw` / `uploadFile` 的 `try-catch` 处使用 `catch (err: BusinessError)` 显式标注错误类型，对原生 `@ohos.net.http` 抛出的 `code`/`message` 属性进行安全访问后包装为标准 `Error` 抛出。该类型守卫确保 `err.code` / `err.message` 访问符合 ArkTS 严格类型检查，避免"any"或"unknown"绕过类型系统。

---

### 7. `harmony-app/entry/src/main/ets/services/HttpClient.ets`（新建）

**导入语句**：
```typescript
import { ApiResponse, TextResult, BinaryResult, RetryPolicyConfig } from '../common/models';
import { API_BASE_URL, API_PATH_PREFIX, API_KEY, HEADER_API_KEY, DEFAULT_TIMEOUT_MS } from '../common/constants';
import { DEFAULT_RETRY } from '../common/RetryPolicy';
import { request, requestRaw } from '../common/api';
import { isNetworkError, sleep } from '../common/utils';
```

> **R2 修订要点**：
> - 追加 `import { isNetworkError, sleep } from '../common/utils';`，确保 `withRetry` 内部引用的两个工具符号可解析。
> - 追加 `RetryPolicyConfig` 类型导入（`withRetry` 的形参类型需要）。

**模块级状态**：
```typescript
export const BASE_URL: string = API_BASE_URL + API_PATH_PREFIX;
export const HEADER_KEY: string = API_KEY;
```

**公开 API**：

#### `get<T>`
```typescript
export function get<T>(path: string, params?: Record<string, string | number | undefined>): Promise<ApiResponse<T>>
```

**实现逻辑（伪代码）**：
1. 构造 `queryString = utils.buildQueryString(params)`
2. `url = BASE_URL + path + queryString`
3. 构造 `headers = { [HEADER_API_KEY]: HEADER_KEY }`
4. 进入重试循环（`attempt` 从 0 开始）：
   - `try`：调用 `api.request(url, { method: 'GET', headers })`
     - 检查 `result.statusCode`：
       - 不在 `DEFAULT_RETRY.retryOn` 中 → 跳出循环
       - 在其中 → 计算 `delay = min(baseDelayMs * 2^attempt, maxDelayMs)`，await `utils.sleep(delay)`，继续下一轮
     - `JSON.parse(result.rawBody)` 强转为 `ApiResponse<T>`
     - 返回
   - `catch(err)`：若是网络错误（`utils.isNetworkError(err)`）且 `attempt < maxRetries`：
     - 同样计算退避延迟并重试
     - 否则 `throw err`
5. 重试耗尽后抛出最后一次错误

#### `post<T>`
```typescript
export function post<T>(path: string, body?: object): Promise<ApiResponse<T>>
```

**实现逻辑（伪代码）**：
1. `url = BASE_URL + path`
2. `headers = { [HEADER_API_KEY]: HEADER_KEY, 'Content-Type': 'application/json' }`
3. `extraData = body ? JSON.stringify(body) : ''`
4. 直接调用 `api.request(url, { method: 'POST', headers, body: extraData })`
5. `JSON.parse` 返回 `ApiResponse<T>`
6. **不**触发重试（POST 非幂等）

#### `getRaw`
```typescript
export function getRaw(path: string, params?: Record<string, string | number | undefined>): Promise<ArrayBuffer>
```

**实现逻辑（伪代码）**：
1. 构造 `url` 同 `get`
2. 构造 `headers` 同 `get`
3. 重试循环（与 `get` 一致）：
   - `api.requestRaw(url, { method: 'GET', headers })`
   - 网络错误或 `statusCode ∈ retryOn` → 退避重试
   - 成功返回 `result.rawBody as ArrayBuffer`
4. 重试耗尽抛错

**重试实现伪代码**（R2 修订：精简控制流，删除不可达的 `lastError` 与末行 `throw`）：
```typescript
async function withRetry(
  operation: () => Promise<TextResult>,
  policy: RetryPolicyConfig = DEFAULT_RETRY
): Promise<TextResult> {
  for (let attempt = 0; attempt <= policy.maxRetries; attempt++) {
    try {
      const result = await operation();
      // 命中可重试状态码：进入下一轮（最后一次时直接抛错，不再 sleep）
      if (policy.retryOn.includes(result.statusCode)) {
        if (attempt === policy.maxRetries) {
          throw new Error(`HTTP ${result.statusCode} after ${policy.maxRetries} retries`);
        }
      } else {
        return result; // 成功或非可重试状态码
      }
    } catch (err) {
      // 网络异常且未到末轮 → 继续重试；其它一律立即抛出
      if (!isNetworkError(err) || attempt === policy.maxRetries) {
        throw err;
      }
    }
    // 退避：base * 2^attempt，截断到 maxDelayMs
    const delay = Math.min(
      policy.baseDelayMs * Math.pow(2, attempt),
      policy.maxDelayMs
    );
    await sleep(delay);
  }
  // 理论上不可达：for 循环体内每次迭代要么 return 要么 throw
  throw new Error('Retry exhausted');
}
```

> **R2 修订说明**：
> - 删除 `let lastError: Error | null = null` 变量及每次 catch 中的赋值，因该变量在控制流中从未被读出。
> - 保留 `throw new Error('Retry exhausted')` 作为 TypeScript 严格类型检查的"函数级终结"占位（for 循环条件为 `<=` 时编译器仍需该路径以满足"所有路径都有返回或抛出"的签名约束）；实际运行中该行不可达。
> - `HTTP ${statusCode} after ${policy.maxRetries} retries` 的措辞修正：用 `policy.maxRetries` 而非 `attempt` 表示"已用尽配置的 N 次重试"，语义更清晰。

**职责边界**：
- 注入 `X-Api-Key` 头
- 拼接 `BASE_URL + path`
- JSON 序列化/反序列化
- 错误码透传（不抛业务异常）
- 指数退避重试（仅 `get` / `getRaw`）
- **不**做业务错误码语义判断（由 Service / Page 处理）

---

### 8. `harmony-app/entry/src/main/ets/services/PollingManager.ets`（新建，占位）

**导入语句**：
```typescript
import { PollingCallback } from '../common/models';
```

**模块级状态**：
```typescript
interface PollingTask {
  running: boolean;
  // 实际调度字段（fn, interval, timerId）留待后续轮次补全
}

const tasks: Map<string, PollingTask> = new Map();
```

**公开 API**：

| 方法 | 签名 | 占位实现 |
|------|------|---------|
| `start` | `start(_key: string, _fn: PollingCallback, _interval: number): void` | 若 `tasks.has(_key)` 则先 `tasks.delete(_key)`；`tasks.set(_key, { running: true })`；**不调用 `_fn`**，不创建定时器 |
| `stop` | `stop(key: string): void` | `tasks.delete(key)` |
| `stopAll` | `stopAll(): void` | `tasks.clear()` |
| `suspendAll` | `suspendAll(): void` | 遍历 `tasks`，将 `running` 置 `false` |
| `resumeAll` | `resumeAll(): void` | 遍历 `tasks`，将 `running` 置 `true` |

> **R2 修订要点**：`start` 方法的形参命名采用下划线前缀（`_key`、`_fn`、`_interval`），显式表明占位阶段参数被有意忽略，避免 ArkTS 严格类型 / lint 规则对"未使用形参"产生 warning。

**导出形式**：
```typescript
export const PollingManager = {
  start, stop, stopAll, suspendAll, resumeAll
};
```

**占位边界声明**：
- 本轮 `_fn` 参数被忽略，`_interval` 参数被忽略
- `running` 字段仅作为状态标记，无任何代码读取或据此分支
- 不创建 `setTimeout` / `setInterval`
- 不在 `start` 中立即调用 `_fn`
- 后续轮次实现实际调度时，需补全 `currentTimer?: number`、`executeTick()` 等字段
- 当前实现保证：`EntryAbility.onBackground()` / `onForeground()` 调用 `suspendAll` / `resumeAll` 时链路编译通过且无运行时错误

---

### 9. `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets`（改造）

**导入语句变更**：
```typescript
// 保留原有
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

// 新增
import { PollingManager } from '../services/PollingManager';
```

**改造点**：

#### `onForeground` 方法
```typescript
onForeground(): void {
  hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  PollingManager.resumeAll();  // 新增
}
```

#### `onBackground` 方法
```typescript
onBackground(): void {
  hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  PollingManager.suspendAll();  // 新增
}
```

**保持不变**：
- `DOMAIN` 常量
- `onCreate` / `onDestroy` / `onWindowStageCreate` / `onWindowStageDestroy` 内部逻辑
- 类结构、继承关系、export 形式

**职责边界**：
- `EntryAbility` 仅做"前后台切换"与"轮询暂停/恢复"的胶水调用
- 不持有任何轮询状态
- 依赖 `PollingManager` 的 `suspendAll` / `resumeAll` 静态方法存在性

---

## 配置与依赖清单

### 第三方 SDK 依赖（`@kit.*` 内建，无需 oh-package.json5 声明）

| 模块 | 来源 | 用途 |
|------|------|------|
| `@kit.AbilityKit` | SDK 内建 | `UIAbility`、`AbilityConstant`、`ConfigurationConstant`、`Want`、`common` |
| `@kit.PerformanceAnalysisKit` | SDK 内建 | `hilog` |
| `@kit.ArkUI` | SDK 内建 | `window` |
| `@kit.NetworkKit` | SDK 内建 | `http`（替代 `@ohos.net.http`） |
| `@kit.RequestKit` | SDK 内建 | `request`（替代 `@ohos.request`），导入重命名为 `ohRequest` 以避免与文件导出冲突 |
| `@kit.BasicServicesKit` | SDK 内建 | `BusinessError`（用于 `api.ets` 的 `catch` 类型守卫） |

> **风险说明**：ArkTS 的 `@kit.*` 模块名与原 `@ohos.*` 模块名可能在编译期因 SDK 版本不同而需要切换。编码实现期若 `@kit.NetworkKit` / `@kit.RequestKit` 编译失败，应回退到 `@ohos.net.http` / `@ohos.request`。本设计规格优先采用 `@kit.*` 命名（与 `@kit.AbilityKit` 风格一致）。

### 不变更的文件
- `harmony-app/entry/oh-package.json5`
- `harmony-app/oh-package.json5`
- `harmony-app/entry/src/main/module.json5`
- `harmony-app/entry/src/main/resources/base/profile/main_pages.json`
- `harmony-app/entry/src/main/ets/pages/Index.ets`
- `harmony-app/entry/src/main/ets/entrybackupability/EntryBackupAbility.ets`

---

## 编译验证基线

完成后预期命令：
```bash
hvigorw assembleHap --mode module -p product=default
```

应满足：
- exit code = 0
- 无 `error:` 行
- 允许 `warning:` 行（如未使用导入，实现期应避免）

---

## 实施风险与边界声明

| 风险点 | 边界 / 缓解 |
|--------|------------|
| `@kit.NetworkKit` 模块名编译失败 | 回退 `@ohos.net.http` |
| `@kit.RequestKit` 模块名编译失败 | 回退 `@ohos.request` |
| `common.UIAbilityContext` 类型导出路径 | 优先 `@kit.AbilityKit`；失败回退 `@ohos.app.ability.UIAbilityContext` |
| `PollingManager` 占位 vs 后续轮次 API 稳定性 | 当前实现的 5 个方法签名（`start/stop/stopAll/suspendAll/resumeAll`）与 `docs/4_hamony-architecture.md` 9. PollingManager 一致，后续轮次仅填充内部实现，不变更公开签名 |
| `request.uploadFile` 在某些 HarmonyOS API 版本中签名差异 | 实现期需按 `@ohos.request.uploadFile` 实际文档适配；当前仅提供意图性伪代码 |
| `EntryAbility` 改造引入循环依赖 | `EntryAbility` 依赖 `PollingManager`；`PollingManager` 不依赖 `EntryAbility`，无循环 |
| ArkTS 严格类型不允许 `any` / 隐式 `any` | 所有类型显式声明，泛型边界清晰；JSON 解析处使用 `JSON.parse(...) as ApiResponse<T>` 强转 |
| `HttpRequest.destroy()` 必须配对 `createHttp()` | `api.ets` 内部 `try-finally` 保证销毁 |
| `DEFAULT_RETRY.timeoutMs` 当前无运行时消费者 | 见 §3 与 §7 的"timeoutMs 字段语义说明"：保留是为后续动态超时策略预留，避免破坏依赖契约 |
| `withRetry` 末行 `throw new Error('Retry exhausted')` 实际不可达 | 仅为满足 ArkTS 严格类型"所有路径终结"约束的占位；运行时实际触发条件已被 `for` 体内 `return` / `throw` 完全覆盖 |
| `PollingManager.start` 占位形参 `_fn` / `_interval` 当前被忽略 | 占位边界已声明；下划线前缀显式标注"故意忽略"，避免 lint warning |

---

## 修订说明（R1 r2）

| 审查意见 | 修改措施 |
|---------|---------|
| **[一般] HttpClient.ets 缺少 `isNetworkError` / `sleep` 导入** | §7 `HttpClient.ets` 的"导入语句"块追加 `import { isNetworkError, sleep } from '../common/utils';`，确保 `withRetry` 内部符号可解析。同时追加 `RetryPolicyConfig` 类型导入（`withRetry` 形参类型需要） |
| **[一般] `api.ets` 中 `request` 导入与文件导出同名冲突** | §6 `api.ets` 的"导入语句"块将 `@kit.RequestKit` 的导入改为 `import { request as ohRequest } from '@kit.RequestKit';`；`uploadFile` 伪代码中相应改为 `ohRequest.uploadFile(...)` 与 `ohRequest.agent.create()` |
| **[一般] `models.ets` 缺少 `CommandResponse` 接口** | §类型定义新增 `CommandResponse`（`command_id`/`device_id`/`command`/`status` 四字段，依据 `docs/3_client-api-reference.md` §2.5.1）；§1 业务实体分组也对应加入 `CommandResponse` 导出项 |
| **[轻微] `withRetry` 伪代码 `lastError` 不可达** | §7 `withRetry` 伪代码：删除 `let lastError` 变量与每次 catch 中的赋值，删除末行 `throw lastError ?? new Error(...)`，替换为不可达但满足类型检查的 `throw new Error('Retry exhausted')` 终结占位 |
| **[轻微] `api.ets` 的 `BusinessError` 导入未使用** | §6 在 `request` / `requestRaw` / `uploadFile` 的 `try-catch` 处改为 `catch (err: BusinessError)`，使 `@kit.BasicServicesKit` 的导入在源码中有实际消费点（用于 `err.code` / `err.message` 的类型守卫访问），避免 lint warning |
| **[轻微] `PollingManager.start` 占位形参未使用** | §8 `start` 方法签名改为 `start(_key: string, _fn: PollingCallback, _interval: number): void`，下划线前缀显式标注"故意忽略"；"占位边界声明"同步更新 |
| **[轻微] `DEFAULT_RETRY.timeoutMs` 字段无运行时消费者** | §3 末尾新增"`timeoutMs` 字段语义说明"段落；§7 职责边界表中相应体现；§实施风险与边界声明新增对应风险行；保留字段是为后续动态超时策略预留接口，避免破坏 `RetryPolicyConfig` 依赖契约 |