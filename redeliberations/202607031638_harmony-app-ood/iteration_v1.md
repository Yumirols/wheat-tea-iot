# 再审议判定报告（v1）

## 判定结果

RETRY

## 判定理由

基于组件B诊断报告（`b_v1_diag_v6.md`）和质询报告（`b_v1_challenge_v6.md`）的分析：

诊断报告共识别 **10 项高严重度问题（H1–H11）** 和 **4 项中严重度问题（M1–M5）**，质询报告判定为 `LOCATED`，确认所有问题定位准确、证据充分、逻辑完整。

根据再审议判定标准，审查报告包含严重及一般等级问题，不满足 PASS 条件，应重新运行组件A进行修复。

## 需要解决的问题（RETRY）

### H1. `ImageViewer` 图片展示路径：需补充 `image_path` 语义分析
- **位置**：`a_v1_design_v3.md` §15 `ImageViewer`（第 273–280 行）
- **严重程度**：严重
- **改进建议**：明确 `DiseaseRecord.image_path` 字段语义（URL vs image_id），据此确定图片展示路径

### H2. `ChartView` 在 ArkUI 中缺少原生图表组件
- **位置**：`a_v1_design_v3.md` §12 `ChartView`（第 237–245 行）
- **严重程度**：严重
- **改进建议**：v1.0 实现单 Y 轴折线图最小可用版本（2–4 人日），预留 `ChartRendererAPI` 接口

### H3. `ImageService` 的 `multipart/form-data` 上传路径缺少 ArkTS 实现指引
- **位置**：`a_v1_design_v3.md` §8 `ImageService`（第 189 行）
- **严重程度**：严重
- **改进建议**：在 `common/api.ets` 中新增 `buildFormData()` 辅助函数和 `requestMultipart()` 方法

### H4. `api.ets` 的 `NetworkResult.rawBody: string` 无法承载二进制响应
- **位置**：`a_v1_design_v3.md` 核心接口表 `NetworkResult`（第 301 行）
- **严重程度**：严重
- **改进建议**：新增 `requestRaw()` 方法，将 `NetworkResult` 拆分为 `TextResult` / `BinaryResult` 联合类型

### H5. 所有页面 `aboutToAppear` 中编排异步加载 + `pushUrl` 场景下轮询停止契约不可执行
- **位置**：`a_v1_design_v3.md` 场景 A/B/C/D/E（第 309–369 行）
- **严重程度**：严重
- **改进建议**：补充 `@State isLoading/errorMessage`、非 async 触发模式、错误处理契约；修正 `pushUrl` 下轮询管理策略

### H6. `DeviceSelector` 设备切换的级联数据刷新路径未定义
- **位置**：`a_v1_design_v3.md` 模块目录 `components/DeviceSelector.ets`（第 37 行）
- **严重程度**：严重
- **改进建议**：补充 `onDeviceChange` 回调契约、级联刷新行为场景、跨页面 device_id 传递机制

### H8. 乐观 UI 回滚未覆盖设备状态漂移场景
- **位置**：`a_v1_design_v3.md` 决策 7（第 483–490 行）
- **严重程度**：严重
- **改进建议**：补充操作前状态保存（`previousState`）、回滚后缓存更新、差异化 toast 提示

### H9. IndexPage 首页缺少传感器数据实时刷新轮询
- **位置**：`a_v1_design_v3.md` 场景 A（第 312–317 行）
- **严重程度**：严重
- **改进建议**：注册 `index_sensor` 轮询 key，每 10s 刷新 SensorCard 数据

### H10. 农业 IoT 场景弱网韧性完全未覆盖
- **位置**：`a_v1_design_v3.md` 错误处理策略（第 373–393 行）
- **严重程度**：严重
- **改进建议**：新增 `RetryPolicy`、`CacheManager`、离线 UI 表现；轮询重试采用串行/跳略模式治理竞争

### H11. 现有 `common/api.ets` 与两层 HTTP 架构的兼容性未评估
- **位置**：`a_v1_design_v3.md` §1 架构描述（第 9–13 行）
- **严重程度**：严重
- **改进建议**：审查现有 `api.ets` 实际实现，评估职责重叠、依赖方向合规性、迁移成本

### M1. 轮询告警状态 → UI 渲染的传播路径未定义
- **位置**：`a_v1_design_v3.md` 场景 A（第 316–317 行）
- **严重程度**：一般
- **改进建议**：定义 `PollingCallback` 类型签名，补充轮询回调 → `@State` → `build()` 完整链路

### M2. `SensorService` 核心抽象中遗漏 `getDaily()` 方法
- **位置**：`a_v1_design_v3.md` §3 `SensorService`（第 131–140 行）
- **严重程度**：一般
- **改进建议**：补充 `getDaily(deviceId, start, end, page?, pageSize?)` 方法签名

### M3. `CommandService` 与 `DeviceService` 的在线状态依赖缺少缓存层定义
- **位置**：`a_v1_design_v3.md` §5 `CommandService`（第 158–160 行）
- **严重程度**：一般
- **改进建议**：在 `DeviceService` 中定义模块级缓存、`getCachedDevices()` / `refreshDevices()` 方法

### M5. 弱网场景请求重试机制缺失
- **位置**：`a_v1_design_v3.md` 错误处理策略（第 373–393 行）
- **严重程度**：一般
- **改进建议**：在 `HttpClient` 中实现指数退避重试，非幂等请求不做重试
