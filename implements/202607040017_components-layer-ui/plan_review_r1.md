# 计划审查报告（R3 r1）

## 审查结果

REJECTED

## 发现

### [严重] 1. `PaginatedList` 的 `loadPage` 返回结构在 task 文件内部前后不一致

- **位置**：`plan_task.md` 第 82 行（设计文档引用）与第 227 行（详细任务范围）相互矛盾
- **问题**：
  - 第 82 行（来自设计文档 §18）：`loadPage: (page: number) => Promise<{ records: T[], total: number }>`
  - 第 227 行（详细任务范围）：`loadPage: (page: number) => Promise<{ records: T[], hasMore: boolean }>`
- **影响**：实现期无法确定返回结构是 `{ records, total }` 还是 `{ records, hasMore }`。
  - 若按 `{ records, hasMore }`：调用方需自行决定是否还有更多数据（基于 `records.length < hasMore`），但与 `DiseaseService.getList` 实际返回的 `PaginatedData<T> = { pagination: { total, page, page_size }, records: T[] }` 不直接对应，需在 Page 层额外计算 `hasMore`。
  - 若按 `{ records, total }`：组件需计算 `hasMore = items.length < total`，更符合 R2 已固化 `PaginatedData<T>` 契约。
- **R2 已固化契约**：`DiseaseService.getList()` 返回 `PaginatedData<DiseaseRecord>`，即 `{ pagination: { total, page, page_size }, records: T[] }`。
- **期望修正方向**：统一采用 `{ records: T[], total: number }`，组件内部基于 `items.length < total` 判定 `hasMore`。这样调用方只需将 `DiseaseService.getList()` 结果扁平化为 `{ records, total }` 传入，无需额外逻辑。

---

### [严重] 2. `ImageViewer` 依赖 `image.PixelMap` 的 Kit stub 当前不存在

- **位置**：`plan_task.md` 第 91、255、309、337 行
- **问题**：
  - `ImageViewer` 降级路径需调用 `image.createImageSource(buf).createPixelMap()`，使用 `@kit.ImageKit` 模块。
  - 当前 `/tmp/arkts-check/stubs/` 目录仅含 `kit-ability.d.ts` / `kit-arkui.d.ts` / `kit-basic.d.ts` / `kit-network.d.ts` / `kit-performance.d.ts` / `kit-request.d.ts` / `hypium.d.ts`，**没有** `kit-image.d.ts` 或 `@kit.ImageKit` stub。
  - 第 337 行明确写"当前 `@kit.ImageKit` 是否已声明 stub 需在验证阶段补全"——这意味着 task 文件本身承认该 stub 缺失风险，但未给出解决方案。
- **影响**：如未在实现前补全 stub，`tsc --noEmit` 将报错（`Cannot find module '@kit.ImageKit'` 或 `image is not defined`）。
- **期望修正方向**：明确要求实现期在 `/tmp/arkts-check/stubs/kit-image.d.ts` 新增 stub，声明 `image.PixelMap` / `image.ImageSource` / `image.createImageSource(buf)` 返回 `ImageSource` / `createPixelMap()` 返回 `PixelMap`。这是 R3 实施的前置条件，不可留给实现期"看运气"。

---

### [严重] 3. `ControlButton` 的 `onToggle` 回调签名在 task 文件内部前后不一致

- **位置**：`plan_task.md` 第 76 行（设计文档引用）与第 205 行（详细任务范围）相互矛盾
- **问题**：
  - 第 76 行（来自设计文档 §16）：`onToggle?: (targetState: boolean) => Promise<void>`
  - 第 205 行（详细任务范围）：`@Prop onToggle?: (targetState: boolean) => void`（无 `Promise` 包装）
- **影响**：
  - 若按 `(targetState: boolean) => Promise<void>`：组件可以 `await onToggle(...)`，但 task 第 209-214 行的乐观 UI 行为描述（点击 → `this.isOn = !this.isOn` → 调 `onToggle`）并未涉及 `await`，意味着组件不会等待 onToggle 完成，乐观 UI 与回滚逻辑无法在组件内部完成（task 第 214 行也明确写"本组件仅做状态翻转与回调通知"）。
  - 若按 `(targetState: boolean) => void`：与设计文档决策 7（异步控制状态闭环确认）冲突——父 Page 层 ControlPage 需在 `onToggle` 内部完成 `CommandService.send()` + 1s 轮询 5 次确认的闭环。
- **期望修正方向**：
  - 统一采用 `onToggle?: (targetState: boolean) => Promise<void>`（与设计文档 §16 一致）
  - 明确 ControlButton 的语义边界：仅翻转 `@Link isOn` + 触发 `onToggle`，**不**等待 Promise 完成，**不**做失败回滚（回滚由父组件 `ControlPage` 通过修改 `isOn` 双向同步实现）
  - 删除第 213 行的 `previousState` 与第 235 行的 `@State private previousState: boolean`（task 第 206 行实际上已经删除了这个 state，但第 206-214 行的描述仍残留"previousState"概念），避免误导实现期。

---

### [一般] 4. `ChartView` 的 `Canvas` 重绘策略未给出"不响应数据变化"的明确兜底

- **位置**：`plan_task.md` 第 330-333 行
- **问题**：
  - "v1.0 折线图采用'绘制后不再响应数据变化'"——这意味着 `ChartView` 在 `onReady` 内首次绘制后，父组件传入新的 `data: SensorHistory[]` 时图表不会自动更新。
  - 第 333 行提到两种应对方案：
    1. "父组件以 `key` 强制重渲"
    2. "绘制结果缓存为 `@State pixelMap`"
  - 但 task 文档**未明确要求实现哪一种**，两种方案在 ArkTS 中的实现复杂度差异显著（方案 1 只需在父 Page 层加 `if (rebuildChart) { ChartView({ key: 'chart-' + timestamp }) }`，方案 2 需要在 ChartView 内做 `onReady` → `setInterval` 重绘）。
- **影响**：实现期会自行选择其一，可能引入不必要复杂度（方案 2 增加 setInterval 与销毁风险），或需要父 Page 层做不直观的 `key` 强制重渲（方案 1 增加 R4 页面层负担）。
- **期望修正方向**：明确选定方案 1（父组件以 `key` 强制重渲），理由：
  - 符合"组件不持有异步副作用"的设计原则（`PollingManager` 已在父 Page 层管理）；
  - v1.0 仅静态绘制简单折线图，R3 内完全可以做到；
  - 后续如需响应式更新再升级到方案 2，避免 R3 过度设计。
  - 在 `ChartView` Props 中增加 `@State private rendered: boolean = false` 标记，配合 `aboutToAppear` 的 `this.rendered = false` + `onReady` 内 `this.rendered = true`，确保组件卸载/重挂时能正确重新绘制。

---

### [一般] 5. `PaginatedList` 的 `renderItem` 在 ArkTS 中无法使用普通函数签名

- **位置**：`plan_task.md` 第 228 行
- **问题**：
  - 当前写 `renderItem: (item: T, index: number) => void`，但在 ArkTS 中，组件 `@Builder` 函数不能作为参数传递到子组件——只能通过 `@BuilderParam` 装饰器接收父组件传入的 `@Builder` 函数。
  - task 第 228 行括号内注释"ArkUI 限制：`@BuilderParam` 或函数式回调"，但未在 Props 签名中正确使用 `@BuilderParam`。
- **影响**：直接写 `renderItem: (item: T, index: number) => void` 在 ArkTS strict 模式下**不是**合法的 `@Component` 装饰器参数类型，会导致 `tsc` 编译失败（"Property 'renderItem' cannot be a function type in a struct"）。
- **期望修正方向**：
  ```typescript
  @BuilderParam renderItem: (item: T, index: number) => void
  ```
  并在父 Page 层用 `@Builder` 函数传入（详见 R4 Page 层 task）。或在 R3 暂时省略 `renderItem` 参数，仅让 `PaginatedList` 渲染 `Text(JSON.stringify(item))` 占位——但这会让 R4 几乎要重写 PaginatedList 的渲染逻辑，不合理。
  - **建议方案**：R3 实现 `PaginatedList` 时采用 `@BuilderParam renderItem: (item: T, index: number) => void`，父 Page 在 R4 用 `@Builder function renderRecord(item: DiseaseRecord) { ... }` 传入。这样 R4 只需修改 Page 层调用方式，组件签名不变。

---

### [一般] 6. `SeverityBadge` 的 Props 类型与 R2 已固化 `DiseaseRecord.severity` 字段类型不一致

- **位置**：`plan_task.md` 第 99、219 行
- **问题**：
  - task 写 `severity: string`（`mild` / `moderate` / `severe` / 其它）。
  - R2 已固化的 `models.ets` 中 `DiseaseRecord.severity` 字段类型是 `string`（非联合类型），所以组件接收 `string` 是正确的。
  - 但 `SeverityBadge` 内部字符串映射（mild/moderate/severe 三色 + 其它灰色）依赖具体英文字符串匹配，与设计文档 §12 衍生定义不完全对齐。
- **影响**：实际实现中后端返回的 `severity` 字段值可能是中文（如"轻度"/"中度"/"重度"），也可能是英文——task 文档未约定。R3 实现期需自行假设一种匹配模式（如"轻度"/"中度"/"重度"），这与 `AlarmBanner` 的 `'mild' | 'moderate' | 'severe'` 严格匹配英文的约定**不一致**。
- **期望修正方向**：
  - 与 `AlarmBanner` 对齐，使用英文 `'mild' | 'moderate' | 'severe'` 作为 `severity` Props 类型（与 `AdvisoryDetection.severity: string` 一致，由父 Page 层做中英文转换）
  - 或：在 Props 注释中明确"传入英文 `mild/moderate/severe`，内部显示中文标签"。

---

### [一般] 7. `LoadingState` 的 `@Prop errorMessage?` 与设计文档不一致

- **位置**：`plan_task.md` 第 104、272 行
- **问题**：
  - task 写 `@Prop errorMessage?: string`，但同时又写"当 `status: 'error'` 时显示 `errorMessage` 文案"——意味着 `errorMessage` 必须配合 `status === 'error'` 使用。
  - 然而设计文档 §21（衍生）描述 `LoadingState` 接收 `errorMessage: string | null`（非可选，默认 `null`），且组件根据 `errorMessage` 自身判断是否显示错误 UI（而非依赖 `status` 字段）。
- **影响**：实现期会有两种解读：
  - 解读 1（task 当前写法）：`status` 决定渲染模式，`errorMessage` 仅在 `status === 'error'` 时使用
  - 解读 2（设计文档）：`status` 概念不存在，组件根据 `errorMessage` 是否为空判断显示哪种 UI
- **期望修正方向**：明确采用 task 的 `status: 'loading' | 'error' | 'empty'` 模式（更符合 ArkUI 状态机思维），但需在 Props 注释中写明"当 `status === 'error'` 时，`errorMessage` 必须提供；否则显示通用错误文案"。

---

### [一般] 8. `ControlButton` 的 `@Link isOn` 决策与设计文档决策 4 一致性需在 task 中显式说明

- **位置**：`plan_task.md` 第 75-77、199-214 行
- **问题**：
  - task 第 78 行写"使用 `@Link` 而非 `@Prop`（理由见 design 决策 4）"，但**未在 Props 注释中直接说明 `@Link` 带来的运行时约束**（如父组件必须用 `$isOn` 语法传递 `@State isOn`）。
  - 实现期如果父 Page 层使用 `@Prop` 接收 `ControlButton`（而不是 `@State`），会导致 `Cannot use @Link without parent's @State binding` 编译错误。
- **影响**：R4 的 `ControlPage` 实现时可能误用，导致 ControlButton 编译失败——但 R4 任务尚未规划。
- **期望修正方向**：
  - 在 task 的 `ControlButton.ets` 描述中增加"**父组件约束**：父 Page 持有 `@State isOn: boolean`，通过 `ControlButton({ isOn: $isOn, ... })` 传递"
  - 明确列出 R4 实施 ControlPage 时的注意事项（如 `ControlPage` 的 `ControlButton` 实例必须包裹在 `@State isOn` + `aboutToAppear` 中初始化为 `getCachedDevices(selectedDeviceId).find(...)?.online ?? false`）。

---

### [一般] 9. 12 个组件一次性实现的粒度过大，建议拆分

- **位置**：`plan_task.md` 第 283-286 行（"组织方式"）与第 116-118 行（"R3 实现后必须能通过 ArkTS 编译"）
- **问题**：
  - 一次性新建 12 个组件文件，且其中 `ChartView` / `LineChartRenderer` / `BarChartRenderer` 涉及 Canvas API（需补 stub），`ImageViewer` 涉及 ImageKit（需补 stub），`PaginatedList` 涉及 `@BuilderParam`（ArkTS 严格模式陷阱），`ControlButton` 涉及 `@Link` + 父组件约束。
  - 这些风险点分散在 5+ 个文件中，如一次性提交，单点失败将导致整轮编译失败，无法定位问题。
  - 计划文件 `plan.md` 第 36 行明确："限度控制：一次不要实现过多内容，以保证完成质量和便于测试"。
- **影响**：
  - 实施时间可能被拉长（需逐一排查 12 个文件的错误）
  - 单轮失败可能掩盖真实问题（如 stub 缺失 vs 接口错误）
  - 测试验证阶段无法针对性覆盖（无单元测试）
- **期望修正方向**：建议拆分为两批：
  - **R3a 基础组件**（6 个，零外部依赖、零 Canvas 风险）：
    - `SeverityBadge`、`AlarmBanner`、`ConnectivityIndicator`、`LoadingState`、`SensorCard`、`DeviceSelector`
    - 仅依赖 `common/models` + `common/utils` + `AppStorage`
    - 一次性完成 + 编译通过
  - **R3b 进阶组件**（6 个，含 Canvas/ImageKit/BuilderParam 风险）：
    - `ChartView`、`LineChartRenderer`、`BarChartRenderer`、`ControlButton`、`PaginatedList`、`ImageViewer`
    - 补全 `@kit.ImageKit` stub 与 Canvas stub 后一次性完成
  - 拆分理由：R3a 编译通过后再实施 R3b，避免"stub 缺失 + 接口错误"混杂在同一轮错误日志中。

---

### [一般] 10. `tsconfig.json` 的 `include` 范围未覆盖 `components/` 目录

- **位置**：`/tmp/arkts-check/tsconfig.json` 第 15-21 行
- **问题**：
  - 当前 tsconfig.json 的 `include` 仅覆盖 `src-ts/common/**` / `src-ts/services/**` / `src-ts/entryability/**`，未覆盖 `src-ts/components/**`。
  - 即使实现期按 R1 / R2 流程将 `components/*.ets` 复制到 `/tmp/arkts-check/src-ts/components/`，tsc 也不会检查这些文件。
- **影响**：如未在实施前更新 tsconfig.json，编译验证将"误判通过"——所有 12 个组件即使有类型错误也不会被 tsc 捕获。
- **期望修正方向**：在 task 中明确"验证策略"第 1 步（`plan_task.md` 第 308 行）必须先更新 tsconfig.json 的 `include`，加入 `"src-ts/components/**/*.ts"` 后再运行 `tsc --noEmit -p .`。

---

### [轻微] 11. `DeviceSelector` 的 `AppStorage.selectedDeviceId` 初始化与 task 描述不完整

- **位置**：`plan_task.md` 第 66-68、183-185 行
- **问题**：
  - task 第 183 行写"`aboutToAppear`：`AppStorage.setOrCreate('selectedDeviceId', '')` 初始化；若已存在有效值则同步到 `selectedIndex`"
  - 但 task 第 183 行未说明：**当 `selectedIndex` 变化时**，父组件如何感知（是否需要在父 Page 层使用 `@StorageLink('selectedDeviceId') selectedDeviceId: string` 绑定？）
  - 这是设计文档决策 5 的核心——但 task 文档未引用该决策。
- **影响**：父 Page 层（特别是 `Index.ets` 与 `DashboardPage.ets`）需要知道 `DeviceSelector` 是单向写 AppStorage 还是双向同步。task 当前描述会让实现者困惑。
- **期望修正方向**：在 `DeviceSelector` 描述中明确"本组件仅向 `AppStorage.set('selectedDeviceId', deviceId)` 写入；父 Page 层使用 `@StorageLink('selectedDeviceId')` 双向绑定监听变化"。

---

### [轻微] 12. `ImageViewer` 的 `imageId` 提取逻辑缺失

- **位置**：`plan_task.md` 第 87、253 行
- **问题**：
  - 设计文档 §19 第 386 行明确写："`imageId` 从 `image_path` 的文件名部分提取（如 `/images/2026/07/03/img_20260703_061500_021.jpg` 中提取 `img_20260703_061500_021`）"
  - 但 task 第 253 行仅写"主路径：...onError 时 `useFallback = true`（若 `imageId` 提供）"——未说明 `imageId` 是由父 Page 层传入，还是组件内部从 `imagePath` 提取。
  - 这两种实现策略在 task 层面有明显差异：
    - 策略 1（父 Page 提取）：Page 层做字符串处理后传入 `imageId`
    - 策略 2（组件自提取）：组件 `aboutToAppear` 中 `imageId = this.imagePath.split('/').pop().replace(/\.[^.]+$/, '')`
- **影响**：实现期有歧义。
- **期望修正方向**：明确采用策略 1（父 Page 层提取），理由：
  - 组件职责单一（仅消费 props，不做字符串解析）
  - 父 Page 层在 `loadData()` 回调中已有 `DiseaseRecord.image_path`，可顺便提取
  - 避免组件内部引入字符串正则依赖（ArkTS 标准库对正则支持有限）

---

### [轻微] 13. `BarChartRenderer` 的"占位"语义在 task 文档中表述模糊

- **位置**：`plan_task.md` 第 14、173-176 行
- **问题**：
  - 第 173 行写"`render` 方法**不**抛错，正常返回（绘制空 canvas 或 'Bar chart coming soon' 文字）"
  - "或"字让实现者困惑：到底是绘制空 canvas 还是绘制文字？
- **影响**：虽然不影响编译，但实现风格不统一。
- **期望修正方向**：明确为"绘制空 canvas（不绘制任何元素，直接 return）"——更符合"占位"语义，且不引入硬编码英文字符串（ArkUI 不支持 i18n 简便切换）。

---

### [轻微] 14. `ImageViewer` 的 `image.PixelMap` 在 ArkTS 中为同步还是异步未明确

- **位置**：`plan_task.md` 第 254 行
- **问题**：
  - `image.createImageSource(buf).createPixelMap()` 的 `createPixelMap()` 方法在 HarmonyOS API 中**默认返回 `Promise<PixelMap>`**（异步），但 task 第 254 行写"赋给 `pixelMap`"未明确是否需要 `await`。
  - 如未 `await` 直接赋值，`pixelMap: PixelMap | null` 会变为 `Promise<PixelMap> | null`——类型不匹配。
- **影响**：实现期可能在 aboutToAppear 的 async 函数中遗漏 `await`，导致运行时渲染失败（PixelMap 始终为 Promise 对象）。
- **期望修正方向**：在 task 中明确"`createPixelMap()` 是异步方法，必须 `await` 后再赋值给 `@State pixelMap`"。

---

## 修改要求

### 必须修正（严重）

1. **统一 `PaginatedList.loadPage` 返回结构**：采用 `{ records: T[], total: number }`，组件内基于 `items.length < total` 判定 `hasMore`。删除 task 第 227 行的 `{ records: T[], hasMore: boolean }` 描述。
2. **补全 `@kit.ImageKit` stub**：要求实现前在 `/tmp/arkts-check/stubs/kit-image.d.ts` 新增 stub，声明 `image.PixelMap` / `image.ImageSource` / `image.createImageSource(buf).createPixelMap()` 为 `Promise<PixelMap>`。删除 task 第 337 行"需在验证阶段补全"的模糊表述，改为"实施前必须补全"。
3. **统一 `ControlButton.onToggle` 回调签名**：采用 `(targetState: boolean) => Promise<void>`，删除第 206 行 `@State private previousState` 相关描述，明确 ControlButton 仅翻转 + 触发回调，不做回滚（回滚由父组件通过 `$isOn` 双向同步实现）。

### 应当修正（一般）

4. **明确 `ChartView` 重绘策略**：选定"父组件以 `key` 强制重渲"方案，并删除方案 2 的描述。
5. **`PaginatedList.renderItem` 改用 `@BuilderParam`**：修正为 `@BuilderParam renderItem: (item: T, index: number) => void`，并在 Props 注释中说明父 Page 层需用 `@Builder` 函数传入。
6. **`SeverityBadge` Props 类型与 `AlarmBanner` 对齐**：使用 `'mild' | 'moderate' | 'severe'` 联合类型，并在内部映射中文标签。
7. **`LoadingState.errorMessage` Props 注释**：明确"当 `status === 'error'` 时必须提供 `errorMessage`"。
8. **`ControlButton` 父组件约束说明**：在 Props 注释中增加"父组件必须用 `@State isOn: boolean` + `ControlButton({ isOn: $isOn, ... })` 传递"。
9. **拆分 R3 为 R3a（基础组件 6 个）+ R3b（进阶组件 6 个）**：避免单轮 12 文件 + stub 缺失的复合风险。
10. **`tsconfig.json` include 范围扩展**：明确"验证策略第 1 步必须先更新 tsconfig.json 加入 `src-ts/components/**/*.ts`"。

### 建议改进（轻微）

11. **`DeviceSelector` 描述补充**：明确"本组件仅写 AppStorage，不读 AppStorage；父组件用 `@StorageLink` 监听"。
12. **`ImageViewer.imageId` 来源**：明确"由父 Page 层从 `DiseaseRecord.image_path` 提取后传入，组件不做字符串解析"。
13. **`BarChartRenderer` 占位语义**：明确为"绘制空 canvas（直接 return）"。
14. **`ImageViewer.createPixelMap()` 异步语义**：明确"必须 `await`"。

---

## 附加说明

### R1/R2 引用验证

- ✅ `BASE_URL` 与 `HEADER_KEY` 均从 `HttpClient.ets` 导出（`plan_task.md` 第 119 行引用准确）
- ✅ `ImageService.getImagePixelMap(path)` 签名一致（`plan_task.md` 第 125 行引用准确）
- ✅ `SensorHistory` / `DeviceInfo` / `DiseaseRecord` 等类型定义一致
- ✅ `utils.parseAlarmFlag` / `utils.formatTimestamp` / `nowMs` 签名一致
- ✅ `HttpClient.get<T>` / `post<T>` / `getRaw` 签名一致
- ✅ 错误码 `ERR_CODE_DEVICE_OFFLINE` 常量名一致
- ✅ 缓存键前缀常量名一致

### 不在本轮范围（验证通过）

- ✅ pages 层（4 个 Page）明确划定留待 R4（第 365-374 行）
- ✅ 单元测试明确划定留待独立轮次（第 371 行）
- ✅ ImageViewer 主路径具体网络联调划定留待后续（第 372 行）
- ✅ LineChartRenderer 触摸交互划定留待后续（第 373 行）
- ✅ BarChartRenderer 实际柱状渲染划定留待后续（第 374 行）

### 已知约束覆盖验证

- ✅ ArkTS 装饰器约束（第 315-318 行）：正确列举了装饰器仅用于 struct 内的约束
- ✅ Canvas 重绘策略约束（第 330-333 行）：已识别但方案不明确（见 [一般] 4）
- ✅ ImageService 依赖（第 335-337 行）：已识别但 stub 缺失未解决（见 [严重] 2）
- ✅ AppStorage 初始化（第 339-341 行）：已识别但语义描述不完整（见 [轻微] 11）
- ⚠️ `tsconfig.json` 更新：未提及（见 [一般] 10）

---

## 总结

R3 任务整体规划合理，12 个组件的职责划分与依赖方向与设计文档对齐。**主要问题集中在三方面**：

1. **细节前后不一致**（3 处严重问题）：`PaginatedList.loadPage`、`ControlButton.onToggle` 的签名在 task 文档内部有矛盾，需统一
2. **stub 缺失未前置处理**：`@kit.ImageKit` stub 缺失会直接导致 `ImageViewer` 编译失败
3. **任务粒度过大**：12 个组件一次性实施的风险点过于分散，建议拆分 R3a/R3b

**通过条件**：修正上述 3 个严重问题 + 至少 5 个一般问题后可批准。