# 设计审查报告（R2 r1）

## 审查结果

APPROVED

## 发现

### [轻微] 1. `ImageService.uploadImage` 内部 `data` 字典构造可读性欠佳（实施细节级）

设计 §ImageService.ets 中构造 `data: Record<string, string> = {}` 后通过 `diseaseRecordId !== undefined` → `data.disease_record_id = String(diseaseRecordId)` 的可变赋值实现 form data 组装。可工作但语义不如直接构造字面量清晰：`const data: Record<string, string> = diseaseRecordId !== undefined ? { disease_record_id: String(diseaseRecordId) } : {}`。**影响范围**：仅 ImageService.ets 一处 ~5 行代码；不阻塞。实施期 Coder 可自由选择两种写法。

### [轻微] 2. `PollingManager.tick` 中 `.then().catch().finally()` 与 ArkTS 严格语法的兼容性未在设计规格中给出伪代码示例

设计 §PollingManager.ets §"私有方法 `tick`" 用文字描述了 `task.fn().then(...).catch(...).finally(...)` 模式，但未给出 ArkTS 实际可编译的 Promise 链伪代码。ArkTS 对 `Promise.finally()` 的支持在某些 SDK 版本中可能存在类型推断差异（如 `finally` 回调无入参，返回的 Promise 类型推断规则与 TS 略有不同）。**影响范围**：实施期 Coder 实际编译验证时会暴露，不构成设计阻塞。建议 Coder 实现时优先测试此 Promise 链是否通过 ArkTS 严格模式；如不通过，回退到 `.then(onFulfilled, onRejected)` 双回调模式或 `.then(...).catch(...).then(...)` 显式链式。

### [轻微] 3. `DiseaseService.getStats` 缓存键 fallback 与 plan_review_r1 第 5 项的修复方向一致但未在 design_spec 偏差表中显式登记

plan_review_r1 §[轻微] 5 指出了 `start + '_' + end` 在 `undefined` 时会拼接为 `"undefined_undefined"` 的潜在 bug。design_spec §DiseaseService.ets 正确采用了 `(start ?? 'all') + '_' + (end ?? 'all')` 兜底（line 237 与 line 299），避免了该问题。但 design_spec §"R2 偏差说明" 未将此修复显式列为对 plan_review_r1 的响应条目。**影响范围**：仅文档登记完整性问题；设计本身正确。不阻塞。

### [轻微] 4. `CommandService.send` 前置校验边界与 plan_review_r1 第 4 项的修复方向一致但未在 design_spec 偏差表中显式登记

plan_review_r1 §[轻微] 4 指出了"缓存未命中 → 放行 / 缓存中存在设备但 online=false → 拒绝 / 缓存中存在但 device_id 不在 → 放行"三种边界场景。design_spec §CommandService.ets 正确实现了这三种边界（line 258-260）。但 design_spec §"R2 偏差说明" 未将 plan_review_r1 的该建议显式登记为已应用修复条目。**影响范围**：仅文档登记完整性问题；设计本身正确。不阻塞。

## 通过理由

1. **接口签名符合 OOD 文档**：
   - 所有 API 路径（`/device/list`, `/sensor/latest`, `/sensor/history`, `/sensor/daily`, `/disease/list`, `/disease/stats`, `/disease/heatmap`, `/image/upload`, `/image/{id}`, `/command/send`, `/command/logs`, `/advisory`）与 `docs/3_client_api_reference.md` §2.1–2.6 精确匹配；
   - 请求参数（device_id/start/end/page/page_size/window_minutes/crop_type/disease_type/severity 等）与 API 文档完全对齐；
   - 响应类型（`ApiResponse<T>` 外层结构、`PaginatedData<T>` 分页结构）已固化于 `common/models.ets`，Service 直接消费未引入新类型；
   - `CommandRequest` 字段（device_id/command/source?/operator?）与 API §2.5.1 请求体一致；`CommandResponse` 字段（command_id/device_id/command/status）与 §2.5.1 响应 data 一致。

2. **实现聚焦（仅 services 层）**：
   - 文件清单严格限制为 6 个新 Service 文件 + PollingManager 改造（7 个文件）；
   - `§非范围` 段显式排除 UI 组件（SensorCard/ChartView/ControlButton 等 → R3+）、页面（DashboardPage/DiseaseRecordsPage/ControlPage/AdvisoryPage → R3+）、单元测试、common 层、HttpClient、EntryAbility 改造；
   - `§不变更的文件` 清单显式列出全部 R1 已固化文件（common/*、HttpClient.ets、EntryAbility.ets、module.json5、main_pages.json 等）；
   - 不引入 AppStorage（UI 状态存储层），符合"Service 层不感知 UI 状态"的设计原则。

3. **PollingManager 串行调度实现完整**：
   - **串行调度**：设计 §PollingManager.ets §"私有方法 `tick`" 明确 `task.fn()` 通过 `.then(...).catch(...).finally(...)` 链异步展开，递归 `scheduleNext(key)` 仅在 fn resolve/reject 后触发，确保不并发 ✓；
   - **失败不中断**：catch 仅 `console.error`，不重新抛出，递归链继续 ✓；
   - **suspendAll**：遍历所有 task，`clearTimeout` + 置 `suspended = true` + 保留 task 引用（不 delete）✓；
   - **resumeAll**：仅重启 `suspended === true` 的 task ✓；
   - **时序约束**：design §实施风险 第 10 行显式声明"`timerId = null` 必须在调用 `task.fn()` **之前**置（避免 `stop` 时 `clearTimeout(null)` 报错）"，与伪代码 line 421-422 顺序一致 ✓；
   - **栈安全性**：design §实施风险 第 3 行显式说明"`setTimeout` 回调是非阻塞宏任务，递归通过 `Promise.then`/`catch` 链异步展开，不存在调用栈累积" ✓；
   - **5 个公开方法签名不变**：start/stop/stopAll/suspendAll/resumeAll 与 R1 占位完全一致，不破坏 EntryAbility 调用点 ✓。

4. **CommandService 失败路径 → `DeviceService.refreshDevices()` 设计合理**：
   - `code === 1003`（`ERR_CODE_DEVICE_OFFLINE`）时调用 `refreshDevices(deviceId)`，再 `throw new Error(resp.message)`，符合"lazy invalidation on detected inconsistency"模式；
   - 单向依赖（`CommandService` → `DeviceService`，`DeviceService` 不依赖 `CommandService`），无循环依赖；
   - `getCachedDevices` 是同步方法，调用链路不阻塞；
   - HTTP 层抛错（网络异常）时不主动刷新缓存，避免无意义刷新（设备可能只是网络问题）；
   - 前置校验的三种边界（缓存未命中 → 放行 / online=false → 拒绝 / 设备不在缓存 → 放行）均正确处理；
   - 与 plan_review_r1 §[轻微] 4 的修复方向一致（虽未显式登记）。

5. **缓存 key 与 TTL 配置与 constants.ets 完全一致**：
   - `CACHE_KEY_PREFIX_DEVICE_LIST = 'device_list_'` → `device_list_<deviceId|all>` ✓
   - `CACHE_KEY_PREFIX_SENSOR_LATEST = 'sensor_latest_'` → `sensor_latest_<deviceId>` ✓
   - `CACHE_KEY_PREFIX_SENSOR_ALL_LATEST = 'sensor_all_latest'` → 固定键 ✓
   - `CACHE_KEY_PREFIX_DISEASE_STATS = 'disease_stats'` → `disease_stats_<start|all>_<end|all>`（含 undefined 兜底）✓
   - `CACHE_KEY_PREFIX_DISEASE_HEATMAP = 'disease_heatmap'` → 固定键 ✓
   - `CACHE_KEY_PREFIX_ADVISORY = 'advisory_'` → `advisory_<deviceId|all>_<windowMin|all>` ✓
   - TTL 全部使用 `CACHE_TTL_SENSOR_MS = 30000`、`CACHE_TTL_DEVICE_MS = 60000`、`CACHE_TTL_DISEASE_MS = 60000`、`CACHE_TTL_ADVISORY_MS = 30000`，与 constants.ets 字段精确匹配 ✓；
   - `ERR_CODE_DEVICE_OFFLINE = 1003` 引用正确 ✓。

6. **类型完整性**：
   - 所有 import 引用类型均存在于 `common/models.ets`（R1 已固化）：`DeviceInfo`、`SensorSnapshot`、`SensorHistory`、`DailyAggregation`、`DiseaseRecord`、`DiseaseStats`、`HeatmapData`、`CommandRequest`、`CommandResponse`、`CommandLog`、`Advisory`、`ImageUploadResult`、`PaginatedData`、`PollingCallback`；
   - 错误处理统一约定（成功返回业务类型 / 失败抛 `Error(message)`）与 §错误处理 章节伪代码一致；
   - 6 个 Service 的依赖图清晰（§依赖关系 章节列出全部依赖项）；
   - `PollingTask` 接口作为 PollingManager 模块内私有类型，不导出（避免公共 API 膨胀）；
   - `ImageService.uploadImage` 中 `HEADER_API_KEY`（常量名）正确引用自 `common/constants`；
   - `CommandService` 对 `CommandRequest` / `CommandResponse` 的使用正确；
   - `SensorService.getLatest(deviceId: string)` 强制 deviceId 与 API 文档 §2.2.1 "传 device_id 时返回单条"语义对齐，空字符串兜底 + 实现期断言 `Array.isArray(resp.data) === false` 防止后端返回数组时类型不匹配。

## 通过依据汇总

- 6 个 [严重]/[一般] 项：无
- 4 个 [轻微] 项：均为实施期细节或文档登记完整性问题，不影响正确性与可编译性
- 设计覆盖了 plan_task.md 中定义的全部交付物（6 Service + 1 PollingManager 升级）
- 设计正确处理了 R1 已固化的全部契约（HttpClient / CacheManager / constants / models / EntryAbility 调用点）
- 缓存策略、错误处理策略、并发设计、模块依赖图均与 R1 OOD 设计原则一致
- 偏差说明（R2 偏差说明表）对所有非主流实现选择（Service 方法返回业务类型而非 ApiResponse 壳、cachedDevices 初始化为 []、强制 deviceId、intervalMs 命名等）均给出明确理由

## 修改要求

无（4 个轻微问题均为实施细节或文档登记完整性，不构成设计层缺陷）。