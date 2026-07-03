# 任务指令（R1）

## 动作

NEW

## 任务描述

实现 FarmEye Guard 鸿蒙应用的最小可编译骨架。完成后 `harmony-app` 必须能够通过 ArkTS 编译，无 error。

**预期文件路径**（均为新增；路径相对 `harmony-app/entry/src/main/ets/`）：

### common 层
1. `common/models.ets` — 接口清单（DeviceInfo、SensorSnapshot、SensorHistory、DailyAggregation、DiseaseRecord、DiseaseStats、HeatmapData、CommandRequest、CommandLog、Advisory、ImageUploadResult、TextResult、BinaryResult、ApiResponse<T>、PaginatedData<T>、Pagination、CacheEntry<T>、RetryPolicyConfig、PollingCallback、ConnectivityStatus）
2. `common/constants.ets` — 常量（API_BASE_URL、API_KEY、DEFAULT_TIMEOUT_MS、DEFAULT_RETRY、轮询间隔、缓存 TTL、命令字符串、错误码枚举、报警位掩码、缓存键前缀）
3. `common/RetryPolicy.ets` — 仅导出 `DEFAULT_RETRY` 常量（`RetryPolicyConfig` 类型在 models.ets 中定义）
4. `common/CacheManager.ets` — 模块级单例，`set<T>/get<T>/invalidate/clear`，TTL 自动失效
5. `common/utils.ets` — `formatTimestamp`、`parseAlarmFlag`、`sleep`、`buildQueryString`、`isNetworkError`、`nowMs`
6. `common/api.ets` — 原始传输层函数 `request(url, options)`、`requestRaw(url, options)`、`uploadFile(context, url, filePath, header, data)`，封装 `@ohos.net.http` 生命周期 + `@ohos.request` 上传

### services 层
7. `services/HttpClient.ets` — 模块级单例；`get<T>(path, params)`、`post<T>(path, body)`、`getRaw(path, params)`；含 JSON 解析 + 业务错误码映射 + 指数退避重试（GET 自动 3 次，POST 不重试）
8. `services/PollingManager.ets` — **占位**：导出空方法 `start/stop/stopAll/suspendAll/resumeAll`，内部仅持有 `Map<key, { running: boolean }>`，不实现实际调度

### entryability 层
9. `entryability/EntryAbility.ets` — 改造：`onForeground` 调用 `PollingManager.resumeAll()`；`onBackground` 调用 `PollingManager.suspendAll()`

### 配置（保持现状）
10. `resources/base/profile/main_pages.json` — 不变（仅含 `pages/Index`）
11. `module.json5` — 不变
12. `Index.ets` — 不变（保留 Hello World 模板）

## 选择理由

- **自底向上 + 基础设施优先**：先固化 common 层（类型 + 常量 + 工具 + 原始 HTTP 封装 + 缓存 + 重试），所有后续 Service / Page 都依赖这些稳定基底；后续轮次无需再回头修改 common 签名。
- **HttpClient 第二优先**：是 common 层之上的业务门面，所有 Service 都依赖 HttpClient，必须紧随 common 层落地。
- **PollingManager 仅占位**：EntryAbility 在 `onForeground/onBackground` 调用其方法占位可保证整链路编译通过；实际调度逻辑（递归 setTimeout、串行模式）实现量大且与多个 Page 的回调签名紧耦合，留到后续轮次与 Page 一同实现更易一次落地。
- **不改 Index.ets**：首轮 Page 仍是 Hello World；改造 Index 为真实首页涉及与 SensorService / DeviceService 联动，应单独成轮。
- **不加路由条目**：其他 Page（DashboardPage 等）尚未实现，提前加入 main_pages 会导致模块找不到组件而编译失败。

## 任务上下文

### 来自 `docs/4_hamony-architecture.md` 的关键约束

- 依赖方向：`pages/ → services/ → common/`；`components/ → common/models.ets`
- `api.ets` 是纯传输层，**不注入 X-Api-Key、不解析 JSON、不拼接 /api/v1**
- `HttpClient` 才是业务门面：注入 `X-Api-Key`、拼接 baseURL、JSON 解析、错误码映射、指数退避
- 错误码：0=success、1001=参数无效、1002=资源不存在、1003=设备离线、1004=API Key 无效、1005=频率限制、2001=DB 错、3001=IoTDA 错、5000=内部错
- 报警位掩码：0x01 高温 / 0x02 低温 / 0x04 高湿 / 0x08 低湿 / 0x10 低光照 / 0x20 高 CO2 / 0x40 低氮 / 0x80 低磷
- 重试策略：baseDelayMs=1000, maxDelayMs=10000, maxRetries=3；GET 重试，POST 不重试；retryOn 状态码 [408,429,502,503,504]
- `PollingCallback` 类型签名：`type PollingCallback = () => Promise<void>`，定义在 `common/models.ets`
- `EntryAbility.onBackground/onForeground` 统一暂停 / 恢复所有轮询

### 来自 `docs/3_client-api-reference.md` 的关键约束

- 基础 URL 路径前缀：`/api/v1`
- 测试 API Key：`farmeye_dev_key_001`，请求头字段名：`X-Api-Key`
- `/sensor/latest` 在携带 `device_id` 时返回单条快照 `data: {...}`；不携带时返回数组 `data: [...]`（HttpClient 透传，由调用方按路径选择）
- 分页：参数 `?page=N&page_size=M`，范围 1-100；响应 `data: { pagination: { total, page, page_size }, records: [...] }`
- 所有响应外层结构：`{ code: number, message: string, data: T | null }`
- `/image/upload` 是 `multipart/form-data`（必须走 `@ohos.request.uploadFile`，不能走 JSON HttpClient POST）

### 来自 `requirement.md` 的硬性要求

- 严格按照 `docs/4_hamony-architecture.md` 实施
- 每轮实现完成后必须可以编译通过，没有 error
- API 严格遵循 `docs/3_client-api-reference.md`

## 已有代码上下文

### 当前模板状态
- `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets` — 模板原样，含 `onCreate/onDestroy/onWindowStageCreate/onWindowStageDestroy/onForeground/onBackground`，全部仅有 hilog 打印
- `harmony-app/entry/src/main/ets/pages/Index.ets` — Hello World 模板（保持不变）
- `harmony-app/entry/src/main/resources/base/profile/main_pages.json` — 仅声明 `pages/Index`
- `harmony-app/entry/oh-package.json5` — 依赖为空
- `harmony-app/oh-package.json5` — 仅 devDependencies `@ohos/hypium`、`@ohos/hamock`
- 现有目录结构：`ets/{entryability,entrybackupability,pages}`，**没有 common/services/components 子目录**（需新建）
- 现有 SDK 能力可用：`@kit.AbilityKit`、`@kit.PerformanceAnalysisKit`、`@kit.ArkUI`；`@ohos.net.http`、`@ohos.request` 为 SDK 内建模块（无需 oh-package 声明）

### 编译验证基线

首轮完成后预期命令：`hvigorw assembleHap --mode module -p product=default`（或 IDE 内 Build Hap）应返回 exit code 0，无 `error:` 行；允许 `warning:`（如未使用的导入，需在实现中避免）。

## RETRY 说明（仅 RETRY 时）

无（首轮 NEW）。