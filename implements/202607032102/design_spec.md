# 设计规格（R2）

## 概述

实现 `services/` 层全部 6 个业务 Service + 将 PollingManager 占位升级为真实递归 setTimeout 串行调度。完成后 `harmony-app` 必须能够通过 ArkTS 编译，无 error。

**范围**：
- 6 个新 Service 文件：DeviceService、SensorService、DiseaseService、CommandService、AdvisoryService、ImageService
- PollingManager 真实实现（从 R1 占位升级）

**非范围**（后续轮次）：
- UI 组件层（SensorCard / ChartView / ControlButton 等）→ R3+
- 页面层（DashboardPage / DiseaseRecordsPage / ControlPage / AdvisoryPage）→ R3+
- 单元测试 → 独立测试轮次
- common 层 → R1 已固化，本轮不修改
- HttpClient、EntryAbility → R1 已固化，本轮不修改

**R1 契约复用**（已固化于 `common/` 层，本轮直接消费）：
- `HttpClient.get<T>(path, params?)` / `HttpClient.post<T>(path, body?)` / `HttpClient.getRaw(path, params?)`
- `HttpClient.get` / `getRaw` 自动注入 `X-Api-Key` + 拼接 `BASE_URL = API_BASE_URL + API_PATH_PREFIX` + 指数退避重试（GET 3 次）
- `HttpClient.post` 不重试（非幂等），但自动注入 `X-Api-Key` + 序列化 JSON body
- `ApiResponse<T>` = `{ code: number, message: string, data: T | null }`
- `BASE_URL` 与 `HEADER_KEY` 已 export 供 `ImageService` 引用

**设计取舍**：
- 本设计采用用户指令中的 Service 方法签名（直接返回业务类型，不包 `ApiResponse` 壳），由 Service 层负责"通过则解包 `data`，失败则抛 `Error(message)`"的语义统一；这与 R1 中 `HttpClient` 透传 `ApiResponse` 的契约是清晰的层级边界——`HttpClient` 负责传输，`Service` 负责业务语义。
- 此处与 `plan_task.md` §"CommandService 失败路径刷新设备缓存" 描述中的"返回 `ApiResponse`"约定有差异；本设计优先遵循用户最终指令中明确的"方法直接返回业务类型"的设计原则（详见 R2 偏差说明）。
- `CacheManager` 写入策略：所有缓存写入由 Service 在成功拿到 `ApiResponse` 且 `code === 0` 时进行；缓存值类型与 Service 公开方法返回类型一致（即"已解包的业务数据"），不存储 `ApiResponse` 壳。

---

## 文件规划

| 文件路径 | 操作 | 职责 |
|---------|------|------|
| `harmony-app/entry/src/main/ets/services/DeviceService.ets` | 新建 | 设备列表缓存 + 远程拉取 |
| `harmony-app/entry/src/main/ets/services/SensorService.ets` | 新建 | 传感器最新/历史/日聚合 |
| `harmony-app/entry/src/main/ets/services/DiseaseService.ets` | 新建 | 病虫害列表/统计/热力图 |
| `harmony-app/entry/src/main/ets/services/CommandService.ets` | 新建 | 设备控制命令下发 + 日志 |
| `harmony-app/entry/src/main/ets/services/AdvisoryService.ets` | 新建 | 综合防治建议 |
| `harmony-app/entry/src/main/ets/services/ImageService.ets` | 新建 | 图像上传 + 二进制下载 |
| `harmony-app/entry/src/main/ets/services/PollingManager.ets` | 改造 | 从 R1 占位升级为真实递归 setTimeout 串行调度 |

---

## 类型定义

### DeviceInfo / SensorSnapshot / DiseaseRecord / CommandRequest / CommandResponse / CommandLog / DiseaseStats / HeatmapData / SensorHistory / DailyAggregation / Advisory / ImageUploadResult / PaginatedData

**形态**：`interface`
**包路径**：`common/models.ets`（R1 已固化）
**职责**：业务数据模型，本轮 Service 直接 import 消费，无新增。

### PollingTask

**形态**：`interface`（模块内私有）
**包路径**：`services/PollingManager.ets`
**职责**：轮询任务条目，描述单个 key 对应的轮询状态、回调、间隔、定时器句柄。
```typescript
interface PollingTask {
  running: boolean;
  suspended: boolean;
  fn: PollingCallback;
  intervalMs: number;
  timerId: number | null;
}
```

**公开接口**：仅作为模块内 `tasks: Map<string, PollingTask>` 的值类型，不导出。

**构造方式**：直接对象字面量 `tasks.set(key, { running: true, suspended: false, fn, intervalMs, timerId: null })`。

**类型关系**：组合 `PollingCallback`（来自 `common/models.ets`）。

---

## 错误处理

### 错误来源

| 来源 | 说明 | 抛出方 |
|------|------|--------|
| **网络层原生异常** | `HttpClient.get/post/getRaw` 内部重试耗尽后抛出 `Error`（如 `HTTP 503 after 3 retries`） | `HttpClient` |
| **JSON 解析失败** | `HttpClient` 内部捕获后包装 `Error('JSON parse error: ...')` 抛出 | `HttpClient` |
| **业务错误** | `ApiResponse.code !== 0` 时，**Service 层**从 `ApiResponse.message` 构造 `Error` 抛出 | 本轮 Service |
| **设备离线** | `CommandService.send` 命中 `code === 1003` 时，先调用 `DeviceService.refreshDevices()` 刷新缓存，**再**以 `code` 对应 `message` 抛 `Error` | `CommandService` |
| **前置校验失败** | `CommandService.send` 在请求前检查设备 `online === false` 时直接 `throw new Error('Device offline')` | `CommandService` |

### Service 层错误统一策略

所有 Service 方法遵循"**成功返回业务类型 / 失败抛 `Error(message)`**"的语义统一约定：

```typescript
// 伪代码模板
async function someServiceCall(...): Promise<BusinessType> {
  const resp: ApiResponse<BusinessType> = await HttpClient.get<BusinessType>(...);
  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Business error');
  }
  return resp.data;
}
```

- 成功路径（`code === 0` 且 `data !== null`）：返回 `data`（已解包）
- 业务失败路径（`code !== 0`）：抛 `new Error(resp.message)`，不返回 `ApiResponse` 壳
- 网络层异常：由 `HttpClient` 抛出的 `Error` 直接向上传播，**Service 不重复包装**，保留原始堆栈与 message

### 缓存命中与失败的协作

- `getCachedXxx` 类方法：仅读缓存，过期/不存在返回 `null`，**不抛错**
- `Xxx` 类方法：缓存不命中时远程获取，远程获取也失败则抛 `Error`（缓存只用于"成功数据"兜底，不写入失败状态）
- 缓存写入条件：`code === 0` 且 `data !== null` 时调用 `CacheManager.set(key, data, ttl)`

---

## 行为契约

### DeviceService.ets

#### 模块级状态
```typescript
let cachedDevices: DeviceInfo[] = [];
let lastFetchTime: number = 0;
```

> **R2 偏差说明**：`cachedDevices` 初始化为空数组（`[]`）而非 `null`；这样调用方在缓存未命中时得到的也是空数组（"无设备"），与"未初始化"语义一致。`lastFetchTime = 0` 表示"从未获取"。

#### 公开 API

##### `getDeviceList(deviceId?: string): Promise<DeviceInfo[]>`
- **行为**：强制远程拉取 `GET /device/list`（可选 `device_id` 过滤），**不读缓存**；成功后将结果写入 `CacheManager`（key = `CACHE_KEY_PREFIX_DEVICE_LIST + (deviceId ?? 'all')`），同时更新模块级 `cachedDevices` 与 `lastFetchTime`。
- **TTL**：写入时使用 `CACHE_TTL_DEVICE_MS`。
- **前置条件**：`HttpClient` 已加载
- **后置条件**：模块级缓存与 `CacheManager` 一致
- **错误处理**：网络/业务失败抛 `Error`

##### `getCachedDevices(deviceId?: string): DeviceInfo[]`
- **行为**：仅读模块级 `cachedDevices`；**不进行远程拉取**。若 `lastFetchTime === 0` 返回 `[]`（语义"缓存未初始化"）；若缓存超过 `CACHE_TTL_DEVICE_MS`，仍返回当前缓存（**不主动失效**——调用方可自行决定是否 `refreshDevices`）。
- **设备过滤**：`deviceId` 提供时，返回 `cachedDevices.filter(d => d.device_id === deviceId)`；未提供时返回 `cachedDevices` 引用本身。
- **后置条件**：同步返回，不抛错
- **用途**：供 `CommandService` 等"快速判断设备在线状态"场景使用，避免触发远程请求

##### `refreshDevices(deviceId?: string): Promise<DeviceInfo[]>`
- **行为**：与 `getDeviceList` 内部逻辑一致；当前实现直接 `return getDeviceList(deviceId)`。
- **设计意图**：为 `CommandService` 失败路径刷新缓存提供显式入口；语义"主动刷新"。

#### 内部缓存键生成
```typescript
function cacheKey(deviceId?: string): string {
  return CACHE_KEY_PREFIX_DEVICE_LIST + (deviceId ?? 'all');
}
```

#### 行为流程（`getDeviceList` 内部）
1. 构造 `queryParams = deviceId !== undefined ? { device_id: deviceId } : {}`
2. `const resp = await HttpClient.get<DeviceInfo[]>('/device/list', queryParams)`
3. 若 `resp.code === 0 && resp.data !== null`：
   - `CacheManager.set(cacheKey(deviceId), resp.data, CACHE_TTL_DEVICE_MS)`
   - 若 `deviceId === undefined`（全量拉取），更新 `cachedDevices = resp.data`、`lastFetchTime = nowMs()`
   - 若 `deviceId` 存在，**不更新模块级 `cachedDevices`**（避免单设备结果覆盖全量缓存）
4. 若失败，抛 `new Error(resp.message)`

#### 依赖
- `HttpClient.get<T>(path, params?)`
- `CacheManager.set/get`
- `DeviceInfo`（`common/models`）
- `CACHE_KEY_PREFIX_DEVICE_LIST`、`CACHE_TTL_DEVICE_MS`（`common/constants`）
- `nowMs()`（`common/utils`，用于 `lastFetchTime` 记录）

---

### SensorService.ets

#### 公开 API

##### `getLatest(deviceId: string): Promise<SensorSnapshot>`
- **行为**：`GET /sensor/latest?device_id=xxx`
- **缓存**：key = `CACHE_KEY_PREFIX_SENSOR_LATEST + deviceId`，TTL = `CACHE_TTL_SENSOR_MS`
- **返回类型**：单个 `SensorSnapshot` 对象（不带 `deviceId` 时后端返回数组，本方法**强制要求 `deviceId`**；若调用方传 `undefined`，按 `?? ''` 转为空字符串以满足后端参数规则）
- **错误处理**：业务失败抛 `Error`

> **R2 偏差说明**：用户指令要求 `getLatest(deviceId: string): Promise<SensorSnapshot>` 强制 `deviceId`；与 `plan_task.md` 中"`deviceId?` 可选"略有差异。本设计以"调用方传字符串（可为空字符串）"实现向后兼容，缓存键仍为 `sensor_latest_<deviceId>`。空 `deviceId` 视作"无设备过滤"，后端将返回数组形态——但本方法签名返回 `SensorSnapshot`，**实现期会断言 `Array.isArray(resp.data) === false`**，若不满足则抛 `Error('Expected single sensor snapshot')`。这与 R1 中 `/sensor/latest` 端点的"传 `device_id` 时返回单条"语义一致。

##### `getAllLatest(): Promise<SensorSnapshot[]>`
- **行为**：等价于 `HttpClient.get('/sensor/latest')`（不传 `device_id`），返回所有设备的最新快照数组
- **缓存**：key = `CACHE_KEY_PREFIX_SENSOR_ALL_LATEST`（**固定键**，无参数），TTL = `CACHE_TTL_SENSOR_MS`
- **错误处理**：业务失败抛 `Error`

##### `getHistory(deviceId: string, start?: string, end?: string, page?: number, pageSize?: number): Promise<PaginatedData<SensorHistory>>`
- **行为**：`GET /sensor/history`，query = `{ device_id, start?, end?, page?, page_size? }`
- **缓存**：**不缓存**（分页+时间范围组合空间大）
- **参数映射**：`pageSize` → query 参数名 `page_size`（snake_case 转换）
- **错误处理**：业务失败抛 `Error`

##### `getDaily(deviceId: string, start: string, end: string, page?: number, pageSize?: number): Promise<PaginatedData<DailyAggregation>>`
- **行为**：`GET /sensor/daily`，query = `{ device_id, start, end, page?, page_size? }`
- **缓存**：**不缓存**
- **参数映射**：同上
- **错误处理**：业务失败抛 `Error`

#### 行为流程（以 `getLatest` 为例）
1. 构造缓存键 `key = CACHE_KEY_PREFIX_SENSOR_LATEST + deviceId`
2. 读 `CacheManager.get<SensorSnapshot>(key)`；命中则直接返回
3. 未命中则 `const resp = await HttpClient.get<SensorSnapshot>('/sensor/latest', { device_id: deviceId })`
4. 成功且 `data !== null` → `CacheManager.set(key, resp.data, CACHE_TTL_SENSOR_MS)` + 返回
5. 失败 → 抛 `Error`

#### 依赖
- `HttpClient.get<T>`
- `CacheManager.set/get`
- `SensorSnapshot` / `SensorHistory` / `DailyAggregation` / `PaginatedData`（`common/models`）
- `CACHE_KEY_PREFIX_SENSOR_LATEST` / `CACHE_KEY_PREFIX_SENSOR_ALL_LATEST` / `CACHE_TTL_SENSOR_MS`（`common/constants`）

---

### DiseaseService.ets

#### 公开 API

##### `getList(filters?: { device_id?, crop_type?, disease_type?, severity?, start?, end?, page?, page_size? }): Promise<PaginatedData<DiseaseRecord>>`
- **行为**：`GET /disease/list`，query = filters（undefined 字段自动跳过，由 `HttpClient.get` → `buildQueryString` 过滤）
- **缓存**：**不缓存**（多维筛选+分页组合空间大）
- **错误处理**：业务失败抛 `Error`

##### `getStats(start?: string, end?: string): Promise<DiseaseStats>`
- **行为**：`GET /disease/stats`，query = `{ start?, end? }`
- **缓存**：key = `CACHE_KEY_PREFIX_DISEASE_STATS + (start + '_' + end)`，TTL = `CACHE_TTL_DISEASE_MS`
  - 当 `start`/`end` 均为 `undefined` 时，key = `CACHE_KEY_PREFIX_DISEASE_STATS + 'all_all'`（保证 key 不为空字符串）
- **错误处理**：业务失败抛 `Error`

##### `getHeatmap(start?: string, end?: string): Promise<HeatmapData>`
- **行为**：`GET /disease/heatmap`，query = `{ start?, end? }`
- **缓存**：key = `CACHE_KEY_PREFIX_DISEASE_HEATMAP`（**全局数据，固定键**），TTL = `CACHE_TTL_DISEASE_MS`
- **错误处理**：业务失败抛 `Error`

#### 行为流程（以 `getStats` 为例）
1. 构造缓存键 `key = CACHE_KEY_PREFIX_DISEASE_STATS + (start ?? 'all') + '_' + (end ?? 'all')`
2. 读 `CacheManager.get<DiseaseStats>(key)`；命中则直接返回
3. 未命中则 `const resp = await HttpClient.get<DiseaseStats>('/disease/stats', { start, end })`
4. 成功且 `data !== null` → `CacheManager.set(key, resp.data, CACHE_TTL_DISEASE_MS)` + 返回
5. 失败 → 抛 `Error`

#### 依赖
- `HttpClient.get<T>`
- `CacheManager.set/get`
- `DiseaseRecord` / `DiseaseStats` / `HeatmapData` / `PaginatedData`（`common/models`）
- `CACHE_KEY_PREFIX_DISEASE_STATS` / `CACHE_KEY_PREFIX_DISEASE_HEATMAP` / `CACHE_TTL_DISEASE_MS`（`common/constants`）

---

### CommandService.ets

#### 公开 API

##### `send(deviceId: string, command: string, source?: string, operator?: string): Promise<CommandResponse>`
- **行为**：`POST /command/send`，body = `{ device_id, command, source?, operator? }`
- **前置校验**（优化路径）：
  1. 调用 `DeviceService.getCachedDevices(deviceId)` 检查设备在线状态
  2. 若返回数组中存在 `d.device_id === deviceId` 且 `d.online === false`，**直接 `throw new Error('Device offline')`**，不发送请求
  3. 若缓存中未找到该设备（缓存未初始化或已过期且无此设备），**放行**——不做悲观阻断（远程可能已更新状态）
- **缓存**：**不缓存** `send` 结果（每次都是真实操作）
- **失败路径刷新**：
  - 当 `resp.code === ERR_CODE_DEVICE_OFFLINE (1003)` 时：
    1. `await DeviceService.refreshDevices(deviceId)`（fire-and-forget 或 await 均可，**实现期统一采用 `await` 以保证刷新完成后再抛错**，确保调用方下次读取时已为最新）
    2. `throw new Error(resp.message)`（保持与其它业务错误一致的抛错语义）
  - 当 HTTP 层抛错（网络异常）时，**不**主动刷新缓存（设备可能仅是网络问题，避免无意义刷新）

##### `getLogs(deviceId?: string, source?: string, start?: string, end?: string, page?: number, pageSize?: number): Promise<PaginatedData<CommandLog>>`
- **行为**：`GET /command/logs`，query = `{ device_id?, source?, start?, end?, page?, page_size? }`
- **缓存**：**不缓存**（分页+筛选组合空间大）
- **错误处理**：业务失败抛 `Error`

#### 行为流程（`send`）
1. 前置校验：`const cached = DeviceService.getCachedDevices(deviceId)`
2. 找到设备且 `online === false` → `throw new Error('Device offline')`
3. 构造 body：`{ device_id: deviceId, command, source, operator }`（undefined 字段由 JSON.stringify 自然忽略）
4. `const resp = await HttpClient.post<CommandResponse>('/command/send', body)`
5. 若 `resp.code === 0 && resp.data !== null` → 返回 `resp.data`
6. 若 `resp.code === 1003` → `await DeviceService.refreshDevices(deviceId)`，再 `throw new Error(resp.message)`
7. 其它业务错误 → `throw new Error(resp.message)`

#### 依赖
- `HttpClient.post<T>`
- `DeviceService.getCachedDevices` / `DeviceService.refreshDevices`（**同模块循环依赖 → 实际实现采用从 `./DeviceService` 直接 `import` 静态对象 `DeviceService`，ArkTS 允许模块间循环 import，只要不在模块顶层执行实例化逻辑**）
- `CommandResponse` / `CommandLog` / `PaginatedData`（`common/models`）
- `ERR_CODE_DEVICE_OFFLINE`（`common/constants`）

> **循环依赖说明**：`CommandService` → `DeviceService` 是单向依赖（`DeviceService` 不依赖 `CommandService`），无循环。`getCachedDevices` 是同步方法，不触发异步链路，避免死锁。

---

### AdvisoryService.ets

#### 公开 API

##### `getAdvisory(deviceId?: string, start?: string, end?: string, windowMinutes?: number): Promise<Advisory>`
- **行为**：`GET /advisory`，query = `{ device_id?, start?, end?, window_minutes? }`
- **缓存键**：`CACHE_KEY_PREFIX_ADVISORY + (deviceId ?? 'all') + '_' + (windowMinutes ?? 'all')`
  - 当 `deviceId` 与 `windowMinutes` 均为 `undefined` 时，key = `CACHE_KEY_PREFIX_ADVISORY + 'all_all'`
  - **不包含** `start`/`end`（与用户指令一致："缓存 key 含 deviceId 参数"——本设计同时包含 `windowMinutes` 以适配不同轮询窗口的差异化缓存）
- **TTL**：`CACHE_TTL_ADVISORY_MS`（30s）
- **错误处理**：业务失败抛 `Error`

#### 行为流程
1. 构造缓存键 `key = CACHE_KEY_PREFIX_ADVISORY + (deviceId ?? 'all') + '_' + (windowMinutes ?? 'all')`
2. 读 `CacheManager.get<Advisory>(key)`；命中则直接返回
3. 未命中则 `const resp = await HttpClient.get<Advisory>('/advisory', { device_id, start, end, window_minutes: windowMinutes })`
4. 成功且 `data !== null` → `CacheManager.set(key, resp.data, CACHE_TTL_ADVISORY_MS)` + 返回
5. 失败 → 抛 `Error`

#### 依赖
- `HttpClient.get<T>`
- `CacheManager.set/get`
- `Advisory`（`common/models`）
- `CACHE_KEY_PREFIX_ADVISORY` / `CACHE_TTL_ADVISORY_MS`（`common/constants`）

---

### ImageService.ets

#### 公开 API

##### `uploadImage(context: common.UIAbilityContext, filePath: string, diseaseRecordId?: number, deviceId?: string): Promise<ImageUploadResult>`
- **行为**：委托给 `api.uploadFile()`，由 `ImageService` 注入 `X-Api-Key` 头部
- **实现步骤**：
  1. 构造 `header = { [HEADER_API_KEY]: HEADER_KEY }`（`HEADER_KEY` 来自 `HttpClient`）
  2. 构造 `data: Record<string, string> = {}`；若 `diseaseRecordId !== undefined` → `data.disease_record_id = String(diseaseRecordId)`；若 `deviceId !== undefined` → `data.device_id = deviceId`
  3. 构造 `url = BASE_URL + '/image/upload'`（`BASE_URL` 来自 `HttpClient`）
  4. `const resp = await api.uploadFile(context, url, filePath, header, data)`
  5. 若 `resp.code === 0 && resp.data !== null` → 返回 `resp.data`
  6. 失败 → `throw new Error(resp.message)`
- **缓存**：**不缓存**（上传结果不可重复使用）

##### `getImagePixelMap(path: string): Promise<ArrayBuffer>`
- **行为**：调用 `HttpClient.getRaw('/image/' + imageId)` 获取二进制数据
- **实现**：
  ```typescript
  return HttpClient.getRaw('/image/' + path);
  ```
- **不缓存**（ArrayBuffer 体积大；`HttpClient.getRaw` 内部已注入 `X-Api-Key` + 重试 3 次）
- **不做解码**——调用方（`ImageViewer` 组件）负责 `image.createImageSource(...).createPixelMap(...)`

> **参数命名说明**：用户指令中使用 `path: string`，本设计遵循。语义上该参数是 `imageId`（如 `img_20260703_061500_021`），传入后拼为 `/image/<imageId>`。此命名延续用户原话以避免接口漂移。

#### 依赖
- `HttpClient.BASE_URL` / `HttpClient.HEADER_KEY`（`services/HttpClient.ets` 的 export）
- `api.uploadFile`（`common/api.ets`）
- `HttpClient.getRaw`（`services/HttpClient.ets`）
- `ImageUploadResult`（`common/models`）
- `common.UIAbilityContext`（`@kit.AbilityKit`）
- `HEADER_API_KEY`（`common/constants`）

---

### PollingManager.ets（真实实现）

#### 模块级状态
```typescript
const tasks: Map<string, PollingTask> = new Map();
```

#### 内部 `PollingTask` 结构
```typescript
interface PollingTask {
  running: boolean;
  suspended: boolean;
  fn: PollingCallback;
  intervalMs: number;
  timerId: number | null;
}
```

#### 公开 API

##### `start(key: string, fn: PollingCallback, intervalMs: number): void`
- **行为**：
  1. 若 `tasks.has(key)` → 调用 `stop(key)` 清理旧任务（含 `clearTimeout`）
  2. 创建 `PollingTask`：`{ running: true, suspended: false, fn, intervalMs, timerId: null }`
  3. `tasks.set(key, task)`
  4. 调用 `scheduleNext(key)` 注册首个 `setTimeout`
- **串行约束**：**不**在 `start` 中立即执行 `fn`；首个 tick 在 `setTimeout` 触发后执行
- **错误处理**：参数无校验（依赖 TypeScript 编译期类型）

##### `stop(key: string): void`
- **行为**：
  1. `const task = tasks.get(key)`
  2. 若 `task === undefined` → 直接返回
  3. 若 `task.timerId !== null` → `clearTimeout(task.timerId)`
  4. `tasks.delete(key)`

##### `stopAll(): void`
- **行为**：
  1. 遍历 `tasks` 所有值，对 `task.timerId !== null` 的项 `clearTimeout`
  2. `tasks.clear()`

##### `suspendAll(): void`
- **行为**：
  1. 遍历 `tasks` 所有值，对 `task.timerId !== null` 的项 `clearTimeout`，将 `task.timerId` 置 `null`
  2. 对所有 task 置 `task.suspended = true`
  3. **保留** task 引用（不 delete），用于 `resumeAll` 恢复
- **用途**：`EntryAbility.onBackground` 调用，App 切后台时暂停所有轮询

##### `resumeAll(): void`
- **行为**：
  1. 遍历 `tasks` 所有值，对 `task.suspended === true` 的项：
     - 置 `task.suspended = false`
     - 调用 `scheduleNext(key)` 重启定时器
  2. 对 `task.suspended === false` 的项（如 `stopAll` 后残留的引用等异常情况），不重启
- **用途**：`EntryAbility.onForeground` 调用，App 切回前台时恢复所有轮询

#### 私有方法 `scheduleNext(key: string): void`
- **行为**：
  1. `const task = tasks.get(key)`
  2. 若 `task === undefined` 或 `task.suspended === true` → 直接返回
  3. `task.timerId = setTimeout(() => { tick(key); }, task.intervalMs)`（`setTimeout` 在 HarmonyOS ArkTS 中返回 `number`）

#### 私有方法 `tick(key: string): void`
- **行为**：
  1. `const task = tasks.get(key)`
  2. 若 `task === undefined` 或 `task.suspended === true` → 直接返回（已被 stop/suspend）
  3. `task.timerId = null`（当前 tick 已完成）
  4. `task.fn()` → `.then(() => { /* 串行调度下一 tick */ })` / `.catch((err) => { console.error('PollingManager tick error', JSON.stringify(err)); /* 不中断轮询 */ })`
  5. 在 `.then` / `.catch` 的 finally 分支中：
     - 再次检查 `tasks.get(key)` 是否仍存在且未 suspended
     - 若条件满足 → 递归调用 `scheduleNext(key)` 注册下一 tick
- **串行模式**：上一个 tick resolve/reject 后才安排下一个 setTimeout（不并发）

#### 行为流程（完整生命周期）
```
EntryAbility.onCreate → PollingManager 空 tasks
Page.onPageShow → PollingManager.start('sensor', refreshFn, 10000)
  ├─ tasks.set('sensor', { running: true, suspended: false, fn: refreshFn, intervalMs: 10000, timerId: null })
  └─ scheduleNext('sensor')
       └─ task.timerId = setTimeout(tick, 10000)
            └─ 10000ms 后 tick('sensor')
                 ├─ task.timerId = null
                 ├─ task.fn() → 成功或失败
                 └─ finally: 仍 running 且未 suspended → scheduleNext('sensor') 继续
App.onBackground → PollingManager.suspendAll()
  ├─ 遍历 tasks，对所有 timerId clearTimeout，置 suspended = true
  └─ task 引用保留
App.onForeground → PollingManager.resumeAll()
  ├─ 遍历 tasks，对 suspended === true 的项：
  │   ├─ suspended = false
  │   └─ scheduleNext(key) 重新注册 setTimeout
  └─ suspended === false 的项不重启
Page.onPageHide → PollingManager.stop('sensor')
  ├─ clearTimeout(timerId)
  └─ tasks.delete('sensor')
```

#### 导出形式
```typescript
export const PollingManager = {
  start: start,
  stop: stop,
  stopAll: stopAll,
  suspendAll: suspendAll,
  resumeAll: resumeAll
};
```

#### 依赖
- `PollingCallback`（`common/models.ets`）
- `console`（全局）

> **API 兼容性声明**：`start/stop/stopAll/suspendAll/resumeAll` 五个公开方法签名与 R1 占位完全一致（`EntryAbility` 已调用），不破坏现有调用点。

---

## 依赖关系

### 模块依赖图（R2 新增 + 改造）

```
services/DeviceService.ets
    ├─→ services/HttpClient.ets（get）
    ├─→ common/CacheManager.ets（set）
    ├─→ common/models.ets（DeviceInfo）
    ├─→ common/constants.ets（CACHE_KEY_PREFIX_DEVICE_LIST, CACHE_TTL_DEVICE_MS）
    └─→ common/utils.ets（nowMs）

services/SensorService.ets
    ├─→ services/HttpClient.ets（get）
    ├─→ common/CacheManager.ets（set, get）
    ├─→ common/models.ets（SensorSnapshot, SensorHistory, DailyAggregation, PaginatedData）
    └─→ common/constants.ets（CACHE_KEY_PREFIX_SENSOR_LATEST, CACHE_KEY_PREFIX_SENSOR_ALL_LATEST, CACHE_TTL_SENSOR_MS）

services/DiseaseService.ets
    ├─→ services/HttpClient.ets（get）
    ├─→ common/CacheManager.ets（set, get）
    ├─→ common/models.ets（DiseaseRecord, DiseaseStats, HeatmapData, PaginatedData）
    └─→ common/constants.ets（CACHE_KEY_PREFIX_DISEASE_STATS, CACHE_KEY_PREFIX_DISEASE_HEATMAP, CACHE_TTL_DISEASE_MS）

services/CommandService.ets
    ├─→ services/HttpClient.ets（post）
    ├─→ services/DeviceService.ets（getCachedDevices, refreshDevices）
    ├─→ common/models.ets（CommandResponse, CommandLog, PaginatedData）
    └─→ common/constants.ets（ERR_CODE_DEVICE_OFFLINE）

services/AdvisoryService.ets
    ├─→ services/HttpClient.ets（get）
    ├─→ common/CacheManager.ets（set, get）
    ├─→ common/models.ets（Advisory）
    └─→ common/constants.ets（CACHE_KEY_PREFIX_ADVISORY, CACHE_TTL_ADVISORY_MS）

services/ImageService.ets
    ├─→ services/HttpClient.ets（getRaw, BASE_URL, HEADER_KEY）
    ├─→ common/api.ets（uploadFile）
    ├─→ common/models.ets（ImageUploadResult）
    ├─→ common/constants.ets（HEADER_API_KEY）
    └─→ @kit.AbilityKit（common.UIAbilityContext）

services/PollingManager.ets（改造）
    └─→ common/models.ets（PollingCallback）
```

### 暴露给后续任务的公开接口

| 来源 | 导出 | 后续消费者 |
|------|------|-----------|
| `DeviceService` | `getDeviceList`、`getCachedDevices`、`refreshDevices` | ControlPage、CommandService |
| `SensorService` | `getLatest`、`getAllLatest`、`getHistory`、`getDaily` | DashboardPage、Index、SensorCard |
| `DiseaseService` | `getList`、`getStats`、`getHeatmap` | DiseaseRecordsPage、SeverityBadge |
| `CommandService` | `send`、`getLogs` | ControlPage、CommandLog |
| `AdvisoryService` | `getAdvisory` | AdvisoryPage、AlarmBanner |
| `ImageService` | `uploadImage`、`getImagePixelMap` | ImageViewer、DiseaseRecordsPage |
| `PollingManager` | `start`、`stop`、`stopAll`、`suspendAll`、`resumeAll` | 全部 Page（轮询注册）、EntryAbility（前后台） |

---

## 实施风险与边界声明

| 风险点 | 边界 / 缓解 |
|--------|------------|
| `SensorService.getLatest` 强制 `deviceId` 与后端"不传 `device_id` 时返回数组"的契约冲突 | 缓存键固定含 `deviceId`；空 `deviceId` 时后端返回数组，实现期断言 `Array.isArray === false` 否则抛 `Error('Expected single sensor snapshot')` |
| `CommandService` 与 `DeviceService` 之间的依赖关系 | 单向依赖（`CommandService` → `DeviceService`），`DeviceService` 不引用 `CommandService`，无循环 |
| `PollingManager.scheduleNext` 递归 `setTimeout` 在 ArkTS 中的 stack 安全性 | `setTimeout` 回调是非阻塞宏任务，递归通过 `Promise.then`/`catch` 链异步展开，不存在调用栈累积 |
| `ImageService.uploadImage` 中 `api.uploadFile` 的占位实现（`code: 0, data: null`） | 本轮 R1 占位行为保留（`plan_task.md` §"不在本轮范围内"明确声明）；实现期 ImageService 透传占位结果，成功路径返回 `null` → 上层调用方需在后续轮次适配 |
| `CacheManager.get` 过期自动失效 | 行为已 R1 固化；本轮 Service 依赖 `null` 返回值判断未命中 |
| `HttpClient.post` 不重试但可能因网络瞬断失败 | 由 `CommandService.send` 透传 `Error`；调用方（ControlPage）可按需在 UI 层加重试按钮或临时 polling |
| `DeviceService.cachedDevices` 初始化为 `[]` vs `null` | 用户指令用 `DeviceInfo[]`（非 `DeviceInfo[] \| null`）；初始化为 `[]` 表示"无设备"语义；`lastFetchTime === 0` 标记"未初始化" |
| `HttpClient.get/post` 业务失败（`code !== 0`）时 `HttpClient` 不抛错 | 由 Service 层统一判 `resp.code === 0` 并抛 `Error(resp.message)`，形成"传输层透传 + 业务层包装"的分层 |
| `AdvisoryService` 缓存键不含 `start`/`end` | 与用户指令"缓存 key 含 deviceId 参数"对齐；`start`/`end` 通常与 `windowMinutes` 配合使用，但 `windowMinutes` 已经能表达时间窗口语义，故缓存键中省略 `start`/`end` 以控制键空间 |
| `PollingManager.tick` 中 `task.fn()` 的 Promise 链与 `timerId = null` 的时序 | 必须在调用 `task.fn()` **之前**置 `task.timerId = null`（避免 `stop` 时 `clearTimeout(null)` 报错）；实现期严格按此顺序 |

---

## R2 偏差说明

| 偏差项 | 原因 | 影响范围 |
|--------|------|---------|
| **Service 方法直接返回业务类型，不包 `ApiResponse` 壳** | 用户最终指令明确要求（如 `getDeviceList(): Promise<DeviceInfo[]>`），与 `plan_task.md` 中"返回 `ApiResponse<...>`"的描述不一致 | 全部 6 个 Service；`HttpClient` 仍返回 `ApiResponse`，由 Service 解包 |
| **`DeviceService.getCachedDevices` 返回 `DeviceInfo[]` 而非 `DeviceInfo[] \| null`** | 用户指令明确"返回缓存值，不强制刷新"；`DeviceInfo[]` 而非 `null` 避免调用方频繁处理 null | `DeviceService`、`CommandService.send` 前置校验 |
| **`DeviceService.cachedDevices` 初始化为 `[]` 而非 `null`** | 同上，配合 `lastFetchTime === 0` 区分"未初始化"与"无设备" | `DeviceService` 内部 |
| **`SensorService.getLatest(deviceId: string)` 强制 `deviceId` 参数** | 用户指令明确；`plan_task.md` 描述为可选 | `SensorService`；与后端"传 `device_id` 时返回单条"契约对齐 |
| **`PollingManager.start` 形参名 `intervalMs` 而非 `interval`** | ArkTS 编码规范（变量名携带单位后缀以提高可读性）；`plan_task.md` 中 `interval` 是简化写法 | `PollingManager` 公开签名 |
| **PollingTask 含 `suspended` 字段而非仅 `running`** | 用户指令"模块级 `tasks: Map<string, PollingTask>`，`PollingTask` 含 `running: boolean`、`suspended: boolean`、`timerId: number \| null`、`fn: PollingCallback`、`interval: number`"；区分"是否启用"与"是否暂停"两态 | `PollingManager` 内部；`suspended` 用于 `suspendAll`/`resumeAll` 区分暂停与停止 |

---

## 编译验证基线

完成后预期命令：
```bash
hvigorw assembleHap --mode module -p product=default
```

应满足：
- exit code = 0
- 无 `error:` 行
- 允许 `warning:` 行

---

## 配置与依赖清单

### 第三方 SDK 依赖（@kit.* 内建，无需 oh-package.json5 声明）

| 模块 | 用途 | 消费方 |
|------|------|--------|
| `@kit.AbilityKit` | `common.UIAbilityContext` | `ImageService.uploadImage` |

### 不变更的文件
- `harmony-app/entry/oh-package.json5`
- `harmony-app/oh-package.json5`
- `harmony-app/entry/src/main/module.json5`
- `harmony-app/entry/src/main/resources/base/profile/main_pages.json`
- `harmony-app/entry/src/main/ets/pages/Index.ets`
- `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets`
- `harmony-app/entry/src/main/ets/entrybackupability/EntryBackupAbility.ets`
- `harmony-app/entry/src/main/ets/common/*.ets`（6 个文件全部 R1 固化）
- `harmony-app/entry/src/main/ets/services/HttpClient.ets`（R1 固化）
