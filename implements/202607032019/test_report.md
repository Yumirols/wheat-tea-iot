# 测试报告（R1）

## 概述

为 R1 实现的 common 层（models / constants / RetryPolicy / CacheManager / utils / api）+ HttpClient + PollingManager 占位 + EntryAbility 编写本地单元测试。覆盖纯函数、可独立测试的模块，并对依赖网络/定时器的模块（HttpClient / api.ets / PollingManager 实际调度）标注后续轮次集成测试。

测试入口位于 `entry/src/test/List.test.ets`，由 hvigor 测试构建器按 localUnitTest 目标编译并执行。

## 测试文件清单

| 操作 | 文件路径 | 覆盖的行为契约 |
|------|---------|---------------|
| 新建 | `harmony-app/entry/src/test/UtilsTest.test.ets` | utils.ets 的 6 个纯函数：formatTimestamp / parseAlarmFlag / buildQueryString / isNetworkError / nowMs / sleep |
| 新建 | `harmony-app/entry/src/test/CacheManagerTest.test.ets` | CacheManager 的 set/get/invalidate/clear 与 TTL 过期自动失效 |
| 新建 | `harmony-app/entry/src/test/RetryPolicyTest.test.ets` | DEFAULT_RETRY 常量各字段与 RETRY_* 常量的一致性 |
| 新建 | `harmony-app/entry/src/test/ConstantsTest.test.ets` | constants.ets 的关键值：HTTP 配置 / 轮询间隔 / 缓存 TTL / 缓存键前缀 / 命令字符串 / 业务错误码 / 报警位掩码 / 重试配置 |
| 新建 | `harmony-app/entry/src/test/PollingManagerTest.test.ets` | PollingManager 占位实现的 start/stop/stopAll/suspendAll/resumeAll 行为契约（无副作用、覆盖不抛错、循环可用） |
| 修改 | `harmony-app/entry/src/test/List.test.ets` | 注册全部新增测试套件 |

## 覆盖的测试维度

### 正常路径
- `formatTimestamp('2026-07-03T14:30:00')` → `'2026-07-03 14:30:00'`
- `parseAlarmFlag(0x01)` → `['高温']`
- `buildQueryString({ device_id: 'd1' })` → `'?device_id=d1'`
- `CacheManager.set('k', 'v')` + `get('k')` → `'v'`
- `DEFAULT_RETRY.maxRetries === RETRY_MAX_RETRIES === 3`
- `isNetworkError({ code: 2300001, message: 'x' })` → `true`
- `PollingManager.start / stop / stopAll` 不抛错

### 边界条件
- `formatTimestamp('not-a-date')` 返回原串
- `formatTimestamp('')` 返回空串
- `parseAlarmFlag(0)` → `[]`
- `parseAlarmFlag(0xFF)` → 8 个报警名
- `parseAlarmFlag(0x100)` → `[]`（超出 8 位掩码范围）
- `buildQueryString({})` → `''`
- `buildQueryString({ k: undefined })` → `''`
- `buildQueryString({ k: '' })` → `'?k='`（空串保留）
- `buildQueryString({ 'k e y': 'v&l=1' })` → `'?k%20e%20y=v%26l%3D1'`（URI 编码）
- `CacheManager.set('k', v, 0)` 立即过期（TTL=0）
- `PollingManager.start('dup', ...)` 覆盖同名 key 不抛错
- `PollingManager.stop('never_registered')` 不存在的 key 不抛错

### 错误路径
- `isNetworkError(null)` → `false`
- `isNetworkError(undefined)` → `false`
- `isNetworkError('string')` → `false`
- `isNetworkError(42)` → `false`
- `isNetworkError({ code: '2300001' })` → `false`（code 需为数字）
- `isNetworkError({})` → `false`
- `CacheManager.get('missing')` → `null`

### 状态交互
- `CacheManager.clear()` 后所有 key 不可读
- `CacheManager.invalidate('k1')` 不影响 'k2'
- `CacheManager.get()` 过期时自动调用 `invalidate`（副作用）
- `PollingManager` 的 suspendAll → resumeAll 循环连续多次不抛错
- `PollingManager.stopAll()` 后再 `stopAll()` 不抛错

## 留待后续轮次集成测试

以下模块因依赖 HarmonyOS SDK 网络/定时器/UIAbility 上下文等原生能力，单元测试无法独立覆盖，将在后续轮次（实现对应 Service / 接入真实 API 时）通过集成测试或 e2e 测试覆盖：

- **`HttpClient`**（`get` / `post` / `getRaw` 的网络往返、重试退避、JSON 解析）
- **`api.ets`**（`request` / `requestRaw` / `uploadFile` 的原生 http/upload 生命周期）
- **`PollingManager` 实际调度**（递归 setTimeout 串行模式、回调实际调用、try-catch 包裹）
- **`EntryAbility`**（onForeground → resumeAll / onBackground → suspendAll 的 Ability 生命周期集成）

## 用例统计

- 测试套件（describe 块）：**5** 个新套件（UtilsTest / CacheManagerTest / RetryPolicyTest / ConstantsTest / PollingManagerTest）+ 1 个模板套件（localUnitTest）
- 测试用例（it 块）：**共 69 个**（UtilsTest: 21 + CacheManagerTest: 9 + RetryPolicyTest: 7 + ConstantsTest: 25 + PollingManagerTest: 7），其中 localUnitTest 模板含 1 个原有用例
- 断言（expect 调用）：**约 90+** 处 `expect(...)` 断言

按模块细分：

| 套件 | it 用例数 | describe 块数 |
|------|----------|--------------|
| UtilsTest | 21 | 7 |
| CacheManagerTest | 9 | 1 |
| RetryPolicyTest | 7 | 1 |
| ConstantsTest | 25 | 7 |
| PollingManagerTest | 7 | 1 |
| **合计** | **69** | **17** |

## 设计偏差说明

实现报告 R1 r2 中列出的 5 项偏差对本次测试编写的影响：

| 偏差 | 对测试的影响 |
|------|------------|
| 偏差 1（api.ets `header` 字段命名） | 无影响。HttpClient/api.ets 的测试留待后续轮次；本轮不涉及。 |
| 偏差 2（api.ets `UploadConfig.data` / `files[].uri` 字段） | 无影响。同上，uploadFile 测试留待后续轮次。 |
| 偏差 3（api.ets `uploadFile` 业务响应解析占位） | 无影响。已明确标注为留待后续轮次。 |
| 偏差 4（api.ets `httpRequest.request()` 的 `method` 字段） | 无影响。 |
| 偏差 5（PollingManager Map 遍历方式） | 无影响。两种实现行为等价，本轮测试仅验证不抛错、覆盖、空操作等契约。 |

**关于 constants.ets 的 API_BASE_URL 偏差**：设计规格要求 `http://<VPS_IP>:8000`，实现也保持此占位符（实现报告"下一步"项 4 已标注后续替换为生产域名）。本轮测试仅验证 `API_BASE_URL` 为非空字符串，**不**断言具体 IP。

## 硬性约束验证

- 全部测试基于行为契约编写（验证公开接口行为，不测实现细节）。
- 每个行为契约至少一个正向用例（正常路径均覆盖）。
- 覆盖维度：正常路径、边界条件、错误路径、状态交互。
- 每个被测类型对应一个测试文件。
- 用例独立：CacheManagerTest / PollingManagerTest 使用 `beforeEach` 重置状态。
- 未修改编码 agent 的任何源文件（仅新增测试文件 + 修改 `List.test.ets` 注册套件）。
