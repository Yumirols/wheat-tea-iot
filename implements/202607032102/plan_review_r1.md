# 计划审查报告（R2 r1）

## 审查结果

APPROVED

## 发现

### [轻微] 1. `CommandService.refreshDevices` 调用方式在 SensorService/DiseaseService 缓存一致性窗口中未提及

`CommandService.send` 在 `code === ERR_CODE_DEVICE_OFFLINE` 时调用 `DeviceService.refreshDevices(req.device_id)` 刷新设备缓存是合理的（设备离线后缓存可能仍显示 `online=true`）。但 `SensorService.getLatest` 同样依赖 `DeviceService.getCachedDevices()` 的间接逻辑（如未来需要按设备列表过滤快照），且 DiseaseService 缓存的热力图/统计也可能包含离线设备记录——本轮仅刷新 DeviceService 缓存而不联动其他 Service 的缓存，存在"DeviceService 一致、其他 Service 仍带陈旧数据"的不对称窗口。

**期望修正方向**：本轮任务范围明确（仅 6 个 Service + PollingManager 升级），完整缓存一致性策略属跨 Service 协作需求，留待后续轮次（Page 接入阶段）由 Page 编排刷新顺序，或在 R5（cache coherence 治理轮次）一并处理。建议在 design_spec 中显式标注此为已知约束：Coder 无需在本轮扩展刷新范围，但需在 design_spec/code_report 中以"已知边界/留待后续轮次"形式记录。

### [轻微] 2. `PollingManager.suspendAll` 期间新增 `start(key)` 的行为边界未明确

`PollingManager` 的 `suspendAll` 保留 task 引用并置 `suspended=true`，但 `resumeAll` 仅遍历"仍存在"且 `suspended=true` 的 task。如果在 `suspendAll` 之后调用 `start(newKey, fn, interval)`，新 task 不应被 `suspendAll` 影响（本轮设计正确——`start` 不读取全局 suspended 状态）。但若在 `suspendAll` 期间对已存在的 key 调用 `start(existingKey, newFn, newInterval)`（覆盖语义），覆盖后 task 的 `suspended` 字段继承旧值，会导致新回调也被暂停，且 `resumeAll` 不会重启它（因为新 task 不在 suspendAll 前的"suspended=true 集合"语义范围中——但当前实现会重启它，因为 `resumeAll` 只看 `suspended=true`，不区分是否在 suspendAll 前已存在）。

**期望修正方向**：本轮 PollingManager 是首次实际调度实现，Page 接入轮询代码时尚未涉及"暂停期间动态替换回调"场景。建议 Coder 在实现时显式处理：在 `start(key)` 内部若发现旧 task 存在且 `suspended=true`，新 task 继承 `suspended=true`（保持暂停），待 `resumeAll` 统一恢复；或在 design_spec 中明确"Page 不应在后台暂停期间替换轮询回调"。当前 R2 计划未涉及此边界声明，R3+ 接入轮询代码时需补充。

### [轻微] 3. `ImageService.uploadImage` 仍依赖 `api.uploadFile` 的占位响应解析

`api.ets` 的 `uploadFile` 在 R1 实现报告中明确标注"业务响应解析留待后续轮次"（code_report.md 偏差 3），当前 `task.on('complete', ...)` resolve 一个 `code: 0, data: null` 的占位响应。`ImageService.uploadImage` 在 R2 接受返回 `ApiResponse<ImageUploadResult>`，由于上游占位响应固定 `code: 0`，调用方实际拿到的 `data` 始终为 `null`，无法解析 `image_id` / `image_path` / `file_size` 等关键字段。

**期望修正方向**：plan_task.md 第 64 行已声明"`api.ets` 的 `uploadFile` 业务响应解析仍保留 R1 占位行为（后续轮次处理）"，与 R1 报告一致。这是计划范围内已知的边界声明，**不构成阻塞**。建议 Coder 在 design_spec 中显式标注：`ImageService.uploadImage` 本轮可编译通过并组装正确的 header/data 参数，但调用方拿到的 `data: null` 需在 R3+（UI 接入需要真实上传时）同步修复 `api.ets` 的 `headerReceive` / `complete` 钩子响应解析。

### [轻微] 4. `CommandService` "发送前设备在线检查"的缓存语义欠明确

`CommandService.send` 在发送前可选检查 `DeviceService.getCachedDevices()`：若缓存中设备 `online === false` 则直接 reject `Error('Device offline')`，避免无意义请求。**此处"可选"含义模糊**：
- 若 `getCachedDevices` 返回 `null`（缓存未命中/已过期），应继续发送请求还是拒绝？
- 若缓存存在但无该 `device_id` 记录（即设备从未出现或已被移除），应发送还是拒绝？

**期望修正方向**：建议 Coder 在实现时明确两种边界：(a) 缓存未命中 → 跳过预检直接发送请求（避免误判）；(b) 缓存中存在设备记录但 `online=false` → 拒绝发送；(c) 缓存中存在但 `device_id` 不在列表 → 跳过预检发送请求（设备可能被首次注册或离线缓存过期）。这些边界若未在 design_spec 显式说明，Coder 可能按字面"可选检查"实现为"始终检查"，导致缓存冷启动阶段（首次进入页面时）所有命令都被错误拒绝。

### [轻微] 5. `DiseaseService.getCachedStats` / `getCachedHeatmap` 缓存键构造方式在 plan_task 中描述不精确

`DiseaseService.getStats` 缓存键 `CACHE_KEY_PREFIX_DISEASE_STATS + (start + '_' + end)`，但 `getCachedStats` 的参数签名未明确——plan_task.md 第 30 行只写"缓存键 `CACHE_KEY_PREFIX_DISEASE_STATS + (start + '_' + end)`"，但未说明 `start/end` 是必填还是可选。当 `start/end` 均为 `undefined` 时（首次调用），`undefined + '_' + undefined` 会拼接为字符串 `"undefined_undefined"`，与后续实际传入 `start='2026-07-01'` 时的键不一致，导致缓存永不命中。

**期望修正方向**：建议 Coder 实现时使用空字符串兜底：`const key = CACHE_KEY_PREFIX_DISEASE_STATS + '_' + (start ?? '') + '_' + (end ?? '')`，并保证 `getStats` 与 `getCachedStats` 使用**完全相同**的键生成函数（提取为内部 helper）。同样问题存在于 `AdvisoryService.getAdvisory` 缓存键 `CACHE_KEY_PREFIX_ADVISORY + (deviceId ?? 'all') + '_' + windowMinutes`，需保证 `windowMinutes` undefined 兜底。

## 通过理由

1. **聚焦性**：R2 任务严格围绕"services 层完整骨架"展开——6 个业务 Service + PollingManager 从占位升级为真实递归 setTimeout 串行调度，共 7 个产出文件，构成一个明确的、纵向切片的可独立验证功能增量。无功能蔓延（如未越界修改 UI 组件、Page、common 层契约）。

2. **可编译性保证**：
   - R1 已交付全部 common 层契约（models.ets 含 `CommandResponse`、constants.ets 含全部缓存前缀/TTL/错误码、CacheManager/HttpClient/PollingManager 占位），所有 Service 只需消费既有契约，无需修改 common 层；
   - HttpClient.get<T>/post<T>/getRaw 三个公开方法已固化，Service 层只调用不修改；
   - 全部 Service 方法返回 `Promise<ApiResponse<T>>`，与 R1 契约一致；
   - PollingManager 升级保持 5 个公开方法签名不变（与 R1 占位完全一致），不破坏 EntryAbility 调用点。

3. **与 R1 接口的对接正确性**（用户重点关注 #2）：
   - `HttpClient.get<T>(path, params?)`：DeviceService/SensorService/DiseaseService/AdvisoryService 的 GET 方法调用方式（路径 + params 对象）与 R1 design_spec.md §7 一致；
   - `CacheManager.set<T>(key, data, ttl?)` / `get<T>(key)` / `invalidate(key)` / `clear()`：全部 Service 的缓存读写使用 R1 提供的 4 个方法，缓存键拼接使用 R1 已定义的 `CACHE_KEY_PREFIX_*` 常量，TTL 使用 `CACHE_TTL_*_MS` 常量；
   - `AppStorage` 模式：plan 未引入 AppStorage（AppStorage 是 UI 状态存储，本轮 Service 层不应消费）✓，符合"Service 层不感知 UI 状态"的设计原则；
   - `SensorService.getLatest` 的返回类型 `ApiResponse<SensorSnapshot | SensorSnapshot[] | null>` 与 API 文档 §2.2.1 的"传 device_id 时返回单条/null，不传时返回数组"语义精确匹配。

4. **PollingManager 真实调度覆盖完整**（用户重点关注 #3）：
   - **串行调度**：`tick()` 内部 `await fn()` 后才递归 `setTimeout(tick, intervalMs)`，确保上一个 fn resolve/reject 后才安排下一次，不会并发触发回调 ✓；
   - **失败不中断**：`fn()` 用 `.then(...).catch(err => console.error(...))` 包裹，catch 仅记录日志不重新抛出，递归链继续 ✓；
   - **suspendAll/resumeAll**：`suspendAll` 保留 task 引用 + `clearTimeout` + 置 `suspended=true`，`resumeAll` 仅重启 `suspended=true` 的 task 的 `setTimeout` ✓；
   - **状态转移正确性**：start 内若 key 已存在则先 stop（避免定时器泄漏），suspendAll 后 timerId 置 undefined，resumeAll 后重启定时器 ✓。

5. **CommandService 失败路径刷新逻辑合理**（用户重点关注 #4）：
   - `send` 命中 `code === ERR_CODE_DEVICE_OFFLINE (1003)` → 调用 `DeviceService.refreshDevices(req.device_id)` 强制刷新设备缓存，使下一次 UI 读取时缓存中的 `online` 字段已是最新值；
   - 这是"缓存一致性恢复"的标准模式（lazy invalidation on detected inconsistency），避免了"缓存显示在线但后端已拒绝命令"的窗口期；
   - 仅刷新 DeviceService 而不联动其他 Service 是合理的最小修复范围（本轮范围内）；
   - 选中"先检查缓存后发送"的预检路径与"失败后刷新缓存"的恢复路径形成完整的设备在线状态管理闭环。

6. **API 路径与参数对齐**：
   - `/device/list`（GET，可选 `device_id`）/ `/sensor/latest`（GET，可选 `device_id`）/ `/sensor/history`（GET，必填 `device_id`，可选 start/end/page/page_size）/ `/sensor/daily`（GET，必填 start/end）/ `/disease/list`（GET，多维筛选）/ `/disease/stats` / `/disease/heatmap` / `/command/send`（POST）/ `/command/logs`（GET，多维筛选）/ `/advisory`（GET，可选 window_minutes）——全部路径与方法与 `docs/3_client_api_reference.md` 精确匹配；
   - `CommandRequest` 字段（`device_id` / `command` / `source?` / `operator?`）与 API §2.5.1 请求体一致；
   - `CommandResponse` 字段（`command_id` / `device_id` / `command` / `status`）与 API §2.5.1 响应 data 一致（R1 已加入 models）。

7. **缓存策略合理性**：
   - `SensorService.getHistory` / `getDaily` / `DiseaseService.getList` 不缓存（分页+多维筛选组合空间大，缓存命中率低）✓；
   - `DeviceService.getDeviceList` / `SensorService.getLatest` / `DiseaseService.getStats` / `getHeatmap` / `AdvisoryService.getAdvisory` 缓存（数据相对稳定，TTL 可控）✓；
   - `CommandService.send` / `getLogs` 不缓存（非幂等写入 + 日志频繁追加）✓；
   - `ImageService.uploadImage` / `getRaw` 不缓存（ArrayBuffer 体积大、二进制不可序列化）✓。

8. **选择理由充分**：
   - 纵向切片优先：6 个 Service 是独立的业务边界（设备/传感器/病虫害/命令/建议/图像），可独立编译使用；
   - PollingManager 同步升级：R1 占位不创建定时器，所有 Page 实际接入时会立即失效，本轮补全后 R3 Page 轮询代码才能真正工作；
   - 避免修改 common 层：如 Service 实现期发现契约缺口，记录到设计偏差而非直接修改 common 层（保持 R1 不变约束）。

9. **不在范围内的内容明确列出**：UI 组件、Page 改造、api.ets uploadFile 响应解析、单元测试、EntryAbility/HttpClient/common 层变更——均明确标注为 R3+ 范围。

10. **任务上下文完整**：
    - R1 已交付清单（含 6 个 common 文件 + HttpClient + PollingManager 占位 + EntryAbility 改造）✓；
    - 当前 `impl/temp-R2` 不含 R1 源文件的事实已记录，并给出"cherry-pick 或重新创建"两种处理路径 ✓；
    - 编译验证基线（`hvigorw assembleHap` 或 tsc 严格模式静态检查）明确 ✓；
    - 上轮 5 项设计偏差的影响已评估（本轮 Service 不涉及）✓。

## 修改要求

无（5 个轻微发现均为后续轮次或 Coder 实现细节层面，非阻塞性）。

## 备注

- 5 个轻微发现应在 Coder 实现时记录到 design_spec.md "已知边界/留待后续轮次" 段落，但不影响 R2 计划通过。
- R3+ 接入 Page 时需要回填的边界声明：
  1. 跨 Service 缓存一致性窗口（DeviceService 刷新 vs 其他 Service 缓存）
  2. `PollingManager.suspendAll` 期间 `start` 覆盖已有 key 的语义
  3. `api.ets` uploadFile 真实响应解析（影响 ImageService.uploadImage 调用方实际可用性）
  4. CommandService 发送前缓存预检的边界（缓存未命中 / 设备不在缓存列表）
  5. `getCachedStats` / `getCachedAdvisory` 的缓存键 undefined 兜底