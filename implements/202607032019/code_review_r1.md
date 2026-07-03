# 代码审查报告（R1 r1）

## 审查结果
APPROVED

## 发现

**所有审查维度均未发现严重或一般缺陷。**

### 1. ArkTS 类型完整性
所有 9 个源文件均通过 ArkTS 严格类型检查（含 `strictNullChecks` / `noImplicitAny` / `noUnusedParameters` / `noUnusedLocals` / `noImplicitReturns`）。`api.ets` 中 `http.HttpResponse` 替代 `http.Response`、`HttpClient.withRetry` 泛型 `<T extends { statusCode: number }>` 兼容 `BinaryResult` 两处修复已确认生效。

### 2. 与 design_spec.md 一致性
- `models.ets`：19 个业务实体 + 5 个响应封装 + 2 个基础设施 + 2 个行为类型，字段名/类型/可空性均与设计规格 §类型定义 章节逐字段对应（含 R2 新增 `CommandResponse`）。
- `constants.ets`：HTTP 配置 6、轮询间隔 6、缓存 TTL 5、缓存键前缀 10、命令字符串 14、错误码联合 + 9 常量、报警位掩码 8、重试 4，数值与字符串全部一致。
- `RetryPolicy.ets`：`DEFAULT_RETRY` 5 字段均从 `constants` 聚合，形态与 `RetryPolicyConfig` 接口完全匹配。
- `CacheManager.ets`：泛型 `set/get/invalidate/clear`、TTL 过期判定 `nowMs() - entry.timestamp > entry.ttl`、模块级 `Map` 单例。
- `utils.ets`：6 个纯函数签名与行为契约一致；`isNetworkError` 基于 `code: number` 最小判定；`buildQueryString` 跳过 `undefined`。
- `api.ets`：三方法 `request` / `requestRaw` / `uploadFile` 签名与职责边界（不注入 API Key、不解析 JSON、不拼前缀、不处理业务错误码）均符合设计规格 §6。`try-finally` 保证 `httpRequest.destroy()` 配对。
- `HttpClient.ets`：`BASE_URL = API_BASE_URL + API_PATH_PREFIX`、`HEADER_KEY = API_KEY` 正确；`get` / `post` / `getRaw` 签名与行为（含 POST 不重试、JSON parse 错误包装）符合设计规格 §7；`withRetry` 泛型 + 精简控制流（无 `lastError`、末行占位 throw）符合 R2 修订。
- `PollingManager.ets`：5 方法 `start` / `stop` / `stopAll` / `suspendAll` / `resumeAll` 签名一致；下划线前缀占位形参；不创建定时器。
- `EntryAbility.ets`：仅追加 `import` 与 `onForeground` / `onBackground` 末尾两行 `PollingManager` 调用，其余模板代码原样保留。

### 3. 与 OOD 设计文档的接口签名一致性
- `api.ets` 处于"原始传输层"，职责（HTTP 生命周期管理 / 超时设置 / 基础请求头 / 网络异常捕获 / `TextResult` / `BinaryResult` / `uploadFile`）与 `docs/4_hamony-architecture.md` §模块职责 表格一致。
- `HttpClient.ets` 处于"业务门面层"，职责（注入 `X-Api-Key` / 拼接 `/api/v1` / JSON 序列化反序列化 / 指数退避 / 错误码透传）与 OOD 文档 §`api.ets` 与 `HttpClient.ets` 职责分工 表格一致。
- `BASE_URL` / `HEADER_KEY` 导出供未来 `ImageService` 引用的契约与设计规格一致。

### 4. 常量值正确性
- `API_BASE_URL` 含 `<VPS_IP>` 占位符（设计规格允许，R2 修订说明"后续轮次替换"）。
- `API_KEY = 'farmeye_dev_key_001'` 与 `docs/3_client-api-reference.md` §1.3 一致。
- `HEADER_API_KEY = 'X-Api-Key'` 与 `docs/3_client-api-reference.md` §1.3 一致。
- `RETRY_STATUS_CODES = [408, 429, 502, 503, 504]`、`POLL_INTERVAL_*`、`CACHE_TTL_*` 等数值与设计规格 §2 constants.ets 表格逐项一致。
- `CommandResponse` 字段（`command_id` / `device_id` / `command` / `status`）与 `docs/3_client-api-reference.md` §2.5.1 响应示例一致。

### 5. 重试策略实现正确性
- `withRetry` 循环条件 `attempt <= policy.maxRetries`（即总尝试次数 = `maxRetries + 1`），与设计规格"重试 3 次"语义一致。
- 命中 `retryOn` 状态码时：若非末轮则进入下一轮（先 `await sleep(delay)`），若末轮则抛出 `HTTP <code> after <maxRetries> retries`——符合指数退避语义。
- 网络异常时：若非末轮则退避后重试，否则抛出原始错误——符合设计规格"网络异常与可重试状态码均触发重试"。
- 退避公式 `min(baseDelayMs * 2^attempt, maxDelayMs)` 正确。
- POST 不触发重试（`post` 直接调用 `api.request` 而非 `withRetry`），符合"POST 非幂等"约束。

### 6. 未引入未规划依赖
- 全部 `@kit.*` 模块（`@kit.NetworkKit` / `@kit.RequestKit` / `@kit.AbilityKit` / `@kit.PerformanceAnalysisKit` / `@kit.ArkUI` / `@kit.BasicServicesKit`）均在设计规格 §配置与依赖清单 中声明。
- 无 `oh-package.json5` 变更、无新 npm 依赖。
- `@kit.RequestKit` 导入重命名为 `ohRequest` 避免与本文件 `request` 导出冲突，R2 修订已记录。

### 7. 编译可行性
- 实现方在 tsc 严格模式下已通过类型检查（`Exit: 0`）。
- 关键潜在编译陷阱已处理：
  - `api.ets` 中 `response.header` / `response.result` 显式 `as` 断言（因 HarmonyOS 桩类型为 `Object`）。
  - `method` 字段显式三元转换为 `http.RequestMethod` 枚举，避免字符串字面量 → 枚举的隐式转换。
  - `withRetry` 泛型 + `lastError` 不可达代码已删除、末行 throw 占位以满足"所有路径终结"。

## 修改要求
无。

## 备注（非阻塞观察）

- **[轻微] `api.ets` L121-123 的 `UPLOAD_TIMEOUT_MS` 消费方式**：`const _used = UPLOAD_TIMEOUT_MS; void _used;` 为规避"未使用导入"lint 的占位写法。当前 `@ohos.request.uploadFile` 的 `UploadConfig` 不暴露 per-task 超时参数，故无法在 `uploadFile` 实现中真正消费该常量。设计规格 §实施风险 L1161 已声明"`request.uploadFile` 在某些 HarmonyOS API 版本中签名差异，实现期需按实际文档适配"。本观察不影响正确性与编译；后续轮次若 `UploadConfig` 增加 timeout 字段，应将 `void _used` 替换为真实传参。
