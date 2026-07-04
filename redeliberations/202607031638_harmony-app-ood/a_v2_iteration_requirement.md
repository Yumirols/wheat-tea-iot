# 第二轮迭代要求 — 农眼卫士 FarmEye Guard v1.0 OOD 设计修订

## 概述

基于上一轮组件B诊断报告（b_v1_diag_v6.md）的审查结论——经质询（b_v1_challenge_v6.md）确认 **LOCATED**，要求在现有设计方案 v3 基础上，对 10 项高严重度问题、4 项中严重度问题、3 项低严重度问题进行系统性修复。设计文档版本号推进至 v4。

## 必须修复的问题

### 高严重度

| 编号 | 问题 | 类型 | 核心修复要求 |
|------|------|------|-------------|
| H1 | `ImageViewer` 图片展示路径未明确 `image_path` 语义 | 语义未定 | 明确设计文档的假设（URL 路径 vs image_id 路径），分别给出两种假设下的组件实现方式和架构影响 |
| H2 | `ChartView` 缺少原生图表组件，Canvas 实现复杂度未评估 | 框架缺口 | 按最小可用原则重新设计：v1.0 仅单 Y 轴折线图，定义 `ChartRendererAPI` 接口，预留折线/柱状切换 |
| H3 | `ImageService` multipart/form-data 上传路径在错误层次 | 架构矛盾 | 修正为 `common/api.ets` 新增 `buildFormData()` + `requestMultipart()`，`HttpClient.post()` 新增 multipart 可选参数 |
| H4 | `api.ets` 缺少二进制响应路径 | 架构遗漏 | `api.ets` 新增 `requestRaw()`（`expectDataType: ARRAY_BUFFER`），`NetworkResult` 拆分为 `TextResult` / `BinaryResult` 联合类型 |
| H5 | `aboutToAppear` 同步约束 + `pushUrl` 不触发 `aboutToDisappear` | 架构矛盾 | 页面新增 `@State isLoading/errorMessage`；`aboutToAppear` 通过非 async 方式触发 `loadData()`；修正 `pushUrl` 下轮询不停止策略；`EntryAbility.onBackground()` 统一暂停 |
| H6 | 设备切换级联刷新路径未定义 | 架构遗漏 | `DeviceSelector` 补充 `@Link selectedDeviceId` + `onDeviceChange` 回调；定义级联刷新行为场景和跨页面 device_id 传递 |
| H8 | 乐观 UI 回滚未覆盖设备状态漂移 | 交互遗漏 | 操作前保存 `@State previousState`；回滚路径补充缓存更新和差异化 toast；`CommandService` 失败路径补充缓存失效信号 |
| H9 | IndexPage 首页缺少传感器数据轮询 | 体验缺口 | 注册 `index_sensor` 轮询 key，每 10s `SensorService.getLatest()` 刷新 SensorCard |
| H10 | 弱网韧性完全未覆盖 | 架构遗漏 | 新增 `RetryPolicy`、`CacheManager`、离线 UI 表现（`@State connectivityStatus`）；轮询重试采用串行（setTimeout）或跳略模式治理与 setInterval 的竞争 |
| H11 | 现有 `common/api.ets` 与两层 HTTP 架构兼容性未评估 | 覆盖遗漏 | 评估职责重叠、依赖方向合规性、迁移成本；在设计中明确现有 api.ets 的实际角色和迁移策略 |

### 中严重度

| 编号 | 问题 | 核心修复要求 |
|------|------|-------------|
| M1 | 轮询告警转 UI 传播路径未定义 | 定义 `PollingCallback` 类型签名，补充轮询回调 → `@State` → `build()` 完整链路 |
| M2 | `SensorService` 遗漏 `getDaily()` 方法签名 | 补充 `getDaily(deviceId, start, end, page?, pageSize?)` |
| M3 | `CommandService` 与 `DeviceService` 缺少缓存层定义 | `DeviceService` 中定义模块级缓存、`getCachedDevices()` / `refreshDevices()` |
| M5 | 弱网请求重试机制缺失 | `HttpClient` 实现指数退避重试，非幂等请求不做重试（注意与 H10 的 RetryPolicy 定义整合） |

### 低严重度

| 编号 | 问题 | 核心修复要求 |
|------|------|-------------|
| L1 | `constants.ets` 命令枚举未显式定义 | 补充命令枚举或类型定义 |
| L2 | 循环渲染 `ForEach` 未引用 | 在页面组件描述中补充 `ForEach` 示例 |
| L3 | 弱网本地缓存策略 | `SensorService` 实现轻量级内存缓存，失败时返回最后一次成功数据 |

## 质询补充项（非驳回，纳入修复范围）

来自质询报告（b_v1_challenge_v6.md）的补充发现：

1. **DiseaseService 方法签名一致性**：`getStats()` / `getHeatmap()` 在核心抽象中同样缺少显式方法签名（与 M2 相同模式），须补充
2. **H10/M5 内容重叠**：H10 改进建议中包含 RetryPolicy 定义，M5 也涉及重试机制。须消除组织性重叠，RetryPolicy 统一归属于 H10 的完整弱网韧性方案，M5 作为 H10 的子引用

## 关键约束

1. 设计必须保持在 ArkTS + ArkUI API 21 框架约束内可行
2. 三层依赖方向（pages → services → common）和组件间依赖方向不得违反
3. 行为契约场景 A/B/C/D/E 须全面修订，同步反映所有修复
4. 轮询调度约束表须同步更新，补充 `index_sensor` 轮询条目
5. 核心接口表（`common/models.ets`）须同步更新 `NetworkResult` 拆分

## 输出

修订后的设计文档 v4 写入 `{workdir}/a_v2_design_v4.md`
