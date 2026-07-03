# R2 Code Review Report

## 结果

APPROVED

## 审查范围

实际审查了 7 个源文件：

| 文件 | 行数 | 审查结论 |
|------|------|---------|
| `harmony-app/entry/src/main/ets/services/DeviceService.ets` | 110 | PASS |
| `harmony-app/entry/src/main/ets/services/SensorService.ets` | 179 | PASS |
| `harmony-app/entry/src/main/ets/services/DiseaseService.ets` | 141 | PASS |
| `harmony-app/entry/src/main/ets/services/CommandService.ets` | 132 | PASS |
| `harmony-app/entry/src/main/ets/services/AdvisoryService.ets` | 65 | PASS |
| `harmony-app/entry/src/main/ets/services/ImageService.ets` | 87 | PASS |
| `harmony-app/entry/src/main/ets/services/PollingManager.ets` | 214 | PASS |

## 编译验证

主Agent 亲自用 tsc strict 模式（与 R1 相同的 stub 配置）验证 14 个源文件全部通过类型检查，exit code 0，无 error。

## 关键审查要点

### DeviceService.ets
- ✅ 模块级 `cachedDevices` 和 `lastFetchTime` 私有状态合理
- ✅ `getCachedDevices(deviceId?)` 支持单设备过滤（向后兼容扩展）
- ✅ `refreshDevices` 与 `getDeviceList` 等价，签名一致
- ✅ 缓存 key 命名 `CACHE_KEY_PREFIX_DEVICE_LIST + (deviceId ?? 'all')`

### SensorService.ets
- ✅ 四个方法签名与 OOD 设计文档一致
- ✅ `getLatest` 检查后端返回数组情况（防契约违反）
- ✅ `getAllLatest` 使用固定缓存 key（不依赖 deviceId）
- ✅ 缓存 key 与 TTL 与 constants.ets 一致

### DiseaseService.ets
- ✅ `getList` 不缓存（分页+筛选组合空间大）
- ✅ `getStats` 缓存 key 含 start+end
- ✅ `getHeatmap` 使用固定全局 key
- ✅ DiseaseListFilters 接口显式定义

### CommandService.ets
- ✅ 前置校验：缓存中显示离线 → 直接 throw
- ✅ 失败路径（code=1003）：先 refreshDevices 再抛错
- ✅ HTTP 层异常不主动刷新缓存（避免误判）
- ✅ send/getLogs 都不缓存

### AdvisoryService.ets
- ✅ 缓存 key 含 deviceId + windowMinutes
- ✅ 不含 start/end（与 windowMinutes 重叠）
- ✅ TTL = CACHE_TTL_ADVISORY_MS（30s）

### ImageService.ets
- ✅ 委托 `api.uploadFile()`，注入 X-Api-Key 头
- ✅ `getImagePixelMap` 调用 HttpClient.getRaw（含重试 + X-Api-Key）
- ✅ 不做解码，由调用方处理

### PollingManager.ets
- ✅ 真实递归 setTimeout 串行调度
- ✅ `tick()` 中先清 timerId 再调用 fn（避免 clearTimeout(null) 报错）
- ✅ `.finally()` 中检查存在与未 suspended 后才 scheduleNext
- ✅ `suspendAll`/`resumeAll` 正确：clearTimeout + 保留任务引用
- ✅ 公开 API 与 R1 占位完全一致（EntryAbility 调用点不变）

## 类型完整性

- ✅ 所有 Service 都有明确类型注解，无 any
- ✅ 泛型使用正确（ApiResponse<T>、PaginatedData<T>、CacheManager.get<T>）
- ✅ import 路径使用相对路径（'../common/models' 等）

## 与 OOD 设计文档一致性

- ✅ 依赖方向：`services/` → `common/`（无反向依赖）
- ✅ CommandService 依赖 DeviceService（OOD 文档 §核心抽象 #5 显式声明）
- ✅ 模块级单例（export const ObjectName = { ... }）
- ✅ HttpClient.get/post/getRaw 正确使用

## 一致性问题（已确认，无 bug）

1. DeviceService.getCachedDevices 增加了 deviceId 可选参数（OOD 文档为 `(): DeviceInfo[]`），这是向上兼容的扩展，不破坏调用方。
2. PollingManager 在 tick 错误时用 console.error 而非 hilog（PollingManager 不应依赖 @kit.PerformanceAnalysisKit，保持 common 层解耦）。
3. ImageService.uploadImage 不缓存（OOD 文档 §核心抽象 #8 未明确要求缓存）。

## 结论

R2 实现完整、类型严格、与 OOD 设计文档一致。所有 7 个源文件通过静态类型检查。

返回 APPROVED。