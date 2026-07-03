# 任务指令（R2）

## 动作

NEW

## 任务描述

实现 `services/` 层全部 6 个业务 Service + 将 PollingManager 占位升级为真实递归 setTimeout 串行调度。完成后 `harmony-app` 必须能够通过 ArkTS 编译，无 error。

**预期文件路径**（均为新增，路径相对 `harmony-app/entry/src/main/ets/`）：

### services 层（本轮新增 6 个 Service）

1. **`services/DeviceService.ets`**（≤ 300 行） — 设备管理 Service：
   - `getDeviceList(deviceId?: string): Promise<ApiResponse<DeviceInfo[]>>` — 调用 `GET /device/list`，可选 `device_id` 过滤；写入 `CACHE_KEY_PREFIX_DEVICE_LIST + (deviceId ?? 'all')` 缓存（TTL = `CACHE_TTL_DEVICE_MS`）
   - `getCachedDevices(deviceId?: string): DeviceInfo[] | null` — 仅读缓存；命中且未过期返回 `DeviceInfo[]`，否则 `null`
   - `refreshDevices(deviceId?: string): Promise<ApiResponse<DeviceInfo[]>>` — 强制刷新（跳过缓存读取，直接调用 `getDeviceList` 后回写缓存）
   - 内部缓存键生成：`CACHE_KEY_PREFIX_DEVICE_LIST + (deviceId ?? 'all')`

2. **`services/SensorService.ets`**（≤ 300 行） — 传感器数据 Service：
   - `getLatest(deviceId?: string): Promise<ApiResponse<SensorSnapshot | SensorSnapshot[] | null>>` — `GET /sensor/latest`；缓存键 `CACHE_KEY_PREFIX_SENSOR_LATEST + deviceId`（无 deviceId 时键 = `CACHE_KEY_PREFIX_SENSOR_ALL_LATEST`）
   - `getAllLatest(): Promise<ApiResponse<SensorSnapshot[]>>` — 等价于 `getLatest()`（不带 deviceId），缓存键同上
   - `getHistory(deviceId: string, params?: { start?: string, end?: string, page?: number, page_size?: number }): Promise<ApiResponse<PaginatedData<SensorHistory>>>` — `GET /sensor/history`；**不缓存**（分页+时间范围组合空间大）
   - `getDaily(deviceId: string, params: { start: string, end: string, page?: number, page_size?: number }): Promise<ApiResponse<PaginatedData<DailyAggregation>>>` — `GET /sensor/daily`；**不缓存**
   - `getCachedLatest(deviceId?: string): SensorSnapshot | SensorSnapshot[] | null` — 仅读缓存

3. **`services/DiseaseService.ets`**（≤ 300 行） — 病虫害 Service：
   - `getList(params?: { device_id?: string, crop_type?: string, disease_type?: string, severity?: string, start?: string, end?: string, page?: number, page_size?: number }): Promise<ApiResponse<PaginatedData<DiseaseRecord>>>` — `GET /disease/list`；**不缓存**（分页+多维筛选）
   - `getStats(params?: { start?: string, end?: string }): Promise<ApiResponse<DiseaseStats>>` — `GET /disease/stats`；缓存键 `CACHE_KEY_PREFIX_DISEASE_STATS + (start + '_' + end)`
   - `getHeatmap(): Promise<ApiResponse<HeatmapData>>` — `GET /disease/heatmap`；缓存键 `CACHE_KEY_PREFIX_DISEASE_HEATMAP`（全局数据，TTL = `CACHE_TTL_DISEASE_MS`）
   - `getCachedStats(...)` / `getCachedHeatmap()` — 仅读缓存

4. **`services/CommandService.ets`**（≤ 300 行） — 设备控制 Service：
   - `send(req: CommandRequest): Promise<ApiResponse<CommandResponse>>` — `POST /command/send`；**不缓存**；发送前可选设备在线检查（内部查 `DeviceService.getCachedDevices()`，若缓存中设备 `online === false` 则直接 reject `new Error('Device offline')`，避免无意义请求）
   - `getLogs(params?: { device_id?: string, source?: string, start?: string, end?: string, page?: number, page_size?: number }): Promise<ApiResponse<PaginatedData<CommandLog>>>` — `GET /command/logs`；**不缓存**
   - 失败路径刷新：若 `send` 命中 `code === ERR_CODE_DEVICE_OFFLINE`（1003）→ 调用 `DeviceService.refreshDevices(req.device_id)` 刷新设备缓存

5. **`services/AdvisoryService.ets`**（≤ 300 行） — 防治建议 Service：
   - `getAdvisory(params?: { device_id?: string, start?: string, end?: string, window_minutes?: number }): Promise<ApiResponse<Advisory>>` — `GET /advisory`；缓存键 `CACHE_KEY_PREFIX_ADVISORY + (deviceId ?? 'all') + '_' + windowMinutes`
   - `getCachedAdvisory(deviceId?: string, windowMinutes?: number): Advisory | null` — 仅读缓存
   - 单一公开方法 + 缓存读取辅助；无分页/无筛选组合

6. **`services/ImageService.ets`**（≤ 300 行） — 图像上传/下载 Service：
   - `uploadImage(context: common.UIAbilityContext, filePath: string, options?: { disease_record_id?: number, device_id?: string }): Promise<ApiResponse<ImageUploadResult>>` — 调用 `api.uploadFile()`；构造 header `{ X-Api-Key: API_KEY }`，data 包含 `disease_record_id`（若提供）+ `device_id`（若提供）
   - `getRaw(imageId: string): Promise<ArrayBuffer>` — 直接包装 `HttpClient.getRaw('/image/' + imageId)`；**不缓存**（ArrayBuffer 体积大）
   - 注：`HttpClient.getRaw` 内部已注入 X-Api-Key + 重试，故 ImageService 不需额外处理

### services 层（本轮改造 1 个文件）

7. **`services/PollingManager.ets`** — 从占位升级为真实实现（≤ 300 行）：
   - 内部状态：`tasks: Map<string, PollingTask>`，其中 `PollingTask { running: boolean; suspended: boolean; fn: PollingCallback; intervalMs: number; timerId?: number }`
   - `start(key, fn, intervalMs)` — 若已存在则先 `stop(key)`；创建 `PollingTask`，设置 `timerId = setTimeout(tick, intervalMs)`；**不在 start 中立即执行 fn**（等首个 timer 触发）
   - `stop(key)` — 若存在则 `clearTimeout(tasks.get(key).timerId)`，再 `tasks.delete(key)`
   - `stopAll()` — 遍历所有 task，`clearTimeout` 后 `tasks.clear()`
   - `suspendAll()` — 遍历所有 task，`clearTimeout`，置 `suspended = true`，**保留 task 引用**（用于 resumeAll 恢复）；timerId 置 undefined
   - `resumeAll()` — 遍历所有 task 且 `suspended === true`：清除 suspended 标记，重启 `setTimeout(tick, intervalMs)`
   - `tick()`（私有方法）：执行 `fn()` → 用 `.then(() => ...)` / `.catch((err) => console.error(...))` 包裹；若 task 已被 stop 或 suspend 则退出；执行完后若仍 `running && !suspended` 则递归 `setTimeout(tick, intervalMs)`

### 不在本轮范围内

- 任何 UI 组件（SensorCard / ChartView / ControlButton / AlarmBanner 等）→ R3+
- 任何页面（Index 改造 / DashboardPage / DiseaseRecordsPage / ControlPage / AdvisoryPage）→ R3+
- `api.ets` 的 `uploadFile` 业务响应解析仍保留 R1 占位行为（后续轮次处理）
- 单元测试用例 → 独立测试轮次
- `EntryAbility`、`HttpClient`、`common/*` 层全部保持 R1 不变

## 选择理由

1. **纵向切片优先**：6 个 Service + 1 个 PollingManager 升级构成一个"业务服务层完整骨架"的纵向功能增量。每个 Service 是独立的业务边界（设备/传感器/病虫害/命令/建议/图像），可独立编译、独立使用；PollingManager 是所有 Page 的横切依赖，必须在首个 Page 引入前完成。
2. **PollingManager 同步升级**：R1 占位不创建定时器、不调用 fn，所有 Page 实际接入时会立即失效；本轮补全后 R3 Page 轮询代码才能真正工作。
3. **避免修改 common 层**：所有类型/常量已在 R1 落地，Service 只需消费既有契约；如 Service 实现期发现契约缺口，**记录到设计偏差**而非直接修改 common 层（保持 R1 不变约束）。
4. **CommandService 失败路径刷新设备缓存**：命令下发失败（设备离线）后，调用 `DeviceService.refreshDevices(deviceId)` 强制刷新缓存，确保下一次 UI 状态读取为最新，避免"缓存中 online=true 但实际已离线"的不一致窗口。
5. **AdvisoryService 仅一个公开方法 + 一个缓存读取**：API 文档 §2.6.1 仅一个端点，无需拆分多方法；缓存键包含 windowMinutes 参数，适配不同轮询窗口。
6. **ImageService 不引入新缓存**：上传结果和图像二进制流都不适合内存缓存（前者可能大、后者必大）；`HttpClient.getRaw` 已内置重试，ImageService 只做参数组装 + 调用转发。

## 任务上下文

### 来自 R1 设计的契约约束（design_spec.md §7）

- `HttpClient.get<T>(path, params?)` / `HttpClient.post<T>(path, body?)` / `HttpClient.getRaw(path, params?)` 三个公开方法已存在
- `HttpClient.get` / `HttpClient.getRaw` 自动注入 `X-Api-Key` + 拼接 `BASE_URL = API_BASE_URL + API_PATH_PREFIX` + 指数退避重试（GET 3 次）
- `HttpClient.post` 不重试（非幂等），但自动注入 `X-Api-Key` + 序列化 JSON body
- `ApiResponse<T>` = `{ code: number, message: string, data: T | null }`
- Service 层不重新注入 Header、不拼接 prefix、不做 JSON 序列化

### 来自 R1 的缓存契约（constants.ets）

- `CACHE_KEY_PREFIX_DEVICE_LIST = 'device_list_'`、`CACHE_KEY_PREFIX_SENSOR_LATEST = 'sensor_latest_'`、`CACHE_KEY_PREFIX_SENSOR_ALL_LATEST = 'sensor_all_latest'`、`CACHE_KEY_PREFIX_DISEASE_STATS = 'disease_stats'`、`CACHE_KEY_PREFIX_DISEASE_HEATMAP = 'disease_heatmap'`、`CACHE_KEY_PREFIX_ADVISORY = 'advisory_'`
- TTL：`CACHE_TTL_SENSOR_MS = 30000`、`CACHE_TTL_DEVICE_MS = 60000`、`CACHE_TTL_DISEASE_MS = 60000`、`CACHE_TTL_ADVISORY_MS = 30000`
- `CacheManager.set(key, data, ttl?)` / `get<T>(key)` / `invalidate(key)` / `clear()`

### 来自 R1 的命令下发约束

- 命令字符串常量：`CMD_LED_ON = 'led ON'`、`CMD_SPRAY_ON = 'spray ON'` 等已存在；CommandService.send 接受 `CommandRequest { device_id, command, source?, operator? }`，不在 Service 层硬编码命令选择（由 UI 层决定）
- 设备离线错误码：`ERR_CODE_DEVICE_OFFLINE = 1003`

### 来自 API 文档的关键端点路径

- `/device/list`（GET，可选 `device_id`） → `DeviceInfo[]`
- `/sensor/latest`（GET，可选 `device_id`） → 单条 `SensorSnapshot | null` 或数组（视 deviceId 而定）
- `/sensor/history`（GET，必填 `device_id`） → `PaginatedData<SensorHistory>`
- `/sensor/daily`（GET，必填 `device_id`/`start`/`end`） → `PaginatedData<DailyAggregation>`
- `/disease/list`（GET，多维筛选 + 分页） → `PaginatedData<DiseaseRecord>`
- `/disease/stats`（GET，可选 `start`/`end`） → `DiseaseStats`
- `/disease/heatmap`（GET） → `HeatmapData`
- `/image/upload`（POST multipart/form-data） → `ImageUploadResult`（走 `api.uploadFile`，不走 HttpClient.post）
- `/image/{image_id}`（GET） → ArrayBuffer（走 `HttpClient.getRaw('/image/' + imageId)`）
- `/command/send`（POST） → `CommandResponse`（走 `HttpClient.post`，**命令为非幂等不重试**）
- `/command/logs`（GET，多维筛选 + 分页） → `PaginatedData<CommandLog>`
- `/advisory`（GET，可选 device_id/window_minutes） → `Advisory`

### PollingManager 真实调度契约

- 递归 `setTimeout` 串行模式（不并发）：上一个 fn resolve/reject 后才安排下一个 setTimeout
- 失败不中断轮询：fn reject 时记录日志（`console.error`）后继续下一次
- 生命周期：start/stop/stopAll/suspendAll/resumeAll 五个公开方法签名与 R1 占位完全一致（不破坏 EntryAbility 调用点）

## 已有代码上下文

### R1 已交付（保持不变）

- `harmony-app/entry/src/main/ets/common/` — 6 个文件全部完成（models / constants / RetryPolicy / CacheManager / utils / api）
- `harmony-app/entry/src/main/ets/services/HttpClient.ets` — 已实现 get/post/getRaw + 指数退避
- `harmony-app/entry/src/main/ets/services/PollingManager.ets` — 占位（5 个方法签名已导出但内部空实现）
- `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets` — 已注入 PollingManager.resumeAll/suspendAll

### 当前文件状态（重要）

- `impl/temp-R2` 分支上 `harmony-app/entry/src/main/ets/` 下仅含 `pages/Index.ets`、`entryability/EntryAbility.ets`、`entrybackupability/EntryBackupAbility.ets`
- R1 的所有 common/services 源文件在 `impl/202607032019-common-baseline` 分支上（已删除于 `impl/temp-R2`）
- R1 verifier 在 `/tmp/arkts-check` 沙箱中验证了源文件可独立编译通过
- **本轮 Coder 需在 `impl/temp-R2` 工作树上重新创建 R1 全部 common/services 文件**（与本轮新增的 7 个 Service/PollingManager 文件一起），或直接从 `impl/202607032019-common-baseline` 分支 cherry-pick R1 文件后追加 R2 增量（推荐后者，避免重新输入 R1 内容）

### 编译验证基线

完成后预期命令：`hvigorw assembleHap --mode module -p product=default`（或 tsc 严格模式静态检查）。应返回 exit code 0，无 `error:` 行。

### 可参考的 R1 产出（详见 implements/202607032019/）

- `design_spec.md` — 完整 R1 设计规格，含 constants/models/api/HttpClient 完整字段定义
- `code_report.md` — R1 实现报告，含全部 5 项设计偏差说明
- `test_report.md` / `run_report.md` — R1 验证通过记录
- 所有 `models` 接口字段（含 `CommandResponse`）与 `constants` 常量值（含全部缓存前缀/TTL/错误码）均已固化，可直接 import 使用

## RETRY 说明（仅 RETRY 时）

无（首轮 NEW）。