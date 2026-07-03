# 测试报告（R2）

## 概述

对 R2 实现的 6 个业务 Service 和 PollingManager 编写/审查单元测试。覆盖缓存命中路径（依赖 CacheManager 预填充）、缓存键构造规则、前置校验放行路径、错误不中断轮询等核心行为契约。

## 审查结论

覆盖充分，补充了 10 个额外测试用例以填补关键缺口。

## 测试文件清单

| 操作 | 文件路径 | 覆盖的行为契约 |
|------|---------|---------------|
| 审查+补充 | `harmony-app/entry/src/test/PollingManager.test.ets` | PollingManager 生命周期：start 不立即执行 / 串行模式 / 错误不中断 / stop 清理 / stopAll 清空 / suspendAll 暂停 + 保留 / resumeAll 恢复 / 同 key 覆盖旧任务 / resumeAll 不重启非 suspended 任务 / **新增: 空 tasks suspendAll 安全** / **新增: 空 tasks resumeAll 安全** / **新增: suspendAll+stopAll 彻底清理** |
| 审查+补充 | `harmony-app/entry/src/test/DeviceService.test.ets` | getCachedDevices 未初始化返回 [] / 设备过滤返回 [] / 缓存键格式验证（CacheManager 预填充）/ TTL 验证 |
| 审查+补充 | `harmony-app/entry/src/test/SensorService.test.ets` | getLatest 缓存命中 / getAllLatest 缓存命中 / 缓存键隔离 / **新增: getHistory 无缓存直通 HTTP** / **新增: getDaily 无缓存直通 HTTP** |
| 审查+补充 | `harmony-app/entry/src/test/DiseaseService.test.ets` | getStats 缓存命中 / getStats 时间范围键隔离 / all_all 键 / getHeatmap 固定全局键命中 / **新增: getStats partial start 键** / **新增: getStats partial end 键** / **新增: getHeatmap 不同参数同键** / **新增修订: getList 直通 HTTP** / **重写: all_all 键测试为真实 Service 调用** |
| 审查+补充 | `harmony-app/entry/src/test/CommandService.test.ets` | send 缓存未命中时放行 HTTP（不抛 Device offline）/ getLogs 直通 HTTP / **新增: getLogs 多参数直通 HTTP 且非 Device offline 错误** |
| 审查+补充 | `harmony-app/entry/src/test/AdvisoryService.test.ets` | getAdvisory 缓存命中 / 缓存键构造规则（deviceId+windowMinutes）/ all_all 键 / **新增: cache miss 直通 HTTP** |
| 新建 | `harmony-app/entry/src/test/Services.test.ets` | R2 测试套件入口，注册全部 6 个 Service 测试 + PollingManager 测试 |
| 不变 | `harmony-app/entry/src/test/List.test.ets` | hvigor 测试构建入口（注册 LocalUnit.test.ets，保持不变） |

## 用例统计

| 套件 | it 用例数 | 新增 | 覆盖维度的关键补充 |
|------|----------|------|-------------------|
| PollingManagerTest | 13 | +3 | 空 tasks 安全操作、suspendAll→stopAll 清理链 |
| DeviceServiceTest | 5 | 0 | 模块级缓存的同步读约束已充分覆盖 |
| SensorServiceTest | 5 | +2 | getHistory / getDaily 无缓存直通 HTTP |
| DiseaseServiceTest | 8 | +4 | getStats partial 参数缓存键、getHeatmap 全局键验证、getList HTTP 直通、all_all Service 调用重写 |
| CommandServiceTest | 3 | +1 | getLogs 多参数直通 HTTP；删除缓存键格式测试（测的是 CacheManager 而非 CommandService） |
| AdvisoryServiceTest | 4 | +1 | cache miss 直通 HTTP |
| **合计** | **38** | **+10** | |

## 覆盖维度

### 正常路径（缓存命中）
- SensorService.getLatest 缓存命中直接返回 ✓
- SensorService.getAllLatest 缓存命中直接返回 ✓
- DiseaseService.getStats 缓存命中直接返回 ✓
- DiseaseService.getHeatmap 缓存命中直接返回 ✓
- AdvisoryService.getAdvisory 缓存命中直接返回 ✓
- DiseaseService.getStats partial start/end 缓存键命中 ✓（新增）
- DiseaseService.getHeatmap 不同参数同一全局键命中 ✓（新增）

### 边界条件
- DeviceService.getCachedDevices 未初始化返回 [] ✓
- PollingManager.stop 不存在 key 安全 ✓
- PollingManager.suspendAll 空 tasks 安全 ✓（新增）
- PollingManager.resumeAll 空 tasks 安全 ✓（新增）
- AdvisoryService all_all 键（无参数）✓

### 错误路径（无后端 HTTP 失败）
- SensorService.getHistory 直通 HTTP 抛错 ✓（新增）
- SensorService.getDaily 直通 HTTP 抛错 ✓（新增）
- DiseaseService.getList 直通 HTTP 抛错 ✓（newly added）
- CommandService.send 缓存未命中放行 HTTP ✓
- CommandService.getLogs 直通 HTTP ✓
- CommandService.getLogs 多参数直通 HTTP 且非 Device offline ✓（新增）
- AdvisoryService.getAdvisory cache miss 直通 HTTP ✓（新增）

### 状态交互
- PollingManager suspend 后 fn 不被调用 ✓
- PollingManager resumeAll 恢复暂停任务 ✓
- PollingManager resumeAll 不重启非 suspended 任务 ✓
- PollingManager 同 key 覆盖旧任务 ✓
- PollingManager suspendAll→stopAll 彻底清理 ✓（新增）

## 设计偏差说明

实现报告中的偏差对测试无实质影响：

| 偏差 | 对测试的影响 |
|------|------------|
| R1 源文件需在工作树中重新创建 | R2 源文件为本轮新建/改造，测试覆盖的是当前 `impl/temp-R2` 的实现 |
| DiseaseService.getList 导出 DiseaseListFilters 接口 | 测试中 filter 参数通过对象字面量传入，无影响 |
| CommandService.send body 显式条件赋值 | 不影响公开行为契约，测试验证的是"正确的错误抛出不涉及 Device offline" |
| PollingManager.tick 使用 console.error | 记录不中断轮询的行为已在 `tick_error_does_not_interrupt_polling` 中验证 |

## 未覆盖范围说明

| 范围 | 原因 | 后续轮次 |
|------|------|---------|
| **HTTP 请求路径**（getDeviceList / refreshDevices / send 等 POST 路径） | 依赖真实后端或 ArkTS mock 框架（hamock） | 集成测试轮次 |
| **CommandService.send 前置校验**（设备离线阻断） | 需修改 DeviceService 模块级 `cachedDevices`，模块私有无法从外部写入 | 集成测试轮次（配合 hamock 的 mockPrivateFunc） |
| **ImageService** | 强依赖 `@kit.AbilityKit` 的 `UIAbilityContext` 与 `api.uploadFile` 实际网络栈，无法单元测试 | R3+ 组件层或集成测试 |
| **HttpClient / api.ets** | R1 已标注留待后续轮次 | 集成测试轮次 |

## 编译验证

将全部 `.ets` 文件转换为 `.ts` 后，使用 TypeScript strict 模式（`strict: true`、`noImplicitAny: true`、`strictNullChecks: true`）运行 `tsc --noEmit`：

```
命令: tsc --noEmit -p tsconfig.json
结果: exit 0，0 errors
```

验证的 stub 模块声明：
- `@ohos/hypium`（describe / it / expect / beforeEach / afterEach）
- `@kit.NetworkKit`（http）
- `@kit.RequestKit`（request）
- `@kit.AbilityKit`（common.UIAbilityContext）
- `@kit.PerformanceAnalysisKit`（hilog）
- `@kit.ArkUI`（window）
- `@kit.BasicServicesKit`（BusinessError）

## 留待后续轮次集成测试

与 R1 一致的集成测试缺口：

- **HttpClient**（get / post / getRaw 的网络往返、重试退避、JSON 解析）
- **api.ets**（request / requestRaw / uploadFile 的原生 HTTP/upload 生命周期）
- **CommandService.send 前置校验**（device offline 阻断路径，需 MockKit.mockPrivateFunc）
- **DeviceService.getDeviceList**（HTTP 成功→模块级缓存更新的完整链路）
- **ImageService**（UIAbilityContext 注入 + uploadFile 集成）
- **PollingManager 真实 setTimeout**（串行模式在实际定时器环境下的抖动容忍度）

## 修订说明（R2 r1）
| 审查意见 | 修改措施 |
|---------|---------|
| DiseaseService.test.ets 缺少 getList 测试 | 新增 `getList_passes_through_to_http_without_cache` 用例，验证无缓存直通 HTTP 抛错 |
| `getStats_all_undefined_uses_all_all_key` 未测试 Service 行为 | 重写该用例：改用 `CacheManager.set()` 预填充缓存后调用 `await DiseaseService.getStats()`（不传参），验证返回预填充数据——真正测试 key 构造行为 |
| `cache_key_for_device_list_stores_separately_per_device` 测试了 CacheManager 而非 CommandService | 从 CommandService.test.ets 中删除该用例（DeviceService.test.ets 已有 `cache_key_format_includes_prefix_and_deviceId` 覆盖相同 key 格式验证） |
