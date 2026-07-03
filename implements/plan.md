# 实现计划

任务描述：按照 `docs/4_hamony-architecture.md` 在 `harmony-app/` 实现 FarmEye Guard v1.0 鸿蒙应用。首轮聚焦最小可编译骨架（common 层 + HttpClient + PollingManager 占位 + EntryAbility 接入）。
项目根目录：`E:\dev\wheat-tea-iot`
实施目录：`E:\dev\wheat-tea-iot\harmony-app`

---

## R1 NEW 最小可编译骨架（common 层 + HttpClient + PollingManager 占位 + EntryAbility 接入）
目录：`E:\dev\wheat-tea-iot\implements\202607032019`
任务：在 `harmony-app/entry/src/main/ets/` 下新增 common、services 目录及对应文件；改造 EntryAbility 接入 PollingManager；新增 PollingManager 占位。
选择理由：自底向上，先把基础设施（common 层 + 原始/业务 HTTP 门面）落地，使后续 R2…R7 的 Service / Component / Page 都有可依赖的稳定基底。PollingManager 仅占位（导出类型与空方法体），保证 EntryAbility 调用通过编译但不实现实际调度（留待后续轮次）。
上下文：当前模板仅含 entryability/EntryAbility.ets、pages/Index.ets、module.json5、main_pages.json（仅声明 Index），依赖只有 hypium/hamock；`@ohos.net.http`、`@ohos.request` 来自 SDK（无需 oh-package 依赖）。

### 计划产出文件清单（R1）

#### common 层（`harmony-app/entry/src/main/ets/common/`）

1. **`models.ets`** — 接口清单：
   - `DeviceInfo`, `SensorSnapshot`, `SensorHistory`, `DailyAggregation`
   - `DiseaseRecord`, `DiseaseStats`, `HeatmapData`, `HeatmapPoint`, `HeatmapSummary`
   - `CommandRequest`, `CommandLog`
   - `Advisory`, `AdvisoryDetection`, `AdvisoryEnv`, `AdvisoryLinkage`, `AdvisoryAction`
   - `ImageUploadResult`
   - `TextResult`, `BinaryResult`
   - `ApiResponse<T>`, `PaginatedData<T>`, `Pagination`
   - `CacheEntry<T>`
   - `RetryPolicyConfig`（独立命名，避免与同名文件冲突）
   - `PollingCallback`（`type PollingCallback = () => Promise<void>`）
   - `ConnectivityStatus`（`'loading' | 'online' | 'offline'`）

2. **`constants.ets`** — 常量：
   - `API_BASE_URL: string`（默认值，如 `'http://127.0.0.1:8000/api/v1'`，实际值后续可通过环境变量覆盖）
   - `API_KEY: string`（默认值 `'farmeye_dev_key_001'`）
   - `DEFAULT_TIMEOUT_MS: number = 10000`
   - `DEFAULT_RETRY: RetryPolicyConfig`
   - `POLL_INTERVAL_INDEX_SENSOR_MS = 10000`、`POLL_INTERVAL_INDEX_ALARM_MS = 10000`
   - `SENSOR_CACHE_TTL_MS = 30000`、`DEVICE_CACHE_TTL_MS = 30000`
   - `COMMAND_SEND_PATH = '/command/send'`、`COMMAND_LOGS_PATH = '/command/logs'`
   - 命令字符串常量：`'led ON'`、`'led OFF'`、`'beep ON'`、`'beep OFF'`、`'spray ON'`、`'spray OFF'`、`'irrig ON'`、`'irrig OFF'`
   - 业务错误码枚举：`CODE_SUCCESS=0`、`CODE_PARAM_INVALID=1001`、`CODE_NOT_FOUND=1002`、`CODE_DEVICE_OFFLINE=1003`、`CODE_APIKEY_INVALID=1004`、`CODE_RATE_LIMIT=1005`、`CODE_DB_ERROR=2001`、`CODE_IOTDA_ERROR=3001`、`CODE_INTERNAL=5000`
   - 报警位掩码：`ALARM_HIGH_TEMP=0x01`、`ALARM_LOW_TEMP=0x02`、`ALARM_HIGH_HUMI=0x04`、`ALARM_LOW_HUMI=0x08`、`ALARM_LOW_LIGHT=0x10`、`ALARM_HIGH_CO2=0x20`、`ALARM_LOW_N=0x40`、`ALARM_LOW_P=0x80`
   - 缓存键前缀：`CACHE_KEY_SENSOR_LATEST_PREFIX='sensor_latest_'`、`CACHE_KEY_DEVICE_LIST='device_list'`、`CACHE_KEY_ADVISORY='advisory'` 等

3. **`RetryPolicy.ets`** — 仅导出 `DEFAULT_RETRY` 默认值常量与 `RetryPolicyConfig` 重导出（类型在 models 中定义）；此处仅暴露 `DEFAULT_RETRY` 供 HttpClient 引用。

4. **`CacheManager.ets`** — 模块级单例：
   - 内部 `Map<string, CacheEntry<unknown>>` 存储
   - `set<T>(key, data, ttl?)`、`get<T>(key)`、`invalidate(key)`、`clear()`
   - TTL 过期自动失效
   - 命名约定：调用方使用命名空间前缀

5. **`utils.ets`** — 工具函数：
   - `formatTimestamp(ts: string): string`
   - `parseAlarmFlag(flag: number): string[]`（位掩码 → 中文标签数组）
   - `sleep(ms: number): Promise<void>`
   - `buildQueryString(params: Record<string, string | number | undefined | null>): string`
   - `isNetworkError(err: unknown): boolean`（粗略判定 `@ohos.net.http` 抛错）
   - `nowMs(): number`

6. **`api.ets`** — 原始传输层（占位实现 + 完整签名）：
   - `request(url: string, options: ApiRequestOptions): Promise<TextResult>`
   - `requestRaw(url: string, options: ApiRequestOptions): Promise<BinaryResult>`
   - `uploadFile(context: common.UploadContext, url: string, filePath: string, header: Record<string, string>, data: Record<string, string>): Promise<TextResult>`
   - 内部使用 `@ohos.net.http` 与 `@ohos.request`；提供完整实现（含超时、生命周期管理、catch 网络异常并封装错误消息）
   - 类型 `ApiRequestOptions { method, headers?, body?, expectDataType?, timeoutMs? }` 在同文件定义
   - 业务层不注入 Header / 不解析 JSON

#### services 层（`harmony-app/entry/src/main/ets/services/`）

7. **`HttpClient.ets`** — 业务门面层（模块级单例）：
   - `get<T>(path: string, params?: Record<string, string | number | undefined | null>): Promise<ApiResponse<T>>`
   - `post<T>(path: string, body: object): Promise<ApiResponse<T>>`
   - `getRaw(path: string, params?: ...): Promise<ArrayBuffer>`
   - `apiKey: string`（只读）、`baseURL: string`（只读）getter
   - 内部组合 `api.request()` + JSON 解析 + 业务错误码映射
   - 内置指数退避重试（GET 自动 3 次；POST 不重试）
   - 错误类型：`ApiError extends Error { code: number; isNetwork: boolean }`

8. **`PollingManager.ets`** — 占位实现：
   - 仅导出空方法 `start(key, fn, intervalMs)`、`stop(key)`、`stopAll()`、`suspendAll()`、`resumeAll()`
   - 内部 `tasks: Map<string, { running: boolean }>` 用于存根
   - 不实现递归 setTimeout（留给后续轮次）
   - 目的是让 EntryAbility 的 `onBackground/onForeground` 调用通过编译

#### entryability 层（`harmony-app/entry/src/main/ets/entryability/`）

9. **`EntryAbility.ets`** — 改造：
   - `import { PollingManager } from '../services/PollingManager'`
   - `onForeground()` 调用 `PollingManager.resumeAll()`
   - `onBackground()` 调用 `PollingManager.suspendAll()`
   - 保留原有 hilog 行为与生命周期

#### module.json5 / main_pages.json（保持现状）

10. **`main_pages.json`** — 仅保留 `pages/Index`（首轮不新增路由条目；Index 仍为 Hello World 模板）
11. **`module.json5`** — 保持现状（无需新增权限，因为网络/上传是基础 SDK 能力）

### 已知约束与设计修正

- **`@ohos.net.http` 的 `destroy()` 必须在 `offline` 阶段调用**；`api.ets` 实现中需保证每请求独立 `createHttp()` 实例并在 `try/finally` 中 `destroy()`。
- **`TextResult.rawBody` 为 `string`**（避免 ArkTS 强类型与 JSON 互转时的 `Object` 兼容性问题）；`BinaryResult.rawBody` 为 `ArrayBuffer`。
- **`UploadContext`** 暂定义为 `object`（具体类型由 `ImageService` 在后续轮次细化），保证 api.ets 签名不依赖 UI 上下文类型。
- **`HttpClient` 中处理 `ApiResponse<T>` 的 `data` 字段为 `null` 的情况**（如 `/sensor/latest` 在无数据时返回 `null`）——返回 `null` 时仍视为 `code===0` 成功，由调用方处理。
- **重试睡眠** 使用 `utils.sleep()`，重试判定条件：捕获 `isNetworkError=true` 或 `statusCode ∈ {408,429,502,503,504}` 且 `attempt < maxRetries`。
- **`PollingManager` 占位必须保证 `EntryAbility` 编译通过**：因此所有方法签名必须精确匹配使用点（无参版本即可，类型由 PollingCallback 在 models 中导出）。

### R2 PASSED services 层 6 个业务 Service + PollingManager 真实调度
目录：`implements/202607032102`
结果：实现 `DeviceService`/`SensorService`/`DiseaseService`/`CommandService`/`AdvisoryService`/`ImageService` 6 个业务 Service + `PollingManager` 从占位升级为递归 `setTimeout` 串行调度
测试：38 用例，新增 10 个（PollingManagerTest 13 / DeviceServiceTest 5 / SensorServiceTest 5 / DiseaseServiceTest 8 / CommandServiceTest 3 / AdvisoryServiceTest 4）；tsc strict 0 errors

## R3 NEW components 层 R3a：6 个基础组件实现
目录：`implements/202607040017`
任务：在 `harmony-app/entry/src/main/ets/components/` 下新建 6 个零 Canvas/ImageKit/BuilderParam 风险的 UI 组件（SeverityBadge / AlarmBanner / ConnectivityIndicator / LoadingState / SensorCard / DeviceSelector）。R3b（ChartView/LineChartRenderer/BarChartRenderer/ControlButton/PaginatedList/ImageViewer）留待下一轮。完成后需通过 ArkTS 编译（tsc strict 0 errors，允许 warning）。
选择理由：**响应 Reviewer r1 轮的拆分会话建议**：将原计划 12 个组件一次性实现拆分为 R3a（6 基础）+ R3b（6 进阶）。R3a 仅依赖 common/models + common/utils + AppStorage，零外部 Kit stub 风险；R3b 涉及 Canvas API、@kit.ImageKit stub、@BuilderParam 严格模式陷阱，需先补全 stub 后再实施，避免"stub 缺失 vs 接口错误"混杂在同一轮错误日志中。本轮 Reviewer 还修正了 PaginatedList.loadPage 返回结构、ControlButton.onToggle 签名、ChartView 重绘策略、SeverityBadge 类型对齐等 14 项反馈中可在本轮前置消化的部分（如 tsconfig.json include 扩展、LoadingState.errorMessage 注释明确、DeviceSelector AppStorage 单向写语义明确等）。
上下文：当前 `harmony-app/entry/src/main/ets/components/` 目录尚未创建。common/models 已固化全部 interface；utils 已固化 `parseAlarmFlag`/`formatTimestamp`/`nowMs`；HttpClient 已固化；6 个 Service 已固化；`BASE_URL` 与 `HEADER_KEY` 已从 HttpClient 导出供 R3b 的 ImageViewer 拼接图片 URL 使用；`@ohos.net.http`/`@ohos.request`/`@kit.AbilityKit` 来自 SDK 无需 oh-package 声明。R3a 组件零服务调用，仅 DeviceSelector 注释引用 DeviceService。验证基线：先更新 `/tmp/arkts-check/tsconfig.json` include 加入 `src-ts/main/ets/components/**/*.ts`，再 `tsc --noEmit -p .`。

### R3a 计划产出文件清单

#### components 层（`harmony-app/entry/src/main/ets/components/`，R3a 新建 6 个）

1. **`SeverityBadge.ets`** — 严重度文字徽标
   - Props: `severity: 'mild' | 'moderate' | 'severe' | string`（与 AlarmBanner 对齐，string 兜底）
   - 映射：mild → 绿色 `#4CAF50` + "轻度"；moderate → 橙色 `#FF9800` + "中度"；severe → 红色 `#F44336` + "重度"；其它 → 灰色 + 原字符串

2. **`AlarmBanner.ets`** — 顶部告警横幅
   - Props: `message: string`、`severity: 'mild' | 'moderate' | 'severe'`、`onClose?: () => void`、`onTap?: () => void`
   - 行为: `message === ''` 时 if 跳过渲染；三色背景（mild 浅绿 / moderate 浅橙 / severe 浅红）；关闭按钮触发 onClose；整体 onClick 触发 onTap

3. **`ConnectivityIndicator.ets`** — 顶部连接状态指示器
   - Props: `status: 'loading' | 'online' | 'offline'`
   - 行为: 三色细条（loading 黄 / online 绿 / offline 红，高度 4vp）；同时 export `@Builder function ConnectivityIndicatorBuilder(status)` 供父组件嵌入

4. **`LoadingState.ets`** — 统一加载状态占位
   - Props: `status: 'loading' | 'error' | 'empty'`、`errorMessage: string`、`@Prop onRetry?: () => void`
   - 约束: `status === 'error'` 时 errorMessage 必须提供；loading → Progress + "加载中..."；error → 图标 + errorMessage + 重试按钮；empty → 图标 + "暂无数据"
   - 状态机: 'loading' | 'error' | 'empty'（与 R1 设计一致）

5. **`SensorCard.ets`** — 传感器参数卡片
   - Props: `label: string`、`value: number`、`unit: string`、`timestamp: string`、`alarmBits: number[] = []`
   - 行为: 数值 + 单位 + formatTimestamp(timestamp) 显示；alarmBits.length > 0 时背景色切为浅红 `#FFEBEE`

6. **`DeviceSelector.ets`** — 设备下拉选择器（AppStorage 单向写）
   - Props: `devices: DeviceInfo[]`
   - State: `@State selectedIndex: number = 0`
   - 行为: aboutToAppear → `AppStorage.setOrCreate<string>('selectedDeviceId', '')`；用户切换 → `AppStorage.set('selectedDeviceId', devices[newIndex].device_id)` + selectedIndex = newIndex
   - AppStorage 语义: **仅写不读**；父 Page 层用 `@StorageLink('selectedDeviceId')` 监听

### R3a 已知约束
- tsconfig.json include 必须先更新加入 `src-ts/main/ets/components/**/*.ts`，否则 tsc 不检查 components/
- R3a 零 Kit stub 需求（@kit.ArkUI 的 promptAction/Progress/ProgressType/Select 已在 R1 stub 中声明）
- AppStorage 初始化必须 setOrCreate，否则父 Page @StorageLink 抛"未初始化"错误
- LoadingState.errorMessage 在 status === 'error' 时必须非空（约定约束，不使用 @Require 装饰器）

### R3b 留待下一轮（6 个进阶组件）
- ChartView / LineChartRenderer / BarChartRenderer：Canvas API + 父组件 key 强制重绘策略；LineChartRenderer 折线渲染；BarChartRenderer render 方法直接 return
- ControlButton: `@Link isOn` + 父组件 `@State isOn` + `ControlButton({ isOn: $isOn, ... })` 传递；onToggle: `(targetState: boolean) => Promise<void>`；仅翻转+触发，不等待、不回滚
- PaginatedList: `@BuilderParam renderItem: (item: T, index: number) => void`；loadPage: `(page: number) => Promise<{ records: T[], total: number }>`；hasMore = items.length < total
- ImageViewer: 主路径 `BASE_URL + imagePath` 直连；降级路径 `imageId` 由父 Page 从 image_path 提取后传入（组件不做字符串解析）；`image.createImageSource(buf).createPixelMap()` 必须 await

### R3b 前置条件（实施前必须完成）
- 创建 `/tmp/arkts-check/stubs/kit-image.d.ts`：声明 `image.PixelMap` / `image.ImageSource` / `image.createImageSource(buf): ImageSource` / `createPixelMap(): Promise<PixelMap>`
- tsconfig.json paths 追加 `"@kit.ImageKit": ["stubs/kit-image.d.ts"]`
- 确认 @kit.ArkUI stub 已声明 Canvas 组件 + CanvasRenderingContext2D + onReady 回调类型