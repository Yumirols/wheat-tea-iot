# 测试审查报告（R2 r2）

## 审查结果
APPROVED

## 发现

### [轻微] DeviceService.test.ets — test 2 与 test 3 实质重复

`getCachedDevices_with_deviceId_on_empty_cache_returns_empty`（line 36-41）与 `getCachedDevices_returns_filtered_subarray_when_deviceId_provided`（line 43-51）均在空模块级缓存（`cachedDevices = []`）状态下传入 deviceId 并断言返回空数组。两者从被测方法到断言都完全等价。

Test 3 的名称暗示它验证了"缓存有数据时的过滤子数组"行为，但由于 `cachedDevices` 为模块私有且 HTTP 路径不可用，该测试只能验证空缓存场景。名称与实际覆盖范围不匹配。

### [轻微] DeviceService.test.ets — test 4 和 test 5 未调用任何 DeviceService 方法

`cache_key_format_includes_prefix_and_deviceId`（line 53-83）和 `cache_TTL_respects_CACHE_TTL_DEVICE_MS`（line 85-106）直接操作 `CacheManager.set/get`，未调用任何 `DeviceService` 的公开方法（`getCachedDevices`、`getDeviceList`、`refreshDevices`）。它们验证的是 `CacheManager` 读写基础能力，而非 `DeviceService` 的行为。测试名称暗示了 Service 层验证，但实际覆盖范围是基础设施层。

DeviceService 的缓存键格式正确性在被测实现中由 `cacheKey()` 函数保证，但当前测试集无法在不触发 HTTP 的情况下验证 `getDeviceList` 内部是否确实使用了该函数。

### [轻微] SensorService.test.ets — test 3 仅验证 CacheManager 而非 SensorService

`getLatest_uses_deviceId_specific_cache_key`（line 110-139）通过 `CacheManager.set(keyX, ...)` / `CacheManager.get(keyY)` 验证不同 deviceId 的缓存键隔离，未在任何路径调用 `SensorService.getLatest`。Service 的缓存键正确性由 test 1 和 test 2 隐式验证（预填缓存后调用 Service 方法，若键不匹配则缓存未命中并触发 HTTP 失败）。

### [轻微] DiseaseService.test.ets — test 2 仅验证 CacheManager 而非 DiseaseService

`getStats_uses_differentiated_keys_for_time_ranges`（line 46-74）直接操作 `CacheManager.set/get` 验证不同时间范围使用不同的缓存键。没有在任何路径调用 `DiseaseService.getStats`。Service 的缓存键隔离已由 test 6 和 test 7 通过实际 Service 调用完成验证。

### [轻微] AdvisoryService.test.ets — test 2 仅验证 CacheManager 而非 AdvisoryService

`cache_key_format_for_specific_deviceId_and_window`（line 66-88）直接操作 `CacheManager.set/get` 验证键格式。没有调用 `AdvisoryService.getAdvisory`。Service 的键构造已由 test 1 和 test 3 通过实际 Service 调用完成验证。

### [轻微] 可测试的边界场景缺失两处

在当前"无后端 ArkTS 测试环境"约束下，以下两个边界场景可通过预先填充 `CacheManager` 并调用 Service 方法验证缓存命中路径，属于可实施的遗漏：

1. **`SensorService.getLatest('')` 空字符串 deviceId 边缘情况**：设计规格明确指出 `getLatest(deviceId: string)` 强制 deviceId，空字符串视作"无设备过滤"，后端将返回数组形态（Service 会抛 `Error('Expected single sensor snapshot')`）。但缓存命中路径仍可测试：预先填充 `CACHE_KEY_PREFIX_SENSOR_LATEST`（空字符串拼接后即原始前缀）键，调用 `SensorService.getLatest('')`，应返回缓存值。

2. **`AdvisoryService.getAdvisory` 携带 `windowMinutes` 参数的 Service 调用测试**：当前 test 1 和 test 3 均以无参形式（命中 `all_all` 键）调用 Service。可增加：预先填充键 `CACHE_KEY_PREFIX_ADVISORY + 'dev_001_60'`，调用 `AdvisoryService.getAdvisory('dev_001', undefined, undefined, 60)`，验证缓存命中。

以上两项不涉及 HTTP 调用，在当前测试框架下可正常通过了（预填 CacheManager 后 Service 方法直接返回缓存值，不触发远程请求）。

## 修改要求（无）

无严重或一般级别问题，无需修改。
