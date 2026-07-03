# 实现报告（R1 r2）

## 概述

按 `design_spec.md`（R1 r2）实现了 FarmEye Guard 鸿蒙应用的最小可编译骨架：
- 6 个 `common/` 文件（models / constants / RetryPolicy / CacheManager / utils / api）
- 2 个 `services/` 文件（HttpClient / PollingManager 占位）
- 1 个 `entryability/` 改造（EntryAbility 注入 `PollingManager` 前后台钩子）

共 8 个源文件 + 1 个改造文件。

## 文件变更清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | `harmony-app/entry/src/main/ets/common/models.ets` | 19 个业务实体 + 5 个响应封装 + 2 个基础设施 + 2 个行为类型的 `interface` / `type` 定义，含 `CommandResponse`（R2 新增）。无运行时副作用。 |
| 新建 | `harmony-app/entry/src/main/ets/common/constants.ets` | 6 类常量：HTTP 配置（6）、轮询间隔（6）、缓存 TTL（5）、缓存键前缀（10）、命令字符串（14）、业务错误码联合类型 `ErrorCode` + 9 个常量、报警位掩码（8）、重试（4）。 |
| 新建 | `harmony-app/entry/src/main/ets/common/RetryPolicy.ets` | 导出 `DEFAULT_RETRY: RetryPolicyConfig` 常量；`timeoutMs` 字段保留为契约字段（注释说明语义）。 |
| 新建 | `harmony-app/entry/src/main/ets/common/CacheManager.ets` | 模块级 `Map<string, CacheEntry<unknown>>` 单例；导出 `set` / `get`（TTL 过期自动 invalidate） / `invalidate` / `clear` 四个方法。 |
| 新建 | `harmony-app/entry/src/main/ets/common/utils.ets` | 6 个纯函数：`formatTimestamp` / `parseAlarmFlag`（按 8 个 `ALARM_FLAG_*` 掩码返回中文报警名） / `sleep` / `buildQueryString`（`undefined` 跳过） / `isNetworkError` / `nowMs`。 |
| 新建 | `harmony-app/entry/src/main/ets/common/api.ets` | 原始传输层：`request`（文本）/ `requestRaw`（二进制，`http.HttpDataType.ARRAY_BUFFER`）/ `uploadFile`（`@ohos.request.uploadFile` 占位）。`request` / `requestRaw` 内部 `try-catch (err: BusinessError)` 类型守卫，`httpRequest.destroy()` 在 `.finally()` 释放。`uploadFile` 内部将 `Record<string, string>` form data 转换为 `Array<RequestData>`，使用 `internal://cache/` URI 规范与 `filename` 字段；`headerReceive` / `complete` / `fail` 钩子的业务响应解析留待后续轮次。 |
| 新建 | `harmony-app/entry/src/main/ets/services/HttpClient.ets` | 业务门面层：导出 `BASE_URL`（含 `/api/v1` 前缀）与 `HEADER_KEY` 常量；`get<T>` / `getRaw` 通过 `withRetry` 辅助函数实现指数退避（`base * 2^attempt`，截断到 `maxDelayMs`），网络错误与 `statusCode ∈ retryOn` 触发重试；`post<T>` 不触发重试（POST 非幂等）。`JSON.parse` 错误统一包装为 `Error('JSON parse error: ...')`。 |
| 新建 | `harmony-app/entry/src/main/ets/services/PollingManager.ets` | 占位实现：`tasks: Map<string, PollingTask>`；`start` 形参下划线前缀（`_key` / `_fn` / `_interval`）显式标注故意忽略；`suspendAll` / `resumeAll` 仅修改 `running` 字段；不创建定时器、不调用回调。 |
| 改造 | `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets` | 追加 `import { PollingManager } from '../services/PollingManager';`；`onForeground` 末尾追加 `PollingManager.resumeAll();`；`onBackground` 末尾追加 `PollingManager.suspendAll();`。其它逻辑（`DOMAIN` / `onCreate` / `onDestroy` / `onWindowStageCreate` / `onWindowStageDestroy`）保持原模板不变。 |

## 编译验证

**未执行 hvigorw 编译**（当前沙箱环境未安装 HarmonyOS SDK 与 hvigor 工具链，`oh_modules` 仅含 `hamock` / `hypium` 桩包）。

**已通过 TypeScript 6.0.3 静态类型检查**（在 `/tmp/arkts-check` 沙箱中复制全部源文件并补齐 HarmonyOS 模块的 `.d.ts` 桩声明后执行 `tsc --noEmit`）：

```
$ tsc --noEmit --noUnusedLocals --noUnusedParameters --noImplicitAny --noImplicitReturns --noFallthroughCasesInSwitch
Exit: 0
```

通过的检查项：
- `strict: true`（含 `strictNullChecks` / `noImplicitAny`）
- `--noUnusedLocals` / `--noUnusedParameters`（无未使用局部变量与形参）
- `--noImplicitReturns`（所有函数路径均有显式 return 或 throw）
- `--noFallthroughCasesInSwitch`（`switch` 分支无遗漏 break）

实际 `hvigorw assembleHap --mode module -p product=default` 编译需在装有 HarmonyOS DevEco Studio / hvigor 工具链的环境下执行。

## 设计偏差说明

### 偏差 1：`api.ets` 中 `request` 的 `header` 字段命名

**设计规格**：`api.ets` §6 伪代码使用 `headerData: headers`

**实际处理**：使用 `header: headers`。原因：经核对 `@ohos.net.http` 官方文档（API 6+），`HttpRequestOptions.header` 字段名为 `header`（类型 `Object`），`headerData` 不存在。`extraData` 字段名与官方一致。

**决策依据**：编译正确性优先于设计规格的伪代码细节；设计规格在 §"实施风险与边界声明" L1158 也明确"ArkTS 的 `@kit.*` 模块名与原 `@ohos.*` 模块名可能在编译期因 SDK 版本不同而需要切换"，允许此类适配。

### 偏差 2：`api.ets` 中 `uploadFile` 的 `UploadConfig.data` / `files[].uri` 字段

**设计规格**：`data: Record<string, string>` 形式直接传入；`uri: 'file://' + filePath`

**实际处理**：
- 内部将 `data: Record<string, string>` 转换为 `Array<ohRequest.RequestData>`（`{name, value}[]`）后再传入 `ohRequest.uploadFile`。
- `files[].uri` 改为 `internal://cache/` 路径前缀，并补充 `filename` 字段（从 `filePath` 末段提取）。

**原因**：核对 `@ohos.request` 官方文档（API 9+）后，`UploadConfig.data` 实际为 `Array<RequestData>` 类型；`File.uri` 文档明确"仅支持 `internal://cache/`"，`file://` 不被原生支持。

**决策依据**：设计规格 L1161 风险声明"实现期需按 `@ohos.request.uploadFile` 实际文档适配"；当前轮次 `ImageService` 不在实现范围内，`uploadFile` 仅为占位骨架，故转换 + 路径规范化以最大化编译兼容性。后续轮次若 `ImageService` 需求变更，可调整此处的传参约定。

### 偏差 3：`api.ets` 中 `uploadFile` 的业务响应解析

**设计规格**：解析响应 JSON 为 `ApiResponse<ImageUploadResult>`。

**实际处理**：当前 `task.on('complete', ...)` 钩子 resolve 一个 `code: 0, message: 'success', data: null` 的占位 `ApiResponse<ImageUploadResult>`；真实响应 JSON 解析（`headerReceive` 钩子缓存响应体 → `complete` 钩子解析）留待后续轮次。

**原因**：设计规格未指定响应体的具体抓取时序与存储位置；后续轮次需要决定"在 `headerReceive` 中累计 body + `complete` 中 parse"或"通过 `UploadTask` 的 `getTaskInfo()` 等渠道"的方案。

### 偏差 4：`api.ets` 中 `httpRequest.request()` 的 `method` 字段

**设计规格**：`options.method: 'GET' | 'POST'`（字符串字面量联合类型）直接赋值给 `HttpRequestOptions.method`。

**实际处理**：使用 `options.method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST` 显式转换为 `RequestMethod` 枚举值。

**原因**：`HttpRequestOptions.method` 声明类型为 `http.RequestMethod`（字符串枚举），`options.method` 类型为字符串字面量联合。ArkTS 严格类型下隐式转换可能触发 `ts(2322)` 错误，显式三元判断可避免潜在告警。

### 偏差 5：`PollingManager.suspendAll` / `resumeAll` 的 Map 遍历方式

**设计规格**：遍历 `tasks` Map 并修改 `running` 字段。

**实际处理**：使用 `Array.from(tasks.keys())` 先收集 keys，再用 `for` 循环 + `tasks.set(k, ...)` 写回；不使用 `tasks.entries()` 迭代器（避免在 ArkTS 严格类型下对 `[string, PollingTask]` 元组解构的兼容性差异）。

**决策依据**：遍历期间不删除元素，仅修改 `running` 字段，行为等价。两种实现均符合设计语义；当前实现更保守、对 ArkTS 类型推断更友好。

---

## 修订说明

本轮为 R1 r2 首轮实现，无既往审查意见需处理。

## 下一步

后续轮次将：
1. 实现 `services/` 下 6 个业务 Service（SensorService / DiseaseService / CommandService / AdvisoryService / DeviceService / ImageService）。
2. 补全 `PollingManager` 的递归 `setTimeout` 串行调度逻辑。
3. 补全 `api.ets` `uploadFile` 的 `headerReceive` / `complete` 钩子中的真实业务响应解析。
4. 替换 `API_BASE_URL` 中的 `<VPS_IP>` 占位符为实际生产环境域名。
