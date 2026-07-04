# 实现报告（R2）

## 概述

按 `design_spec.md` 实现 `services/` 层全部 6 个业务 Service + 将 `PollingManager` 从 R1 占位升级为真实递归 `setTimeout` 串行调度。同时恢复 R1 已交付的 `common/` 层 6 个文件 + `HttpClient.ets` + `EntryAbility.ets` + `EntryBackupAbility.ets` + `Index.ets`（R1 在 `impl/202607032019-common-baseline` 分支，当前 `impl/temp-R2` 工作树不含 R1 源文件；按 `plan.md` 上下文说明"重新创建"）。

完成后：
- `harmony-app/entry/src/main/ets/services/` 下 7 个文件（6 个 Service + PollingManager）
- `harmony-app/entry/src/main/ets/common/` 下 6 个 R1 文件（未修改）
- `harmony-app/entry/src/main/ets/services/HttpClient.ets` 保留 R1 形态（未修改）
- `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets` 恢复 R1 形态（含 `PollingManager.resumeAll/suspendAll` 调用）

## 文件变更清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | `harmony-app/entry/src/main/ets/services/DeviceService.ets` | 实现 `DeviceService`（`getDeviceList` / `getCachedDevices` / `refreshDevices`） |
| 新建 | `harmony-app/entry/src/main/ets/services/SensorService.ets` | 实现 `SensorService`（`getLatest` / `getAllLatest` / `getHistory` / `getDaily`） |
| 新建 | `harmony-app/entry/src/main/ets/services/DiseaseService.ets` | 实现 `DiseaseService`（`getList` / `getStats` / `getHeatmap` + `DiseaseListFilters` 接口） |
| 新建 | `harmony-app/entry/src/main/ets/services/CommandService.ets` | 实现 `CommandService`（`send` 含前置校验+失败路径刷新 / `getLogs`） |
| 新建 | `harmony-app/entry/src/main/ets/services/AdvisoryService.ets` | 实现 `AdvisoryService`（`getAdvisory`） |
| 新建 | `harmony-app/entry/src/main/ets/services/ImageService.ets` | 实现 `ImageService`（`uploadImage` / `getImagePixelMap`） |
| 改造 | `harmony-app/entry/src/main/ets/services/PollingManager.ets` | 从 R1 占位升级为递归 `setTimeout` 串行调度实现 |
| 恢复 | `harmony-app/entry/src/main/ets/common/models.ets` | 恢复 R1 交付的 models 契约（**未修改**） |
| 恢复 | `harmony-app/entry/src/main/ets/common/constants.ets` | 恢复 R1 交付的 constants（**未修改**） |
| 恢复 | `harmony-app/entry/src/main/ets/common/CacheManager.ets` | 恢复 R1 交付的 CacheManager（**未修改**） |
| 恢复 | `harmony-app/entry/src/main/ets/common/RetryPolicy.ets` | 恢复 R1 交付的 RetryPolicy（**未修改**） |
| 恢复 | `harmony-app/entry/src/main/ets/common/utils.ets` | 恢复 R1 交付的 utils（**未修改**） |
| 恢复 | `harmony-app/entry/src/main/ets/common/api.ets` | 恢复 R1 交付的 api（**未修改**） |
| 恢复 | `harmony-app/entry/src/main/ets/services/HttpClient.ets` | 恢复 R1 交付的 HttpClient（**未修改**） |
| 恢复 | `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets` | 恢复 R1 交付的 EntryAbility（含 `onBackground`/`onForeground` 接入 `PollingManager`） |
| 恢复 | `harmony-app/entry/src/main/ets/entrybackupability/EntryBackupAbility.ets` | 恢复 R1 交付的 EntryBackupAbility（**未修改**） |
| 恢复 | `harmony-app/entry/src/main/ets/pages/Index.ets` | 恢复 R1 交付的 Index.ets（**未修改**） |

## 编译验证

按 R1 `run_report.md` 验证方法（同步源文件到 `/tmp/arkts-check/src-ts/` → 派生 `.ts` 副本 → `tsc -p .` strict 模式类型检查）执行：

```
命令:
  rm -rf /tmp/arkts-check/src-ts/{common,services,entryability}
  mkdir -p /tmp/arkts-check/src-ts/{common,services,entryability}
  cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/common/*.ets    /tmp/arkts-check/src-ts/common/
  cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/services/*.ets   /tmp/arkts-check/src-ts/services/
  cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/entryability/*.ets /tmp/arkts-check/src-ts/entryability/
  cd /tmp/arkts-check/src-ts
  for d in common services entryability; do for f in $d/*.ets; do base=$(basename "$f" .ets); dir=$(dirname "$f"); cp "$f" "$dir/$base.ts"; done; done
  cd /tmp/arkts-check && tsc -p .
```

结果：

- 源文件：6（common）+ 7（services，含 R1 `HttpClient`/`PollingManager` 升级 + 6 新 Service）+ 1（entryability）= 14 个 `.ets`
- TypeScript strict 模式（`strict: true`、`noImplicitAny: true`、`strictNullChecks: true`）：**exit 0，0 errors**
- HarmonyOS Kit 模块 stub 解析正常：`@kit.NetworkKit`、`@kit.RequestKit`、`@kit.AbilityKit`、`@kit.PerformanceAnalysisKit`、`@kit.ArkUI`、`@kit.BasicServicesKit`

注：未执行 `hvigorw assembleHap` 鸿蒙原生编译（本地无 hvigorw 命令，R1 同等做法仅做 tsc strict 类型检查作为编译验证基线）。

## 关键实现要点

### PollingManager 真实实现（核心改造）

- **串行模式**：`tick(key)` 中先 `task.timerId = null`，再调用 `task.fn()`，其 `.then/.catch/.finally` 在 `finally` 中再次检查 `tasks.get(key)` 仍存在且未 suspended，递归调用 `scheduleNext(key)` 注册下一 tick。`scheduleNext` 使用 `setTimeout(tick, intervalMs)`，整体形成"tick 完成 → 等 intervalMs → 下一 tick"链。
- **错误不中断**：`tick` 中 `.catch` 块以 `console.error('PollingManager tick error', JSON.stringify(err))` 记录错误但不 reject；`.finally` 仍调度下一 tick。
- **暂停 / 恢复**：`suspendAll` 对所有 `timerId !== null` 的任务 `clearTimeout` 并置 `suspended = true`，**保留**任务引用；`resumeAll` 对 `suspended === true` 的任务 `scheduleNext` 重启。
- **公开 API 完全兼容 R1**：`start(key, fn, intervalMs)` / `stop(key)` / `stopAll()` / `suspendAll()` / `resumeAll()` 五个方法签名与 R1 占位一致（`EntryAbility` 调用点 `onBackground`/`onForeground` 不破坏）。
- **`timerId = null` 必须在 `task.fn()` 之前置位**——避免 `stop(key)` 在 tick 期间被调用时 `clearTimeout(null)` 报错（设计规格"实施风险与边界声明"显式约束）。

### CommandService 失败路径

- **前置校验**：调用 `DeviceService.getCachedDevices(deviceId)`，若发现设备 `online === false` 直接 `throw new Error('Device offline')`；缓存中找不到该设备（未初始化）**放行**。
- **业务失败路径**：`code === ERR_CODE_DEVICE_OFFLINE (1003)` 时 `await DeviceService.refreshDevices(deviceId)` 刷新缓存后 `throw new Error(resp.message)`；其它业务错误直接抛 `resp.message`。
- **HTTP 层异常**：透传 `HttpClient` 抛出的 `Error`，**不**主动刷新缓存（设备可能仅是网络问题）。
- **单向依赖**：`CommandService` → `DeviceService` 单向；`DeviceService` 不引用 `CommandService`，无循环。

### 缓存策略

- **写入条件**：`code === 0 && data !== null` 时 `CacheManager.set(key, data, ttl)`，ttl 取自 `constants.ets` 中相应 `CACHE_TTL_*_MS`。
- **命中读取**：`getLatest` / `getAllLatest` / `getStats` / `getHeatmap` / `getAdvisory` 先 `CacheManager.get<T>(key)`，命中即返回。
- **不缓存**：`getHistory` / `getDaily` / `getList`（分页+时间范围/多维筛选组合空间大）、`send` / `getLogs` / `uploadImage` / `getImagePixelMap`（每次均为真实操作或体积大）。
- **`DeviceService` 模块级缓存**：`cachedDevices: DeviceInfo[] = []` + `lastFetchTime: number = 0`；`getCachedDevices` 同步返回；`getDeviceList` 仅在 `deviceId === undefined` 时更新模块级缓存（避免单设备结果覆盖全量缓存）。

### ArkTS 严格类型

- **零 `any`**：所有 Service 方法签名与缓存读写使用泛型 `<T>`，未使用 `any`。
- **类型守卫**：`Array.isArray` / `=== undefined` / `!== null` 显式判别；`Map.get` 返回 `T | undefined`，调用方显式 `if (task === undefined) return`。
- **`Error` 实例化**：业务失败统一 `throw new Error(resp.message || '<default msg>')`，堆栈与 message 保留。

### 模块依赖图（R2 新增）

```
DeviceService    → HttpClient.get, CacheManager, models, constants, utils
SensorService    → HttpClient.get, CacheManager, models, constants
DiseaseService   → HttpClient.get, CacheManager, models, constants
CommandService   → HttpClient.post/get, DeviceService, models, constants
AdvisoryService  → HttpClient.get, CacheManager, models, constants
ImageService     → HttpClient.BASE_URL/HEADER_KEY/getRaw, api.uploadFile, @kit.AbilityKit, models, constants
PollingManager   → models (PollingCallback)
```

## 设计偏差说明

| 偏差项 | 原因 | 影响范围 |
|--------|------|----------|
| `R1 源文件` 需在工作树中重新创建 | R1 在 `impl/202607032019-common-baseline` 分支交付，当前 `impl/temp-R2` 工作树不含 R1 源文件（`common/*` + `HttpClient.ets` + `EntryAbility.ets`）。按 `plan.md` 上下文说明 "Coder 需 cherry-pick R1 后追加 R2 增量，或重新创建"，本轮按 R1 已交付内容**逐字节**重建（未做任何"发挥"）。 | `common/` 6 文件 + `HttpClient.ets` + `EntryAbility.ets` + `EntryBackupAbility.ets` + `Index.ets` |
| `DiseaseService.getList` 形参 `filters?: DiseaseListFilters` 而非内联对象字面量类型 | 用户指令中 `filters?` 内联对象字面量形式在 ArkTS strict 模式下与导出类型"显式命名接口"风格不一致；本实现显式声明 `DiseaseListFilters` 接口并在同模块 `export`，便于后续 Page 层复用类型 | `DiseaseService` 公开 API 的入参类型；调用方需 `import { DiseaseListFilters }` 或 `import { DiseaseService }` 后通过 `DiseaseService` 间接使用 |
| `CommandService.send` 中 `body` 显式按 `undefined` 字段跳过 | 用户指令中 body 可"undefined 字段由 JSON.stringify 自然忽略"；但 ArkTS 严格模式 + `Record<string, string>` 不允许 `undefined` 值；本实现以 `if (source !== undefined) body['source'] = source` 显式条件赋值，确保 `body: Record<string, string>` 类型完整 | `CommandService.send` 内部；语义不变（结果与 `JSON.stringify({...with undefined})` 相同） |
| `PollingManager.tick` 中错误日志使用 `console.error` | 用户指令中 `.catch` 块使用 `console.error`；ArkTS 全局可访问 `console` 对象（与浏览器 API 兼容），无需额外导入 | `PollingManager` 内部；记录但不中断轮询 |

## 已知约束与后续轮次

- `ImageService.uploadImage` 中 `api.uploadFile` 当前 R1 占位实现返回 `code: 0, data: null`；按 R2 设计规格明确"占位行为保留"，上层调用方需在后续轮次适配（`null` 不抛错，由调用方处理）。
- `SensorService.getLatest` 强制 `deviceId`，空 `deviceId` 时后端将返回数组形态——本实现已在该路径断言 `Array.isArray(resp.data) === false` 并抛 `Error('Expected single sensor snapshot')`。
- `CommandService` 单向依赖 `DeviceService`（无循环）；`getCachedDevices` 为同步方法，不触发异步链路，避免死锁。
- 单元测试 → 独立测试轮次（design_spec §非范围）。

## 风险与边界声明

- 递归 `setTimeout` 通过 `Promise.then` / `catch` / `finally` 链异步展开，不存在调用栈累积。
- `PollingManager.scheduleNext` 在 `suspended === true` 时直接返回，**不会**错误地重置已暂停任务的定时器。
- `CacheManager` TTL 过期自动失效由 R1 固化；本轮 Service 依赖 `null` 返回值判断未命中。
- `HttpClient.post` 不重试（POST 非幂等），由 `CommandService.send` 透传 `Error`；调用方可按需在 UI 层加重试按钮。
