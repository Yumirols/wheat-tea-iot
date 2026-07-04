# 设计审查报告（R1 r1）

## 审查结果

REJECTED

## 发现

### [一般] HttpClient.ets 缺少 utils 模块的 `isNetworkError` / `sleep` 导入

**位置**：`harmony-app/entry/src/main/ets/services/HttpClient.ets`（设计规格第 880-885 行 `导入语句`）

设计规格中 `HttpClient` 的 `withRetry` 伪代码（第 962、972 行）调用了 `isNetworkError(err)` 和 `sleep(delay)`，但 `HttpClient.ets` 的导入语句只声明：

```typescript
import { ApiResponse, TextResult, BinaryResult } from '../common/models';
import { API_BASE_URL, API_PATH_PREFIX, API_KEY, HEADER_API_KEY, DEFAULT_TIMEOUT_MS } from '../common/constants';
import { DEFAULT_RETRY } from '../common/RetryPolicy';
import { request, requestRaw } from '../common/api';
```

`utils.ets` 的导出未导入。如果按此规格编码，实现期编译会因找不到 `isNetworkError` 与 `sleep` 符号而失败。

**期望修正**：在 `HttpClient.ets` 导入语句中追加：
```typescript
import { isNetworkError, sleep } from '../common/utils';
```

---

### [一般] `api.ets` 中 `import { request } from '@kit.RequestKit'` 与同名函数形参/导出名冲突

**位置**：`harmony-app/entry/src/main/ets/common/api.ets`（设计规格第 798 行）

设计规格列出：
```typescript
import { http } from '@kit.NetworkKit';
import { request } from '@kit.RequestKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
```

但同一文件内又导出 `export function request(url, options)`（第 811 行）。ArkTS 中模块导入与文件级导出同名会导致：
- 文件内部 `request(...)` 调用被遮蔽为模块导入引用（而模块本身不具备可调用签名）
- 即便 ArkTS 允许重命名，但调用语义不清晰

**期望修正**：将 `@kit.RequestKit` 的导入重命名以避免冲突：
```typescript
import { request as ohRequest } from '@kit.RequestKit';
```
并在 `uploadFile` 实现中改用 `ohRequest.uploadFile(context, config)` / `ohRequest.agent.create()`。

---

### [一般] `models.ets` 缺少 `CommandResponse` 接口

**位置**：`harmony-app/entry/src/main/ets/common/models.ets`（设计规格"完整导出清单"第 564-596 行）

依据 `docs/3_client-api-reference.md` §2.5.1，`POST /command/send` 的成功响应 `data` 字段结构为：
```json
{
  "command_id": "cmd_20260703_143000_187",
  "device_id": "farmeye_guard_ws63",
  "command": "spray ON",
  "status": "sent"
}
```

当前 `models.ets` 仅有 `CommandRequest`（请求体）与 `CommandLog`（日志实体），**未定义** `CommandResponse`（`/command/send` 响应实体）。后续 `CommandService.send()` 需要此类型来解析响应 `data`。

虽然首轮 `CommandService` 属"非范围"，但 `models.ets` 是本轮交付的核心契约文件，遗漏此类型会导致下一轮编码时必须回头修改 common 层——违背"common 层签名固化"的目标。

**期望修正**：在"业务实体"分组下补充：
```typescript
export interface CommandResponse {
  command_id: string;
  device_id: string;
  command: string;
  status: string;
}
```

---

### [轻微] `withRetry` 伪代码 `lastError` 在状态码路径上不被使用

**位置**：`harmony-app/entry/src/main/ets/services/HttpClient.ets`（设计规格第 945-975 行）

伪代码：
```typescript
let lastError: Error | null = null;
for (let attempt = 0; ...) {
  try {
    const result = await operation();
    if (policy.retryOn.includes(result.statusCode)) {
      if (attempt === policy.maxRetries) {
        throw new Error(`HTTP ${result.statusCode} after ${attempt} retries`);
      }
    } else {
      return result;
    }
  } catch (err) {
    lastError = err as Error;
    if (!isNetworkError(err) || attempt === policy.maxRetries) {
      throw err;
    }
  }
  await sleep(delay);
}
throw lastError ?? new Error('Retry exhausted');
```

分析：
- 当重试路径因 `statusCode` 命中 `retryOn` 且非最后一次时，进入下一轮；最后一次时 `throw` 会被 `catch` 接住，因 `!isNetworkError` 为真直接重抛——`lastError` 在此路径上仅作短暂赋值即被重抛覆盖，**功能上无害**。
- 当网络异常路径耗尽（`isNetworkError(err) && attempt === maxRetries`），`if` 条件为真，重抛 `err`——`lastError` 同样未被读出。
- 末行 `throw lastError ?? new Error(...)` **仅在循环正常退出**时执行；由于 `for` 条件为 `attempt <= policy.maxRetries` 且每次循环要么 `return` 要么 `throw`，正常退出不可达。

**期望修正**（可选改进）：删除 `lastError` 变量及末行 `throw`，因不可达；或改 `for` 条件为 `attempt < policy.maxRetries` 并保留末行作为兜底。

---

### [轻微] `api.ets` 导入 `BusinessError` 但导出接口未直接使用

**位置**：`harmony-app/entry/src/main/ets/common/api.ets`（设计规格第 800 行）

```typescript
import { BusinessError } from '@kit.BasicServicesKit';
```

`api.ets` 的导出函数（`request` / `requestRaw` / `uploadFile`）的伪代码中均未声明使用 `BusinessError` 类型。`api.ets` 自身 `try-catch` 后直接 `throw new Error(...)`，未使用 `BusinessError` 类型守卫。编译可通过，但属于"未使用导入"——在严格 lint 规则下可能产生 warning（与规格"避免 warning"要求相违）。

**期望修正**：要么在 `try-catch` 处显式 `catch (err: BusinessError)` 后再包装为 `Error`（类型清晰且正确捕获原生错误），要么删除该导入。

---

### [轻微] `PollingManager` 占位实现接受 `PollingCallback` 与 `interval` 参数但不使用

**位置**：`harmony-app/entry/src/main/ets/services/PollingManager.ets`（设计规格第 1009 行）

```typescript
start(key: string, fn: PollingCallback, interval: number): void
```

占位边界声明（设计规格第 1023-1024 行）已明确：`fn` 与 `interval` 参数被忽略。但 ArkTS 严格类型与某些 lint 规则可能对"未使用形参"产生 warning。设计规格"实施风险与边界声明"未涵盖此点。

**期望修正**：实现期可使用下划线前缀命名（如 `_fn: PollingCallback, _interval: number`）以暗示显式忽略；或在本规格"占位边界声明"中补充"形参命名以下划线开头"的约定。

---

### [轻微] `DEFAULT_RETRY.timeoutMs` 字段用途未在 `HttpClient` 中消费

**位置**：`common/RetryPolicy.ets`（设计规格第 719-726 行）& `services/HttpClient.ets`

`RetryPolicyConfig` 接口含 `timeoutMs: number`，`DEFAULT_RETRY` 将其设为 `DEFAULT_TIMEOUT_MS`。但 `HttpClient` 的 `get/post/getRaw` 伪代码未在任何路径读取 `policy.timeoutMs`——超时由 `api.ets` 内部直接使用 `DEFAULT_TIMEOUT_MS` 常量。

`RetryPolicyConfig.timeoutMs` 成为"名义定义但运行时无消费者"的字段。两值通过 `DEFAULT_RETRY` 同步，但若实现期将超时策略改为"按重试次数退避调整"则需要此字段。当前实现下它是无用字段。

**期望修正**（二选一）：
- 在 `api.ets` 改造为接收 `timeoutMs` 参数并由 `HttpClient` 传入 `policy.timeoutMs`（规格更自洽）；
- 或在本规格"实施风险与边界声明"中补充"timeoutMs 当前为冗余字段，保留是为后续动态超时策略预留"。

---

## 修改要求（汇总）

实现前必须修正（一般级别）：

1. `HttpClient.ets` 导入语句追加 `import { isNetworkError, sleep } from '../common/utils';`
2. `api.ets` 中 `@kit.RequestKit` 的导入重命名（如 `ohRequest`），避免与文件级 `request` 导出冲突；`uploadFile` 实现中相应引用 `ohRequest.uploadFile` / `ohRequest.agent`。
3. `models.ets` 补充 `CommandResponse` 接口（`command_id`, `device_id`, `command`, `status` 四字段）。

实现期可一并处理（轻微级别）：

4. `withRetry` 伪代码精简 `lastError` 与末行（可选）。
5. `api.ets` 的 `BusinessError` 导入要么实际使用（`catch (err: BusinessError)`），要么删除。
6. `PollingManager.start` 占位形参可用下划线前缀。
7. `DEFAULT_RETRY.timeoutMs` 要么由 `api.ets` 消费，要么在"实施风险"中声明冗余语义。
