# 农眼卫士 FarmEye Guard v1.0 — OOD 设计方案可落地性审查报告（v2 第1轮）

## 审查概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `a_v2_design_v4.md` — 鸿蒙移动应用 OOD 设计方案（v4，迭代修订版） |
| 对应需求 | `requirement.md` + `a_v2_iteration_requirement.md` |
| 审查视角 | OOD 设计可落地性：第1轮问题修复验证 + 新设计方案完整性 |
| 审查方法 | 逐项对照迭代需求中的17项问题（10H+4M+3L）及2项质询补充，检查修复状态 |
| 前置审查 | `a_v2_review_v1.md` — 类型系统/标准库/设计一致性审查，结论 APPROVED |

---

## 整体评价

v4 设计对第1轮审查的17项问题及2项质询补充实现了**全覆盖修复**，修复方案准确、完整，无遗漏。新增的弱网韧性基础设施（RetryPolicy、CacheManager、ConnectivityIndicator、串行轮询）填补了 v3 的核心架构缺口，6个行为场景（A~F）形成完整交互闭环，模块职责清晰、依赖方向合规。

但在可落地性细节层面仍存在 **2 项中严重度** 和 **4 项低严重度** 未覆盖缺口，以及第1轮审查中已识别、迭代需求未要求修复但可能影响编码质量的 **6 项持续存在项**。

---

## 第1轮审查问题修复验证

### 高严重度（10 项）

| 编号 | 问题 | 修复措施 | 修复状态 | 验证说明 |
|------|------|---------|---------|---------|
| H1 | `ImageViewer` 图片展示路径未明确 `image_path` 语义 | 核心抽象 §18 明确采纳 URL 路径假设（`<Image src={baseURL + image_path}>`），标注备用路径（image_id → PixelMap） | ✅ **完整修复** | 基于 API 文档 `image_path` 为相对 URL 格式做了明确假设，场景 C 同步修正；备用路径已标注且不影响 v1.0 核心功能 |
| H2 | `ChartView` 缺少原生图表组件，Canvas 实现复杂度未评估 | 新增 `ChartRendererAPI` 接口（§15）+ `LineChartRenderer`（v1.0 最小可用：单 Y 轴单折线，无触摸）+ `BarChartRenderer`（架构预留）；`ChartView` 通过 `@Prop chartType` 切换渲染器 | ✅ **完整修复** | 按最小可用原则定义 v1.0 范围，接口解耦策略模式合理 |
| H3 | `ImageService` multipart/form-data 上传路径在错误层次 | 修正为 `common/api.ets` 新增 `buildFormData()` + `requestMultipart()`；`HttpClient.post()` 新增 `multipart?` 可选参数 | ✅ **完整修复** | 三层依赖方向合规（`api.ets` 在 common 层，`HttpClient` 在 services 层调用 common 层） |
| H4 | `api.ets` 缺少二进制响应路径 | `api.ets` 新增 `requestRaw()`；`NetworkResult` 拆分为 `TextResult` / `BinaryResult` 联合类型；`HttpClient` 新增 `getRaw()` | ✅ **完整修复** | 类型拆分合理，两条路径清晰分离 |
| H5 | `aboutToAppear` 同步约束 + `pushUrl` 不触发 `aboutToDisappear` | 页面新增 `@State isLoading/errorMessage/connectivityStatus`；`aboutToAppear` 非 async 触发 `loadData()`；场景 E 修正为 `pushUrl` 不停止轮询；`EntryAbility.onBackground()` 统一暂停 | ✅ **完整修复** | 初始加载状态、错误处理、轮询生命周期三者均已覆盖 |
| H6 | 设备切换级联刷新路径未定义 | `DeviceSelector` 补充 `@Link selectedDeviceId` + `onDeviceChange` 回调；新增场景 F 完整契约；跨页面 device_id 传递策略 | ✅ **完整修复** | 级联刷新场景覆盖了所有依赖 device_id 的 Service |
| H8 | 乐观 UI 回滚未覆盖设备状态漂移 | `ControlButton` 补充 `@State previousState`；场景 B 补充 `code=1003` 回滚链；`CommandService` 失败路径缓存失效信号 | ✅ **完整修复** | 回滚 + 缓存更新 + 差异化 toast 三层覆盖 |
| H9 | IndexPage 首页缺少传感器数据轮询 | 场景 A 补充 `PollingManager.start('index_sensor', 10000)`；轮询调度表新增 `index_sensor` 条目 | ✅ **完整修复** | 首页传感器数据实现 10s 实时刷新 |
| H10 | 弱网韧性完全未覆盖 | 新增 `RetryPolicy` + `CacheManager` + `connectivityStatus` + `ConnectivityIndicator`；`PollingManager` 串行模式；`HttpClient` 指数退避重试 | ✅ **完整修复** | 四维弱网韧性方案（重试、缓存、离线 UI、轮询交互治理）形成完整体系 |
| H11 | 现有 `common/api.ets` 与两层 HTTP 架构兼容性未评估 | 职责分工表清晰划分 api.ets/HttpClient 边界；增量剥离迁移策略声明 | ✅ **完整修复** | 设计假设明确，迁移路径定义清晰 |

### 中严重度（4 项）

| 编号 | 问题 | 修复措施 | 修复状态 | 验证说明 |
|------|------|---------|---------|---------|
| M1 | 轮询告警转 UI 传播路径未定义 | 定义 `PollingCallback` 类型；场景 A 补充完整传播链路；`PollingManager` 每个 tick try-catch 包裹 | ✅ **完整修复** | 回调 → `@State` → `build()` → `AlarmBanner` 链路完整 |
| M2 | `SensorService` 遗漏 `getDaily()` 方法签名 | 核心抽象 §3 补充 `getDaily(deviceId, start, end, page?, pageSize?)` | ✅ **完整修复** | 方法签名添加 |
| M3 | `CommandService` 与 `DeviceService` 缺少缓存层定义 | `DeviceService` 模块级缓存定义 + `getCachedDevices()` / `refreshDevices()`；`CommandService.send()` 预检 + 失败路径缓存更新 | ✅ **完整修复** | 缓存层闭环完整 |
| M5 | 弱网请求重试机制缺失 | 与 H10 整合：`HttpClient` 指数退避重试；`RetryPolicy` 统一归属于 H10 | ✅ **完整修复** | 内容重叠已消除，M5 作为 H10 子引用 |

### 低严重度（3 项）

| 编号 | 问题 | 修复措施 | 修复状态 |
|------|------|---------|---------|
| L1 | `constants.ets` 命令枚举未显式定义 | 补充 `Command` 联合类型定义 | ✅ **完整修复** |
| L2 | 循环渲染 `ForEach` 未引用 | 场景 C 补充 `ForEach` 显式标注 | ✅ **完整修复** |
| L3 | 弱网本地缓存策略 | 与 H10 整合：`SensorService` 内存缓存（CacheManager），失败返回最后一次成功数据 | ✅ **完整修复** |

### 质询补充项（2 项）

| 编号 | 问题 | 修复措施 | 修复状态 |
|------|------|---------|---------|
| QC1 | `DiseaseService.getStats()` / `getHeatmap()` 同样缺少显式方法签名 | 核心抽象 §4 补充方法描述；设计决策 §12 记录一致性原则 | ✅ **完整修复** |
| QC2 | H10/M5 内容重叠 | RetryPolicy 统一归属于 H10，M5 作为子引用 | ✅ **完整修复** |

---

## 新发现的可落地性缺口

### 中严重度

#### N1. `ControlButton` 乐观 UI 的状态管理机制未闭合（中）

**位置**：核心抽象 §16 `ControlButton`（第307–318行）

**问题描述**：
`ControlButton` 职责描述："接收当前状态（on/off）作为属性"+"操作前保存当前状态到 `@State private previousState`"。但在 ArkUI 中：
- `@Prop` 为**只读**，子组件不能直接修改其值
- 乐观 UI 要求"点击后立即切换为目标状态"——如果状态通过 `@Prop` 传入，子组件无法翻转显示状态
- `@State previousState` 保存后，乐观 UI 翻转的**目标状态值**没有对应的可写变量承载

若 `ControlButton` 使用 `@Prop` 接收 `isOn`，则乐观 UI 执行后父组件 `ControlPage` 的 `@State` 未被更新；若父组件因任何原因触发重渲染，`ControlButton` 会收到原始的 `isOn` 值，乐观 UI 效果消失。

**严重程度**：中 — 核心控制交互的核心组件状态管理未闭合，实现者需自行推演

**改进建议**：
- 方案 A：`ControlButton` 改用 `@Link` 接收 `isOn`（而非 `@Prop`），乐观 UI 直接通过 `this.isOn = targetState` 修改父组件状态，ArkUI 数据流自动响应
- 方案 B：维持 `@Prop`，但 `ControlButton` 维护独立的 `@State displayOn` 内部状态来覆盖显示的开关值，父组件通过异步结果（成功/失败）驱动下一次 `@Prop` 更新
- 方案 C（推荐 v1.0 最小改动）：`ControlButton` 内维护 `@State displayOn: boolean`（初始化为 `@Prop isOn`），乐观 UI 时修改 `displayOn`，回滚时恢复为 `previousState`；成功时等待父组件 `@Prop` 更新 `isOn` 后在 `aboutToUpdate` 中同步 `displayOn`

**建议在核心抽象 §16 中明确选择一种方案并补充 `@Prop` vs `@Link` vs `@State displayOn` 的决策。**

#### N2. `connectivityStatus` 状态更新机制未定义（中）

**位置**：核心抽象 §12 页面组件（第256行）、错误处理策略弱网韧性表（第510行）

**问题描述**：
每个页面声明了 `@State private connectivityStatus: 'loading' | 'online' | 'offline'`，且弱网策略和条件渲染中均引用此状态。但**完整的状态转换闭环未定义**：

| 问题 | 描述 |
|------|------|
| 触发时机 | `connectivityStatus` 何时从 `'loading'` → `'online'`？首次 `loadData()` 成功时？ |
| 离线判定 | 谁负责将其切换为 `'offline'`？是 `HttpClient` 重试耗尽后的回调？各 Service 的 catch？页面层的统一错误拦截？ |
| 恢复机制 | 离线状态下如何恢复为 `'online'`？下一个轮询 tick 成功时自动恢复？需要单独的心跳探测？ |
| 跨页面一致性 | 若 `HttpClient` 层检测到全局网络断开，所有页面应共享同一连接状态，但当前每个页面的 `connectivityStatus` 是独立的 `@State` |

**严重程度**：中 — 状态变量的完整生命周期未定义，实现者可能各页面实现不一致

**改进建议**：
- 在 `HttpClient` 或 `api.ets` 层增加模块级 `connectivityStatus` 信号（如模块级 `let globalConnectivity: 'loading' | 'online' | 'offline' = 'loading'`），作为统一的连接状态源
- 页面通过每次 Service 调用返回时判断：成功 → `'online'`，网络异常且重试耗尽 → `'offline'`，正在请求中 → `'loading'`
- 在错误处理策略中补充 `connectivityStatus` 的转换矩阵

---

### 低严重度

#### N3. `AlarmBanner` 缺少核心抽象定义（低）

**位置**：模块目录 `components/AlarmBanner.ets`（第39行）、场景 A（第399行）

**问题描述**：
场景 A 中 `AlarmBanner` 出现在完整行为链路中（`@State alarmMessage/alarmSeverity → build() → AlarmBanner`），但核心抽象部分没有为 `AlarmBanner` 提供与其他组件（如 `SensorCard`、`ControlButton`）同等的独立章节描述。其接收的 `@Prop` 类型、告警展示逻辑、交互行为（点击跳转？可关闭？）均未定义。

**改进建议**：在核心抽象中补充 `AlarmBanner` 的职责描述和接口定义（`@Prop message: string`、`@Prop severity: 'mild' | 'moderate' | 'severe'`）。

#### N4. `PollingManager` 串行模式的定时漂移行为未标注（低）

**位置**：核心抽象 §9 `PollingManager`（第220–228行）

**问题描述**：
`PollingManager` 使用递归 `setTimeout` 串行模式——上一个 tick（含重试）完全结束后再调度下一个周期。若单 tick 因重试耗时 >10s，实际轮询频率会低于配置间隔。这是串行模式的固有背压特性，但设计未在任何位置注明此行为预期，实现者可能误以为轮询严格按 10s 准时执行。

**改进建议**：在 `PollingManager` 职责描述中补充行为说明："串行模式下若单 tick 执行时间超过配置间隔，下一个 tick 将立即执行（`setTimeout(0)`）而非跳过，实际频率不低于 1/(tick_duration + interval)？需明确策略：超时后是立即执行下一个、还是等待完整间隔？"

#### N5. 页面核心抽象中 `@State alarmMessage/alarmSeverity` 缺失声明（低）

**位置**：核心抽象 §12 页面组件（第256行）、场景 A（第399行）

**问题描述**：
场景 A 引用了 `@State alarmMessage / alarmSeverity`，但在 §12 页面组件声明的 `@State` 列表中仅有 `isLoading` / `errorMessage` / `connectivityStatus`，未包含这两个变量。M1 的改进建议要求补充，但修复只体现在场景 A 的行为描述中，核心抽象层未同步更新。

**改进建议**：在核心抽象 §12 的页面 `@State` 列表中补充 `alarmMessage` 和 `alarmSeverity` 声明，使其与场景 A 的行为描述一致。

#### N6. `catch((err: Error)` 不符 ArkTS 约定（低）

**位置**：核心抽象 §12 `aboutToAppear` 代码片段（第262行）

**问题描述**：
代码片段使用 `catch((err: Error) => {...})`。需求 §6.7 和参考项目约定使用 `catch((err: BusinessError) => {...})`。ArkTS 中 `BusinessError` 继承自 `Error` 且包含额外的 `code` 属性，对于超时、网络错误的原生异常具体类型判断有帮助。

**改进建议**：将 `catch((err: Error)` 统一替换为 `catch((err: BusinessError)`，与参考项目约定一致。

---

## 第1轮审查已识别但本轮迭代未要求修复的持续存在项

以下为 `a_v2_review_v1.md`（审查报告）中识别的轻微项，迭代需求未要求修复，但持续存在于 v4 设计中，可能影响编码质量：

| 编号 | 问题来源 | 问题描述 | 当前状态 | 编码影响 |
|------|---------|---------|---------|---------|
| S1 | 审查§1轻微 | `CacheManager` 缓存键空间共享，多 Service 可能键名冲突 | ⚠️ 持续存在 | 低 — 编码时约定前缀即可 |
| S2 | 审查§3轻微 | `PollingManager` 串行模式定时漂移未标注（同 N4） | ⚠️ 持续存在 | 低 — 行为预期需告知实现者 |
| S3 | 审查§4轻微 | `DiseaseRecord` 模型缺少 `linkage_detail` 字段 | ⚠️ 持续存在 | 低 — 按需补充即可 |
| S4 | 审查§4轻微 | `SensorService.getLatest()` 未注明 `deviceId` 可选行为 | ⚠️ 持续存在 | 低 — `deviceId` 为空时行为需约定 |
| S5 | 审查§5轻微 | `PollingCallback` 类型未显式导出为独立类型定义 | ⚠️ 持续存在 | 低 — 隐式约束足够，显式更好 |
| S6 | 审查§5轻微 | `CommandService` 硬引用 `DeviceService.refreshDevices()` 为 ad-hoc 耦合 | ⚠️ 持续存在 | 低 — v1.0 规模可接受 |

上述 6 项均为低严重度，不影响整体可落地性判定，但建议编码前在 `AGENTS.md` 或 `TODO` 中登记，避免实现阶段遗漏。

---

## 可落地性综合评价

| 维度 | 评级 | 说明 |
|------|------|------|
| 第1轮问题修复完整性 | ✅ **全部修复** | 17项问题 + 2项质询补充全覆盖，无遗漏 |
| 修复方案正确性 | ✅ **正确** | 所有修复均在 ArkTS/ArkUI 框架约束内，依赖方向合规 |
| 新增设计完整性 | ✅ **完整** | RetryPolicy、CacheManager、ConnectivityIndicator、串行轮询、场景F设备级联 — 填补了全部架构缺口 |
| 组件状态管理闭合度 | ⚠️ **可落地** | N1（ControlButton @Prop vs @Link）和 N2（connectivityStatus 更新机制）需在编码阶段前闭合 |
| 编码阶段可操作性 | ⚠️ **基本可落地** | 核心架构清晰、API 全覆盖、行为契约完整；6项低严重度问题不影响编码启动 |

**结论**：设计 v4 相对于 v3 实现了质的飞跃，第1轮全部问题均已正确修复，新增的弱网韧性方案、级联刷新、乐观回滚等设计填补了核心架构缺口。2项中严重度新发现问题（N1 ControlButton 状态机制、N2 connectivityStatus 更新闭环）建议在编码前做最小修复合入设计文档；6项低严重度问题可在编码过程中就地解决，不阻塞编码启动。

---

## 修订说明（本版新增）

本报告为第2轮审查的第1版诊断报告，基于 `a_v2_design_v4.md` 的完整内容进行独立分析，未参考任何之前的质询记录。

