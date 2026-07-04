# 迭代需求 — v3

## 背景

本迭代基于 `a_v2_design_v4.md` 进行第 3 轮修订。`b_v2_diag_v2.md` 的诊断结论为：v4 设计对第 1 轮审查的 17 项问题及 2 项质询补充实现全覆盖修复，但存在 2 项中严重度和 4 项低严重度新发现缺口，以及 6 项持续存在项。质询结论为 LOCATED（通过）。

## 需要解决的问题

### 中严重度

#### N1. `ControlButton` 乐观 UI 的状态管理机制未闭合

**位置**：核心抽象 §16 `ControlButton`

**问题**：`ControlButton` 使用 `@Prop` 接收 `isOn`，但 ArkUI 中 `@Prop` 为只读，子组件无法直接修改。乐观 UI 要求点击后立即翻转状态，需明确选择状态管理方案。

**要求**：
- 在核心抽象 §16 中明确选择方案 A：`ControlButton` 改用 `@Link` 接收 `isOn`，乐观 UI 通过 `this.isOn = targetState` 直接修改父组件状态
- 补充 `@Link` 决策说明，移除方案 C 引用（`aboutToUpdate` 不存在于 ArkUI API 21）
- 同步更新相关行为场景（场景 B）

#### N2. 各页面 `connectivityStatus` 的完整状态转换闭环未定义

**位置**：核心抽象 §12 页面组件、错误处理策略弱网韧性表

**问题**：每个页面声明了 `@State connectivityStatus`，但完整的状态转换闭环（触发时机、离线判定、恢复机制、跨页面一致性）未定义。

**要求**：
- 采用纯页面级状态转换矩阵，放弃模块级 `globalConnectivity` 方案
- 在 `loadData()` 的统一 catch 中维护 `connectivityStatus` 状态转换：
  - 每次 Service 调用成功 → `'online'`
  - 网络异常且 HttpClient 重试耗尽 → `'offline'`
  - 业务错误 → 保持当前值不变
- 在错误处理策略中补充完整的状态转换矩阵表，覆盖 `loading→online→offline→online` 闭环
- 将 `connectivityStatus` 初始值从 `'loading'` 改为 `'online'`（避免启动闪白），`aboutToAppear` 中短暂设置为 `'loading'`

### 低严重度

#### N3. `AlarmBanner` 缺少核心抽象定义

**位置**：模块目录 `components/AlarmBanner.ets`、场景 A

**问题**：场景 A 中 `AlarmBanner` 出现在完整行为链路中，但核心抽象部分未有独立章节描述其职责、属性、交互行为。

**要求**：在核心抽象中为 `AlarmBanner` 补充独立章节，定义：
- `@Prop message: string`
- `@Prop severity: 'mild' | 'moderate' | 'severe'`
- 告警展示逻辑和交互行为（点击跳转/可关闭等）

#### N4. `PollingManager` 串行模式定时漂移行为未标注

**位置**：核心抽象 §9 `PollingManager`

**问题**：串行模式下若单 tick 因重试耗时 >10s，实际轮询频率会低于配置间隔，设计未注明此行为预期。

**要求**：在 `PollingManager` 职责描述中补充串行定时策略说明，明确：
- 每个 tick 完成后以 `setTimeout(fn, interval)` 调度下一个 tick
- 若某 tick 执行耗时超过 `interval`，有效轮询频率 = 1/(tickDuration + interval) ≤ 1/interval
- 在 IoT 弱网场景下避免请求堆积比维持名义频率更重要

#### N5. 页面核心抽象中 `@State alarmMessage/alarmSeverity` 缺失声明

**位置**：核心抽象 §12 页面组件

**问题**：场景 A 引用了 `@State alarmMessage/alarmSeverity`，但 §12 页面组件的 `@State` 列表中未包含这两个变量。

**要求**：在核心抽象 §12 的页面 `@State` 列表中补充 `alarmMessage: string` 和 `alarmSeverity: 'mild' | 'moderate' | 'severe'` 声明。

#### N6. `catch((err: Error)` 不符 ArkTS 约定

**位置**：核心抽象 §12 `aboutToAppear` 代码片段

**问题**：代码片段使用 `catch((err: Error)`，但需求 §6.7 和参考项目约定使用 `catch((err: BusinessError)`。

**要求**：将 `catch((err: Error)` 统一替换为 `catch((err: BusinessError)`。

### 条件修复项

#### M1. `PollingCallback` 显式类型定义缺失

**位置**：核心抽象 §9 `PollingManager`、`common/models.ets`

**问题**：`PollingCallback` 类型仅以文本描述存在于修订说明中，未在代码模型中使用 `type PollingCallback = () => Promise<void>` 形式显式定义。

**要求**：在 `common/models.ets` 或 `PollingManager.ets` 中添加 `export type PollingCallback = () => Promise<void>` 显式导出，`PollingManager.start(key, fn, interval)` 中 `fn` 参数标注为 `PollingCallback` 类型。

### 持续存在项（低优先级，建议修复）

#### S1. `CacheManager` 缓存键空间共享冲突

**位置**：`common/CacheManager.ets`

**问题**：多 Service 使用同一 `CacheManager` 实例，键名可能冲突。

**要求**：约定各 Service 使用统一前缀命名空间（如 `sensor_`、`device_`）作为缓存键前缀。

#### S3. `DiseaseRecord` 模型缺少 `linkage_detail` 字段

**位置**：`common/models.ets`

**问题**：`DiseaseRecord` 接口未包含 `linkage_detail` 字段。

**要求**：在 `DiseaseRecord` 接口中补充 `linkage_detail?: string` 可选字段。

#### S4. `SensorService.getLatest()` 未注明 `deviceId` 可选行为

**位置**：核心抽象 §3 `SensorService`

**问题**：`getLatest(deviceId)` 未定义 `deviceId` 为空时的行为。

**要求**：注明 `deviceId` 为空时的行为约定（如返回空结果或抛异常）。

#### S6. `CommandService` 硬引用 `DeviceService.refreshDevices()` 的 ad-hoc 耦合

**位置**：核心抽象 §5 `CommandService`

**问题**：`CommandService` 失败路径直接调用 `DeviceService.refreshDevices()`，形成跨 Service 硬耦合。

**要求**：在决策中记录此耦合在 v1.0 阶段可接受，并标注后续架构升级时可通过事件机制解耦。

## 历史修复验证

以下为第 1 轮和第 2 轮已修复问题的验证状态，本次迭代**不要求重新修复**，但需确保新增修改不与已修复方案冲突：

- **H1-H11**：10 项高严重度问题已完整修复 ✅
- **M1-M3、M5**：中严重度问题（M1 为条件修复，本次需补充显式类型定义后转为完整修复）✅
- **L1-L3**：低严重度问题已完整修复 ✅
- **QC1-QC2**：质询补充项已完整修复 ✅

## 修订约束

- 所有修改必须在 ArkTS + ArkUI（API 21）框架约束内
- 依赖方向保持：`pages/ → services/ → common/`
- 禁止引入 ArkTS 不支持的语法（如 `class` 继承、`interface` 方法实现、运行时反射）
- 数据模型使用 `interface`，组件使用 `@Entry` + `@Component` 装饰器
