# 任务指令（R3 r3 修订）

> **本轮为 R3 第三轮（PR=3）**：Reviewer 在 r2 轮提出 15 项反馈（3 严重 + 5 一般 + 5 轻微 + r1 遗留 2 项）。本文件覆写原 `plan_task.md` 以修正所有严重问题、采纳关键一般建议、并完成 r1/r2 遗留项的闭环。

---

## 修订摘要

| # | Reviewer 发现 | 严重度 | 本轮处理 |
|---|--------------|--------|---------|
| 1 | `@kit.ArkUI` stub 缺少 ArkUI 装饰器与组件类型（`@Component`/`@State`/`@Prop`/`@Builder`/`@Entry`/`promptAction`/`Progress`/`ProgressType`/`Select`） | 严重 | **修正**：在验证策略第 0 步要求补全 `kit-arkui.d.ts`，提供完整 stub 模板（含 8 个装饰器 + 7 个组件类型） |
| 2 | `tsconfig.json` 路径约定不匹配（实际 `src-ts/main/ets/...` 四层，与 R2 验证报告描述不一致） | 严重 | **修正**：验证策略统一使用 `src-ts/main/ets/components/` 四层结构，与当前 tsconfig.json include 完全对齐 |
| 3 | `AppStorage.setOrCreate<string>` / `AppStorage.set<string>` 的 ArkTS 兼容性未验证，stub 缺失 | 严重 | **修正**：在补全 `kit-arkui.d.ts` 时一并声明 `AppStorage` 接口（`setOrCreate<T>(key, value)` / `set<T>(key, value)`），明确 ArkTS 严格模式下的正确调用形式（去掉泛型） |
| 4 | `LoadingState.errorMessage` 约束 `@Require` 装饰器描述自相矛盾 | 一般 | **修正**：删除 `@Require` 方案；明确"build() 中兜底渲染默认文案 `'加载失败，请重试'`"，约定 + 文档注释即可 |
| 5 | `SensorCard.alarmBits: number[]` 与 R1 `parseAlarmFlag(flag): string[]` 契约冲突 | 一般 | **修正**：Props 改为 `alarmLabels: string[]`（中文标签数组，默认 `[]`），父组件调用 `parseAlarmFlag(alarm_flag)` 解析后传入 |
| 6 | `ConnectivityIndicator` 的 `@Builder` 导出方式与 ArkUI 标准用法不一致 | 一般 | **修正**：R3a 移除顶层 `@Builder` export；仅提供 `<ConnectivityIndicator status={...} />` 组件形式，与 ArkUI 标准用法对齐。`@Builder` 顶层 export 概念从本轮完全删除 |
| 7 | `SensorCard.timestamp` 空值处理未约定 | 一般 | **修正**：明确 `Text(this.timestamp !== '' ? formatTimestamp(this.timestamp) : '--')` |
| 8 | `DeviceSelector` 的 `<Select>` 组件 props 形式未明确 | 一般 | **修正**：明确 `options: devices.map(d => ({ value: d.device_id }))`、`selected: this.selectedIndex`、`onSelect: (index: number) => { ... }` |
| 9 | `SeverityBadge` 与 `AlarmBanner` 的 `severity` 类型不一致 | 一般 | **修正**：两个组件统一为 `severity: string`（与 R1 `DiseaseRecord.severity: string` 对齐），内部 switch 严格匹配英文值 |
| 10 | `LoadingState.onRetry` 必传约束未明确 | 一般 | **修正**：明确"当 `status === 'error'` 时 `onRetry` 必须提供（约定约束，非编译期强约束）"；Props 改为 `onRetry?: () => void` 但在 Props 注释中显式标注约定 |
| 11 | tsconfig.json 修改未提供完整 diff | 轻微 | **修正**：提供修改后的完整 include 数组 |
| 12 | LoadingState 文案硬编码中文无 i18n 规划 | 轻微 | **采纳**：硬编码可接受；在"留待后续"中明确 R5+ 提取 `$r('app.string.*')` 资源 |
| 13 | 组件 Props 缺少完整 ArkTS 装饰器签名 | 轻微 | **修正**：每个组件 Props/State 给出完整 ArkTS 装饰器签名（`@Prop` / `@State` 等） |
| 14 | R3b `PixelMap` stub 模板不完整 | 轻微 | **采纳**：R3b stub 模板在 R3b 任务文件中展开；R3a 仅指向文件路径 |
| 15 | r1 遗留：r2 修订表中 #6 SeverityBadge 类型仍未完全对齐 AlarmBanner | 一般 | **闭合**：已通过本轮 #9 统一为 `string` |

---

## 动作

NEW（R3 第一轮拆分为 R3a，R3b 留待下一轮）

## 任务描述

**R3a：本轮只实现 5 个基础组件**（R3a 移除 `ConnectivityIndicator.ets` 中的顶层 `@Builder` export 后简化为 5 个组件，仅涉及 ArkUI 装饰器 + `common/models` 类型 + AppStorage）：

| 文件 | 职责 | 本轮依赖 |
|------|------|---------|
| `SeverityBadge.ets` | 严重度文字徽标（mild/moderate/severe 三色 + 中文标签） | 无 |
| `AlarmBanner.ets` | 告警横幅（mild/moderate/severe 三色 + 关闭按钮 + 点击回调） | 无 |
| `LoadingState.ets` | 统一加载占位（loading/error/empty 三态 + 重试按钮） | 无 |
| `SensorCard.ets` | 传感器参数卡片（数值+单位+时间戳+告警标签高亮） | `common/utils.formatTimestamp` |
| `DeviceSelector.ets` | 设备下拉选择器（AppStorage 单向写） | `common/models.DeviceInfo` + `AppStorage` |

> **R3a 范围缩减说明**：Reviewer r2 轮 [严重] #1 指出 `ConnectivityIndicator` 的顶层 `@Builder` export 属于 ArkUI 严格模式陷阱（与 `@BuilderParam` 同属装饰器陷阱集合）。r2 轮已确认 `kit-arkui.d.ts` 当前只有 19 行 `window.WindowStage` 声明，不含任何 `@Builder` 装饰器声明。本轮选择将 `ConnectivityIndicator` 移至 R3b（与 ChartView/ControlButton/PaginatedList 同批），仅提供 `<ConnectivityIndicator status={...} />` 组件形式而不导出顶层 `@Builder`。R3a 缩减为 5 个纯组件，最大化排除 ArkUI 装饰器风险。

**R3b：留待下一轮**，含 ArkUI `@Builder` 顶层 export / Canvas / ImageKit / `@BuilderParam` / `@Link` 风险：

- `ConnectivityIndicator.ets`（如需顶层 `@Builder` export 模式）
- `ChartView.ets` / `LineChartRenderer.ets` / `BarChartRenderer.ets`（Canvas API + 父组件 key 强制重绘策略）
- `ControlButton.ets`（`@Link` + 父组件约束 + 乐观 UI）
- `PaginatedList.ets`（`@BuilderParam` + 分页滚动）
- `ImageViewer.ets`（依赖 `@kit.ImageKit` stub + 降级路径）

**R3a 完成后预期命令**：
```bash
hvigorw assembleHap --mode module -p product=default
```
应满足：exit code = 0，无 `error:` 行，允许 `warning:` 行。

> **拆分理由**：R3a 仅 5 个组件，全部围绕"纯 ArkUI 装饰器渲染 + props 消费 + AppStorage 单向写"，零外部 Kit 依赖（除 `@kit.ArkUI` 装饰器 + 组件类型 + `AppStorage`，这三类已在补全 stub 中声明）。R3b 涉及 `@Builder` 顶层 export 陷阱、Canvas API、ImageKit stub、`@BuilderParam` 严格模式陷阱、`@Link` 父组件约束，分批可避免"stub 缺失 vs 接口错误"混杂。

---

## 选择理由

- **依赖方向契合**：5 个基础组件仅依赖 `common/models.ets` 的类型定义与 `common/utils.formatTimestamp`，符合设计文档"components → common"的依赖方向；当前 R1+R2 已固化数据契约，本轮可独立完成。
- **R4 前置**：R4 将实现 4 个 Page（DashboardPage / DiseaseRecordsPage / ControlPage / AdvisoryPage），这些 Page 需直接消费 R3a 组件（DashboardPage 消费 `SensorCard` + `LoadingState`；DiseaseRecordsPage 消费 `SeverityBadge` + `LoadingState`；ControlPage 消费 `LoadingState`；AdvisoryPage 消费 `AlarmBanner` + `LoadingState`）。若 R3a 未实现，Page 层将无可复用的基础渲染单元。
- **可独立编译验证**：5 个组件全部为 `@Component` struct + 类型/常量引用 + AppStorage，无 Canvas / ImageKit / `@BuilderParam` / `@Link` / 顶层 `@Builder` 等高风险语法，可通过 ArkTS strict 模式独立验证。
- **任务粒度合理**：5 个基础组件全部围绕"ArkUI 装饰器渲染单元 + props 消费 + AppStorage 集成"这一个关注点内聚，可在一次提交内完成并编译验证，符合 plan.md "限度控制"原则。

---

## 任务上下文

### 来自 requirement.md 的范围约束
- 本轮**只**实现 R3a（5 个基础组件）；R3b（Canvas / ImageKit / @BuilderParam / @Link / 顶层 @Builder 相关）留待下一轮
- R3a 实现后必须能通过 ArkTS 编译，无 error（允许 warning）
- 组件实现应基于已固化的 models/common/utils 契约，不要修改 common/services
- 设计文档 `docs/4_hamony-architecture.md` 中 components 章节有详细设计
- 重点关注：组件的对外接口（Props/State）、内部状态管理、依赖哪些 Service、与页面的契约

### 来自 design 文档（4_hamony-architecture.md）的组件契约（R3a 相关）

#### 1. SensorCard（第 13 节）
- **Props**：`label: string`、`value: number`、`unit: string`、`timestamp: string`、`alarmLabels: string[]`（中文标签数组，默认 `[]`）
- **职责**：单值展示；按告警标签数切背景高亮；显示单位后缀；显示数据时间戳
- **复用**：被 DashboardPage 和 Index 复用
- **依赖 common**：`SensorSnapshot` 字段定义；`utils.formatTimestamp`

#### 2. DeviceSelector（第 6 节 + 决策 5）
- **Props**：`devices: DeviceInfo[]`（来自父组件 Service 调用结果）
- **内部状态**：本地 `@State selectedIndex: number`
- **AppStorage 写入语义**：组件**仅向 AppStorage 写入** `selectedDeviceId`；**不读取** AppStorage 同步 selectedIndex。父 Page 层需用 `@StorageLink('selectedDeviceId') selectedDeviceId: string` 监听变化。
- **依赖 common**：`DeviceInfo` 字段定义；`AppStorage.setOrCreate('selectedDeviceId', '')` 初始化

#### 3. AlarmBanner（第 17 节）
- **Props**：`message: string`、`severity: string`、`onClose?: () => void`、`onTap?: () => void`
- **行为**：`message === ''` 时不渲染（`if (this.message === '') { /* skip render */ }`）；点击触发 `onTap`；关闭按钮触发 `onClose`
- **依赖 common**：无（仅消费 props）

#### 4. SeverityBadge（第 12 节衍生）
- **Props**：`severity: string`（与 R1 `DiseaseRecord.severity: string` 对齐）
- **行为**：英文 `mild/moderate/severe` → 绿/橙/红 + "轻度/中度/重度"；其它值 → 灰色 + 原字符串
- **依赖 common**：`DiseaseRecord.severity` 字段（string 类型）

#### 5. LoadingState（第 21 节衍生）
- **Props**：`status: 'loading' | 'error' | 'empty'`、`errorMessage: string`、`onRetry?: () => void`
- **重要约束**：`status === 'error'` 时 `errorMessage` **必须**提供（不可为空）；`status === 'loading' | 'empty'` 时 `errorMessage` 被忽略。`status === 'error'` 时 `onRetry` **必须**提供（约定约束，非编译期强约束）。
- **行为**：loading → `<Progress>` + "加载中..." 文案；error → 错误图标 + `errorMessage`（若为空降级显示默认文案）+ "重试"按钮（点击触发 `onRetry`）；empty → 空图标 + "暂无数据"文案
- **依赖 common**：无（仅消费 props）

---

## 已有代码上下文

### 已固化的 common 层契约（不修改）
- `common/models.ets`：`DeviceInfo`、`SensorSnapshot`、`SensorHistory`、`DailyAggregation`、`DiseaseRecord`、`DiseaseStats`、`HeatmapData`、`HeatmapPoint`、`HeatmapSummary`、`CommandRequest`、`CommandResponse`、`CommandLog`、`Advisory`、`AdvisoryDetection`、`AdvisoryEnv`、`AdvisoryLinkage`、`AdvisoryAction`、`ImageUploadResult`、`TextResult`、`BinaryResult`、`ApiResponse<T>`、`PaginatedData<T>`、`Pagination`、`CacheEntry<T>`、`RetryPolicyConfig`、`PollingCallback`、`ConnectivityStatus`
- `common/constants.ets`：`API_BASE_URL` / `API_PATH_PREFIX` / `API_KEY` / `HEADER_API_KEY` / `DEFAULT_TIMEOUT_MS` / `UPLOAD_TIMEOUT_MS` / 各 `POLL_INTERVAL_*_MS` / `CONTROL_POLL_INTERVAL_MS` / `CONTROL_POLL_MAX_TIMES` / 各 `CACHE_TTL_*_MS` / 各 `CACHE_KEY_PREFIX_*` / `CMD_*_ON`/`CMD_*_OFF` 8 个 / `COMMAND_SOURCE_*` / `COMMAND_STATUS_*` / `ERR_CODE_*` / `ALARM_FLAG_*` / `RETRY_*`
- `common/utils.ets`：`formatTimestamp(iso)`、`parseAlarmFlag(flag)` 返回 `string[]`（中文标签数组）、`sleep(ms)`、`buildQueryString(params)`、`isNetworkError(err)`、`nowMs()`
- `common/CacheManager.ets`：`set<T>(key, data, ttl?)` / `get<T>(key): T | null` / `invalidate(key)` / `clear()`
- `common/RetryPolicy.ets`：`DEFAULT_RETRY` 常量
- `common/api.ets`：`request()` / `requestRaw()` / `uploadFile()`（**R3a 不调用**）

### 已固化的 services 层契约（不修改，R3a 仅在 DeviceSelector 注释中引用 DeviceService）
- `services/DeviceService.ets`：`getDeviceList(deviceId?)` / `getCachedDevices(deviceId?)` / `refreshDevices(deviceId?)`
- `services/HttpClient.ets`：导出 `get<T>` / `post<T>` / `getRaw` / `BASE_URL` / `HEADER_KEY`
- `services/PollingManager.ets`：`start` / `stop` / `stopAll` / `suspendAll` / `resumeAll`

### 组件设计原则
- R3a 仅依赖 `common/` 层（types + utils + constants）+ `@kit.ArkUI`（装饰器 + 组件类型 + AppStorage）；不依赖 services 层（`DeviceSelector` 仅注释引用 DeviceService，实际不调用）
- `@Prop` 用于父→子单向数据流；R3a 暂不涉及 `@Link`（R3b 的 `ControlButton` 使用）
- 所有 R3a 组件不持有异步副作用
- 命名风格与现有 .ets 文件一致（PascalCase + 完整 JSDoc 中文注释）

---

## 详细任务范围（按组件拆分）

### 1. SensorCard.ets
- **职责**：单值展示卡片，含数值 + 单位 + 时间戳 + 告警标签高亮
- **完整 ArkTS 签名**：
  ```typescript
  @Component
  struct SensorCard {
    @Prop label: string;
    @Prop value: number;
    @Prop unit: string;
    @Prop timestamp: string;
    @Prop alarmLabels: string[] = [];
    build() { /* ... */ }
  }
  export { SensorCard };
  ```
- **行为**：
  - 数值大字号显示
  - 末尾显示 `unit`
  - 底部显示 `Text(this.timestamp !== '' ? formatTimestamp(this.timestamp) : '--')`（**约定**：空 timestamp 显示 `--`）
  - 当 `alarmLabels.length > 0` 时，背景色切为告警色（浅红 `#FFEBEE`）
- **依赖 common**：`utils.formatTimestamp`

### 2. DeviceSelector.ets
- **职责**：设备下拉选择器，与 `AppStorage.selectedDeviceId` **单向写**（不读）
- **完整 ArkTS 签名**：
  ```typescript
  @Component
  struct DeviceSelector {
    @Prop devices: DeviceInfo[];
    @State selectedIndex: number = 0;
    aboutToAppear() { /* AppStorage.setOrCreate('selectedDeviceId', '') */ }
    build() { /* <Select options={...} selected={...} onSelect={...} /> */ }
  }
  export { DeviceSelector };
  ```
- **行为**：
  - `aboutToAppear`：`AppStorage.setOrCreate('selectedDeviceId', '')` 初始化（**不**从 AppStorage 读取 existing 值到 selectedIndex；selectedIndex 初始始终为 0）
  - 渲染 `<Select>` 组件（ArkUI 内建），ArkTS 精确 props 形式：
    - `options: devices.map(d => ({ value: d.device_id }))`（每个元素为 `SelectOption = { value: string }`）
    - `selected: this.selectedIndex`（绑定当前选中索引）
    - `onSelect: (index: number) => { ... }`（监听选择变化，回调签名 `onSelect: (index: number, value?: string) => void`）
  - 用户切换选项时（`onSelect` 回调）：
    - `this.selectedIndex = index`
    - `AppStorage.set('selectedDeviceId', devices[index].device_id)`
- **AppStorage 语义**（与 R4 Page 层契约）：
  - **本组件仅写 AppStorage**：`AppStorage.set('selectedDeviceId', deviceId)` 在用户切换时调用
  - **不读 AppStorage 同步 selectedIndex**：selectedIndex 是组件内部 UI 状态，不与 AppStorage 双向同步
  - **父 Page 层职责**：通过 `@StorageLink('selectedDeviceId') selectedDeviceId: string` 监听变化，触发数据刷新（如 `SensorService.getLatest(selectedDeviceId)`）
- **依赖 common**：`DeviceInfo`

### 3. AlarmBanner.ets
- **职责**：顶部告警横幅
- **完整 ArkTS 签名**：
  ```typescript
  @Component
  struct AlarmBanner {
    @Prop message: string;
    @Prop severity: string;
    @Prop onClose?: () => void;
    @Prop onTap?: () => void;
    build() { /* if (this.message === '') skip render */ }
  }
  export { AlarmBanner };
  ```
- **行为**：
  - `message === ''` 时用 `if (this.message === '') { /* skip build */ }` 跳过渲染（保证父组件可传空字符串隐藏）
  - 根据 `severity` 字符串匹配：
    - `'mild'` → 浅绿 `#E8F5E9`
    - `'moderate'` → 浅橙 `#FFF3E0`
    - `'severe'` → 浅红 `#FFEBEE`
    - 其它值 → 灰色 `#F5F5F5`（兜底）
  - 右上角关闭按钮（`<Button>` 或 `<Text>` + `onClick`）触发 `this.onClose?.()`
  - 整个横幅 `onClick` 触发 `this.onTap?.()`
- **依赖**：无（仅 props）

### 4. SeverityBadge.ets
- **职责**：严重度文字徽标
- **完整 ArkTS 签名**：
  ```typescript
  @Component
  struct SeverityBadge {
    @Prop severity: string;
    build() { /* switch (this.severity) */ }
  }
  export { SeverityBadge };
  ```
- **行为**：
  - 英文映射（`switch (this.severity)` 严格匹配）：
    - `'mild'` → 绿色 `#4CAF50` + "轻度"
    - `'moderate'` → 橙色 `#FF9800` + "中度"
    - `'severe'` → 红色 `#F44336` + "重度"
  - 其它字符串值（含中文"轻度/中度/重度"等）：灰色 `#9E9E9E` + 原 severity 字符串
- **依赖**：无
- **类型对齐**：与 `AlarmBanner.severity: string` 完全一致（r1/r2 遗留 #6 已闭合）

### 5. LoadingState.ets
- **职责**：统一加载状态占位
- **完整 ArkTS 签名**：
  ```typescript
  @Component
  struct LoadingState {
    @Prop status: 'loading' | 'error' | 'empty';
    @Prop errorMessage: string;
    @Prop onRetry?: () => void;
    build() {
      // if (this.status === 'error' && !this.errorMessage) { errorMessage = '加载失败，请重试'; /* 兜底 */ }
    }
  }
  export { LoadingState };
  ```
- **约束**：
  - `status === 'error'` 时 `errorMessage` **必须**提供（约定 + 文档注释；不使用 `@Require` 装饰器）
  - `status === 'error'` 时 `onRetry` **必须**提供（约定 + 文档注释；不使用 `@Require` 装饰器）
  - `status === 'loading' | 'empty'` 时 `errorMessage` / `onRetry` 被忽略
- **行为**：
  - loading → `<Progress type={ProgressType.Circular}>` + "加载中..." 文案
  - error → 错误图标（`<Text>⚠</Text>`）+ `errorMessage`（若为空降级显示默认文案 `'加载失败，请重试'`，**不 throw**，避免页面崩溃）+ "重试"按钮（点击触发 `this.onRetry?.()`）
  - empty → 空图标（`<Text>∅</Text>`）+ "暂无数据"文案
- **依赖**：无

---

## 实施策略

### 组织方式
- 一次性新建 5 个 R3a 组件文件
- 一次性 ArkTS strict 模式 `tsc --noEmit` 验证全部 5 文件

### 编码顺序（按依赖关系）
1. **零依赖组件**：
   - `SeverityBadge.ets`
   - `AlarmBanner.ets`
   - `LoadingState.ets`
2. **依赖 common/utils**：
   - `SensorCard.ets`（依赖 `formatTimestamp`）
3. **AppStorage 集成**：
   - `DeviceSelector.ets`（依赖 `AppStorage` + `DeviceInfo`）

### 验证策略（4 层路径约定 + 前置 stub 补全）

#### 第 0 步：前置补全 `/tmp/arkts-check/stubs/kit-arkui.d.ts`

当前 `kit-arkui.d.ts` **只有 19 行**，仅声明 `window.WindowStage`；R3a 实施前必须补全 ArkUI 装饰器 + 组件类型 + `AppStorage` 的 stub。完整模板如下：

```typescript
// /tmp/arkts-check/stubs/kit-arkui.d.ts
declare type AsyncCallback<T> = (err: BusinessError | null, data?: T) => void;
declare interface BusinessError extends Error {
  code: number;
  name: string;
  message: string;
}

// ArkUI 全局装饰器与组件类型
declare module '@kit.ArkUI' {
  // ============================
  // 全局装饰器（ArkTS struct 内可用）
  // ============================
  // 注：ArkTS 装饰器在 TypeScript 中以 `declare` 函数形式存在，供 tsc 类型检查
  // 实际运行时由 ArkTS 编译器/ETS 运行时识别（tsc 仅做声明匹配，不做语义校验）
  
  export function Component(target: object): void;
  export function Entry(target: object): void;
  export function State(target: object, propertyKey: string): void;
  export function Prop(target: object, propertyKey: string): void;
  export function Link(target: object, propertyKey: string): void;
  export function Builder(target: object | (() => void), propertyKey?: string): void;
  export function BuilderParam(target: object, propertyKey: string): void;
  export function Watch(target: object, propertyKey: string): void;
  export function StorageLink(target: object, propertyKey: string): void;
  export function StorageProp(target: object, propertyKey: string): void;
  
  // ============================
  // 组件类型
  // ============================
  
  // Progress 进度条
  export class ProgressType {
    static readonly Linear: ProgressType;
    static readonly Circular: ProgressType;
    static readonly Ring: ProgressType;
    static readonly Eclipse: ProgressType;
    static readonly ScaleRing: ProgressType;
    static readonly Capsule: ProgressType;
  }
  
  export interface ProgressOptions {
    value?: number;
    total?: number;
    type?: ProgressType;
    style?: object;
  }
  
  // Select 下拉选择
  export interface SelectOption {
    value: string;
    icon?: Resource;
  }
  
  export interface SelectAttribute {
    options(value: SelectOption[]): SelectAttribute;
    selected(value: number): SelectAttribute;
    value(value: string): SelectAttribute;
    font(value: object): SelectAttribute;
    fontColor(value: string | Resource): SelectAttribute;
    selectedOptionBgColor(value: string | Resource): SelectAttribute;
    selectedOptionFont(value: object): SelectAttribute;
    selectedOptionFontColor(value: string | Resource): SelectAttribute;
    optionBgColor(value: string | Resource): SelectAttribute;
    optionFont(value: object): SelectAttribute;
    optionFontColor(value: string | Resource): SelectAttribute;
    onSelect(callback: (index: number, value?: string) => void): SelectAttribute;
  }
  
  // AppStorage 全局存储
  export class AppStorage {
    static setOrCreate<T>(key: string, value: T): void;
    static set<T>(key: string, value: T): void;
    static get<T>(key: string): T | undefined;
    static has(key: string): boolean;
    static delete(key: string): void;
    static keys(): string[];
  }
  
  // promptAction（暂为 R3b 准备，但本轮一并声明避免后续 stub 变更）
  export namespace promptAction {
    export function showToast(options: { message: string | Resource; duration?: number }): void;
    export function showDialog(options: {
      title: string | Resource;
      message: string | Resource;
      buttons?: Array<{ text: string; color?: string }>;
    }): void;
  }
  
  // window.WindowStage（R1 已声明，保留）
  export namespace window {
    class WindowStage {
      loadContent(path: string, callback: AsyncCallback<void>): void;
      loadContent(path: string, callback: (err: {code: number, message: string}) => void): void;
      on(eventType: string, callback: () => void): void;
    }
  }
}

// ============================
// ArkUI 全局组件类（用于 build() JSX 中识别）
// ============================
// 注：以下为组件类的 stub，供 tsc 在 JSX 中识别；实际渲染由 ArkUI 运行时处理

declare class Progress {
  constructor(options?: ProgressOptions);
}

declare class Select {
  constructor(options?: object);
  attribute: SelectAttribute;
}

declare class Text {
  constructor(content?: string | Resource);
}

declare class Button {
  constructor(options?: object);
}

declare class Row {
  constructor(options?: object);
}

declare class Column {
  constructor(options?: object);
}

declare class Stack {
  constructor(options?: object);
}
```

**ArkTS 严格模式下 `AppStorage` 调用约定**：
- ArkUI 官方文档中 `AppStorage.setOrCreate` / `AppStorage.set` 的签名**不含泛型类型参数**（泛型仅作为 TypeScript 类型推导辅助），ArkTS 严格模式编译时不要求显式标注泛型。
- **本轮要求**：调用形式统一为 `AppStorage.setOrCreate('selectedDeviceId', '')`（**不带** `<string>`），`AppStorage.set('selectedDeviceId', deviceId)`（**不带** `<string>`）。
- stub 中 `setOrCreate<T>` / `set<T>` 的泛型参数用于 TypeScript 类型推导（让 tsc 推断返回类型），**不要求调用方显式标注**。

#### 第 1 步：更新 `/tmp/arkts-check/tsconfig.json`

将 `include` 数组更新为（**完整修改后内容**）：

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "moduleResolution": "node",
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "experimentalDecorators": true,
    "noEmit": true,
    "ignoreDeprecations": "6.0",
    "baseUrl": ".",
    "paths": {
      "@kit.NetworkKit": ["stubs/kit-network.d.ts"],
      "@kit.RequestKit": ["stubs/kit-request.d.ts"],
      "@kit.AbilityKit": ["stubs/kit-ability.d.ts"],
      "@kit.PerformanceAnalysisKit": ["stubs/kit-performance.d.ts"],
      "@kit.ArkUI": ["stubs/kit-arkui.d.ts"],
      "@kit.BasicServicesKit": ["stubs/kit-basic.d.ts"]
    }
  },
  "include": [
    "src-ts/main/ets/common/**/*.ts",
    "src-ts/main/ets/services/**/*.ts",
    "src-ts/main/ets/entryability/**/*.ts",
    "src-ts/main/ets/components/**/*.ts",
    "stubs/**/*.d.ts"
  ]
}
```

**Diff 说明**：仅在 `include` 数组中新增 `"src-ts/main/ets/components/**/*.ts"` 一行（位置在 `entryability` 之后，`stubs` 之前）。

#### 第 2 步：创建 components 目录并复制源文件

```bash
mkdir -p /tmp/arkts-check/src-ts/main/ets/components
cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/components/*.ets /tmp/arkts-check/src-ts/main/ets/components/
```

**路径约定**：与 tsconfig.json include 完全一致的 **四层结构**（`src-ts/main/ets/components/`），与 R2 code_report.md 第 41-49 行的 `src-ts/main/ets/common/` 等子目录布局相同。

#### 第 3 步：派生 .ts 副本

```bash
cd /tmp/arkts-check/src-ts/main/ets/components
for f in *.ets; do base=$(basename "$f" .ets); cp "$f" "$base.ts"; done
```

#### 第 4 步：运行 tsc

```bash
cd /tmp/arkts-check && tsc --noEmit -p .
```

#### 第 5 步：期望结果

- exit 0，0 errors
- 允许 warning 行
- 若 tsc 失败 → 修复后重新验证（不允许带 error 进入 R3b）

> **重要**：R3a 不需要创建任何新的 Kit stub（`@kit.ImageKit` 留待 R3b 实施前补全）。

---

## 已知约束与设计修正

### ArkTS 装饰器约束
- `@Component` / `@Entry` / `@State` / `@Prop` / `@Link` / `@Builder` / `@BuilderParam` / `@Watch` / `@StorageLink` / `@StorageProp` 等装饰器仅能用于 ArkUI 组件 struct 内
- 自定义 interface 类型不能使用装饰器
- R3a 不涉及 `@Link` / `@BuilderParam` / 顶层 `@Builder`（这三个装饰器在 R3b 引入）

### 状态管理最佳实践
- **单一职责**：每个组件仅维护自身 UI 状态（如 `DeviceSelector` 维护 `selectedIndex`）；不持有跨组件共享状态
- **不在组件内发起 Service 调用**（R3a 全部组件零 Service 调用）
- **不在组件内启动 PollingManager**（轮询任务由 Page 层在 `aboutToAppear` 中注册，在 `aboutToDisappear` 中清理）

### 组件解耦
- props 入参类型显式标注，避免隐式 `any`
- 回调函数（`onTap` / `onClose` / `onRetry`）统一标记为可选（`?:`），调用方未提供时使用 `this.onTap?.()` 安全调用
- 默认值（`alarmLabels: []`）在 ArkTS 装饰器语法中显式标注

### AppStorage 初始化
- `DeviceSelector` 首次渲染前需 `AppStorage.setOrCreate('selectedDeviceId', '')`；否则父 Page 层 `@StorageLink('selectedDeviceId')` 抛出"未初始化"错误
- 实际策略：在组件 `aboutToAppear` 中调用 `AppStorage.setOrCreate('selectedDeviceId', '')`（**不带泛型**，与 ArkUI 官方文档一致）
- **本轮 DeviceSelector 仅写 AppStorage，不读 AppStorage**（设计决策：组件保持 UI 状态单一职责，避免 AppStorage 反向同步导致 selectedIndex 抖动）

### severity 类型统一
- `SeverityBadge` 与 `AlarmBanner` 的 `severity` Props **统一为 `string`**（与 R1 `DiseaseRecord.severity: string` 对齐）
- 组件内部用 `switch (severity)` 严格匹配英文 `mild/moderate/severe`，其它值走默认分支（兜底灰色 + 原字符串）

### LoadingState 错误消息约束
- 当 `status === 'error'` 时 `errorMessage` 必须提供（约定约束，不使用 `@Require` 装饰器）
- 实现约定：`build()` 中通过 `const msg = this.errorMessage !== '' ? this.errorMessage : '加载失败，请重试';` 兜底，**不 throw**（避免页面崩溃）
- 当 `status === 'error'` 时 `onRetry` 必须提供（约定约束，不使用 `@Require` 装饰器）
- 实现约定：Props 注释中显式标注"建议父组件在 `status === 'error'` 时传非空 `errorMessage` 与 `onRetry` 回调"，实现层不强制编译期检查

### timestamp 空值处理
- `SensorCard` Props 注释明确：`timestamp` 为空字符串时显示 `'--'`
- 实现：`Text(this.timestamp !== '' ? formatTimestamp(this.timestamp) : '--')`

### DeviceSelector `<Select>` 组件 ArkTS 精确用法
- `options: this.devices.map((d: DeviceInfo) => { return { value: d.device_id }; })`
- `selected: this.selectedIndex`
- `onSelect: (index: number, value?: string): void => { this.selectedIndex = index; AppStorage.set('selectedDeviceId', this.devices[index].device_id); }`

### 不修改的文件
- `common/*.ets` 全部 R1 固化
- `services/*.ets` 全部 R2 固化（含 HttpClient / PollingManager）
- `entryability/EntryAbility.ets`
- `pages/Index.ets`（保持 Hello World 模板）
- `module.json5` / `main_pages.json` / `oh-package.json5`
- `stubs/kit-*.d.ts` 中**除 `kit-arkui.d.ts` 之外**的 stub 文件（R3a 只需补全 `kit-arkui.d.ts`）

### 文件清单
- **新建** 5 个组件文件（R3a）：
  - `harmony-app/entry/src/main/ets/components/SeverityBadge.ets`
  - `harmony-app/entry/src/main/ets/components/AlarmBanner.ets`
  - `harmony-app/entry/src/main/ets/components/LoadingState.ets`
  - `harmony-app/entry/src/main/ets/components/SensorCard.ets`
  - `harmony-app/entry/src/main/ets/components/DeviceSelector.ets`
- **修改** 1 个 stub 文件：
  - `/tmp/arkts-check/stubs/kit-arkui.d.ts`（补全 ArkUI 装饰器 + 组件类型 + AppStorage，模板见上文第 0 步）
- **修改** 1 个 tsconfig 文件：
  - `/tmp/arkts-check/tsconfig.json`（include 数组新增 `src-ts/main/ets/components/**/*.ts`，完整内容见上文第 1 步）

### 留待 R3b（下一轮）的 7 个组件
- `ConnectivityIndicator.ets`（如需顶层 `@Builder` export 模式）
- `ChartView.ets` / `LineChartRenderer.ets` / `BarChartRenderer.ets`（Canvas API + 父组件 key 强制重绘策略）
- `ControlButton.ets`（`@Link` + 父组件约束 + 乐观 UI + `onToggle: Promise<void>`）
- `PaginatedList.ets`（`@BuilderParam renderItem` + `loadPage: Promise<{records, total}>`）
- `ImageViewer.ets`（依赖 `@kit.ImageKit` stub + 降级路径 + `createPixelMap()` await）

### R3b 前置条件（实施前必须完成）
- 创建 `/tmp/arkts-check/stubs/kit-image.d.ts`，声明 `image.PixelMap` / `image.ImageSource` / `image.createImageSource(buf): ImageSource` / `createPixelMap(): Promise<PixelMap>` + `PixelMap.getPixelBytes(): ArrayBuffer` 等方法（**完整 stub 模板在 R3b 任务文件中展开**）
- 在 `tsconfig.json` 的 `paths` 中追加 `"@kit.ImageKit": ["stubs/kit-image.d.ts"]`
- 确认 `@kit.ArkUI` stub 已声明 `Canvas` 组件 + `CanvasRenderingContext2D` + `onReady` 回调类型（如缺失需补全）
- ChartView 的父组件 key 强制重绘策略需要 R4 Page 层配合（Page 层持有 `@State chartRebuildKey: string`，切换设备时 `chartRebuildKey = nowMs()`，ChartView 通过 `ChartView({ key: 'chart-' + chartRebuildKey, ... })` 触发重绘）

### i18n 国际化（留待 R5+）
- R3a LoadingState 中"加载中..." / "暂无数据" / "重试" / "加载失败，请重试"等中文文案硬编码
- R5+ 提取为 `$r('app.string.*')` 资源，实现多语言切换
- 本轮不引入 `$r` 依赖

---

## 不在本轮范围内（明确划定边界）

### 不在 R3a 范围内（留待 R3b）
- `ConnectivityIndicator.ets`（顶层 `@Builder` export 陷阱）
- `ChartView.ets` / `LineChartRenderer.ets` / `BarChartRenderer.ets`（Canvas 渲染 + 父组件 key 重绘）
- `ControlButton.ets`（`@Link` + 乐观 UI）
- `PaginatedList.ets`（`@BuilderParam` + 分页滚动）
- `ImageViewer.ets`（ImageKit 降级路径）
- `@kit.ImageKit` stub 创建（留待 R3b 实施前）
- `@kit.ArkUI` stub 中 Canvas 组件 + CanvasRenderingContext2D + onReady 回调类型（如缺失，R3b 实施前补全）

### 不在 R3 范围内（明确划定边界，留待后续轮次）
- `Index.ets` 改造为真实入口（含 `Navigation` 容器与 `NavPathStack`）
- `DashboardPage.ets`（传感器卡片 + 实时曲线 + 历史趋势）— R4
- `DiseaseRecordsPage.ets`（列表 + 筛选 + 详情 + 图片查看）— R4
- `ControlPage.ets`（设备执行机构操作面板）— R4
- `AdvisoryPage.ets`（AI 决策建议展示）— R4
- 任何形式的单元测试
- ImageViewer 主路径的具体网络联调（仅依赖 `BASE_URL` 拼接的 URL 字符串）
- LineChartRenderer 的触摸交互（v1.0 仅静态绘制）
- BarChartRenderer 的实际柱状渲染（仅占位）
- i18n 资源化（硬编码中文，R5+ 提取）