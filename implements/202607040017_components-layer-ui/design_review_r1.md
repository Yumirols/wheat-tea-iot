# 设计审查报告（R3 r1）

## 审查结果

REJECTED

## 发现

### [严重] 1. `ImageViewer` 中 `Image(pixelMap)` 类型与 ArkUI `Image.src` 签名不兼容

- **位置**：`design_spec.md` 第 689、698-699、711-712 行
- **问题**：
  - 设计将 `@State pixelMap: object | null` 与 `source: object` 标注为弱类型，并在"风险与边界声明"第 1128 行承认"由于 `@kit.ImageKit` 的 `PixelMap` 类型在 stub 中暂以 `object` 表示；R3b 实施时逐步精化"。
  - ArkUI `<Image>` 组件的 `src` 参数签名是 `ResourceStr | PixelMap`（不接受 `object`）。当 R3b 阶段把 stub 精化为 `export interface PixelMap { ... }`（非 `object`），`Image(this.pixelMap)` 调用将因类型不匹配报"不能将 `PixelMap | null` 赋给 `ResourceStr | PixelMap`"——不对，因为 `PixelMap` 是 `ResourceStr | PixelMap` 的合法成员。**但** `source.createPixelMap()` 的返回类型 `object` 与 `Image` 期望的 `PixelMap` 不同：把 `object` 类型变量赋给 `@State pixelMap: object | null` 可以，但赋值给 `PixelMap | null` 不行。
  - 真实风险在于 `source.createPixelMap()` 的返回值是 `object`（按设计当前标注），如果未来 stub 精化为 `Promise<PixelMap>`，而 `pixelMap` 仍声明为 `object | null`，赋值路径 `this.pixelMap = pm` 会因 `pm: PixelMap` 不能赋给 `pixelMap: object | null` 而报错。
  - 反向风险：如果把 `pixelMap` 声明为 `PixelMap | null`，而 stub 当前为 `object`，则 `this.pixelMap = pm`（`pm: object`）不能赋给 `pixelMap: PixelMap | null` 报错。
  - 总之：当前 `object` 弱类型方案与 stub 精化路径**双向不兼容**，需要明确一种最终类型并贯穿。
- **影响**：R3b 实施时 stub 精化将导致 ImageViewer 不能通过 tsc strict 检查，需要回头修改组件代码。设计未给出从 `object` 迁移到 `PixelMap` 的过渡方案。
- **期望修正方向**：
  - 明确 `pixelMap: PixelMap | null`（与 R3b stub 同步声明）；
  - 或在 R3a 阶段同步创建 `kit-image.d.ts` stub（哪怕占位），声明 `PixelMap` 接口（含 R3b 设计要求的 `getPixelBytes()` 等方法）；
  - 同步把 `source: PixelMap`、`createPixelMap(): Promise<PixelMap>` 类型标注统一，避免中间态出现 `object`。

### [严重] 2. `DeviceSelector` `selectedIndex` 初始值与 AppStorage 持久值不一致

- **位置**：`design_spec.md` 第 332-342 行（DeviceSelector 实现要点）、第 359-369 行（行为契约）
- **问题**：
  - 设计明确："`selectedIndex` 始终初始为 0"，"**不**从 AppStorage 读取 existing 值同步到 `selectedIndex`"。
  - 但 AppStorage 在用户切换设备后已持久化 `selectedDeviceId`。
  - **第二次启动场景**：App 启动 → DashboardPage 加载 → DeviceSelector `aboutToAppear` 调用 `AppStorage.setOrCreate('selectedDeviceId', '')`（setOrCreate 不覆盖已有值）→ AppStorage 保留之前的 deviceId → 但 UI 显示 `selectedIndex = 0`（第一台设备，可能与之前选中的不是同一台）。
  - 这造成 UI 显示与实际选中设备的"撕裂"：用户看到第一台设备的 SensorCard 在更新，但 AppStorage 里的 `selectedDeviceId` 是另一台，导致父 Page 层 `@StorageLink('selectedDeviceId')` 触发的 Service 调用拉取了非 UI 显示设备的数据。
  - 设计用 "**避免 AppStorage 反向同步导致 selectedIndex 抖动**" 作为理由，但实际效果是制造了**反向撕裂**：UI 不跟随持久化状态。
  - 正确设计应是：AppStorage 已有值时 → `selectedIndex = devices.findIndex(d => d.device_id === AppStorage.get('selectedDeviceId'))`（找不到则 0）；AppStorage 为空时 → `selectedIndex = 0`。
- **影响**：第二次启动后用户看到错误设备的数据刷新，体验严重割裂。R4 Page 层 SensorCard 显示设备 A，但 AppStorage 驱动的是设备 B 的请求。
- **期望修正方向**：
  - 在 `aboutToAppear` 中读取 AppStorage 持久值（`AppStorage.get<string>('selectedDeviceId')`）并同步到 `selectedIndex`：
    ```typescript
    aboutToAppear() {
      AppStorage.setOrCreate('selectedDeviceId', '');
      const stored: string | undefined = AppStorage.get<string>('selectedDeviceId');
      if (stored !== undefined && stored !== '') {
        const idx: number = this.devices.findIndex((d: DeviceInfo) => d.device_id === stored);
        if (idx >= 0) { this.selectedIndex = idx; }
      }
    }
    ```
  - 或者放弃 "不读 AppStorage" 的设计原则，在 onSelect 时同时写 AppStorage 和 `selectedIndex`，并在 aboutToAppear 中初始化一次 `selectedIndex`。
  - 关键是：UI 状态与持久化状态必须一致。

### [一般] 3. `PaginatedList` `@BuilderParam` 类型签名与 ArkTS 实际用法存在歧义

- **位置**：`design_spec.md` 第 611-612 行（PaginatedList Props）
- **问题**：
  - 设计声明：`@BuilderParam renderItem: (item: T, index: number) => void;`
  - ArkTS 官方 `@BuilderParam` 的设计意图是接收父组件的 `@Builder` 方法引用。虽然 ArkTS 允许 `@BuilderParam` 声明为函数类型，**但**当父组件传入普通函数（非 `@Builder` 标注的方法）时，ArkUI 严格模式在编译期可能不接受。
  - 当前签名 `(item: T, index: number) => void` 是一个普通函数类型，并不显式表明该字段是 `@Builder` 引用。在 ArkTS strict 模式下，这会导致编译歧义。
  - 更重要的是：泛型组件 `PaginatedList<T>` 的 `@BuilderParam renderItem` 类型在 ArkTS 编译器中的处理路径未经验证——泛型与 `@BuilderParam` 装饰器组合可能触发编译器未知错误。
- **影响**：R3b 实施期编译失败，需要回退到具体类型或调整 `@BuilderParam` 用法。
- **期望修正方向**：
  - 明确父组件传入方式：要求父组件声明 `@Builder private renderItem(item: T, index: number): void { ... }` 然后传入 `<PaginatedList renderItem={this.renderItem} ... />`；
  - 或在 Props 注释中显式标注"父组件必须用 `@Builder` 修饰 renderItem 方法"；
  - 验证 ArkTS 编译器对泛型 `@BuilderParam` 的支持（参考 ArkTS 文档或 ArkTS Playground）；如不支持，回退到非泛型设计（父组件用 `as any` 转型）。

### [一般] 4. `ControlButton` `@Link isOn` 父组件约束未在 Props 注释中明确

- **位置**：`design_spec.md` 第 544-547 行（ControlButton Props）
- **问题**：
  - 设计声明 `@Link isOn: boolean`，但没有在 Props 说明中显式标注"**父组件必须用 `@State` 持有 isOn**"。
  - `@Link` 在 ArkTS 中的约束是：父组件传入 `@State` 变量（不能是 `@Prop` 或普通变量）。如果父组件误传 `@Prop isOn`，编译期会报"cannot find name 'isOn'"或"`@Link` cannot work with `@Prop`"错误。
  - 设计仅在"风险与边界声明"第 1124 行提到"`ControlButton` `@Link` 父组件需 `@State`——文档注释中明确；R4 Page 层 `isOn` 用 `@State` 持有"——但这是风险声明而非 Props 文档。
- **影响**：R4 Page 层开发者按 Props 表使用，遗漏 `@State` 要求，导致编译失败。需在 Props 注释中显式标注。
- **期望修正方向**：
  - 在 ControlButton Props 注释中明确："**父组件必须用 `@State isOn: boolean` 持有状态**（`@Link` 仅支持双向同步 `@State` 变量）"；
  - 与 SeverityBadge 等纯展示组件的 Props 注释风格保持一致（"父→子单向数据流" vs "父必须 `@State`"）。

### [一般] 5. `ImageViewer` 主路径 `onError` 回调签名与 ArkUI 标准不一致

- **位置**：`design_spec.md` 第 702 行
- **问题**：
  - 设计使用 `Image(...).onError(() => { this.fallbackToPixelMap(); });`
  - ArkUI `<Image>` 组件的 `onError` 回调标准签名是 `onError(callback: (event: object) => void)`（event 参数携带错误详情），**不是无参函数**。
  - 当前声明为无参 `() => void` 与 ArkUI 标准签名不匹配。stub 中如果按 ArkUI 真实签名声明 `onError(callback: (event?: object) => void)`，当前代码可以兼容；但如果 stub 严格为 `(event: object) => void`，则无参回调签名不匹配。
  - 此外，`onError` 是 attribute method（链式调用），`Image(src)` 后必须用 attribute chain（`.onError()`）——这部分设计正确。
- **影响**：取决于 stub 严格度，可能触发编译错误或运行时无错误回调。
- **期望修正方向**：
  - 明确 `onError` 回调签名：在 stub 中声明 `onError(callback: (event?: object) => void)` 或 `onError(callback: () => void)`；
  - 在 ImageViewer 设计中统一两种写法之一，建议 `() => void`（因为当前实现不需要 event 详情）。

### [一般] 6. `DeviceSelector` `onSelect` 回调签名中 `value` 参数与 ArkUI 实际签名不一致

- **位置**：`design_spec.md` 第 339-340 行
- **问题**：
  - 设计声明 `onSelect: (index: number, value?: string): void`（`value` 可选）。
  - ArkUI `<Select>` 组件 `onSelect` 回调的实际签名是 `(index: number, value: string) => void`（`value` 是必填的字符串）。
  - 设计把 `value` 标为可选（`value?: string`），与 ArkUI 真实签名不一致。stub 自身一致地按设计写成可选（plan_task.md stub 第 351 行），但这造成两个问题：
    1. 实际 ArkUI 中 `value` 必有值，可选标注无意义；
    2. 实施期若需消费 `value`（如直接写入 AppStorage 而不查 devices），当前实现 `AppStorage.set('selectedDeviceId', this.devices[index].device_id)` 是冗余的（直接用 `value` 即可）。
- **影响**：轻微设计冗余，不阻塞编译，但增加理解成本。
- **期望修正方向**：
  - 修正 stub 为 `onSelect(callback: (index: number, value: string) => void)`（value 必填）；
  - 组件实现可简化为 `onSelect: (index: number, value: string): void => { this.selectedIndex = index; AppStorage.set('selectedDeviceId', value); }`。

### [一般] 7. 编译验证基线路径约定与 tsconfig.json 不匹配

- **位置**：`design_spec.md` 第 1041-1063 行（编译验证基线）
- **问题**：
  - 第 1046 行 `cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/components/*.ets /tmp/arkts-check/src-ts/main/ets/components/`——4 层路径（`src-ts/main/ets/components/`）。
  - 第 1057 行 `for f in *.ets; do ... cp "$f" "$base.ts"; done` 在 `/tmp/arkts-check/src-ts` 下，但 `.ets` 文件位于 4 层子目录，循环不会遍历到 `components/*.ets`。
  - 实际 R2 的命令路径是 3 层（`src-ts/common/` 等），但 plan_review_r3 确认了 tsconfig 实际 include 是 4 层。
  - 第 1055 行 `for f in *.ets; do base=$(basename "$f" .ets); cp "$f" "$base.ts"; done`——如果当前目录是 `/tmp/arkts-check/src-ts`，`*.ets` 匹配的是根目录的 .ets，没有；要 `cd` 到 `main/ets/components/` 后再执行。
  - 派生 `.ts` 副本的 for 循环路径与 mkdir 路径、cp 路径不连续。
- **影响**：实施期按验证脚本逐字执行，会出现"找不到 .ets 文件"或派生 .ts 在错位置。
- **期望修正方向**：
  - 验证脚本明确每一步的工作目录：
    ```bash
    # 第 3 步：派生 .ts 副本（必须在 components 目录下执行）
    cd /tmp/arkts-check/src-ts/main/ets/components
    for f in *.ets; do base=$(basename "$f" .ets); cp "$f" "$base.ts"; done
    cd /tmp/arkts-check && tsc --noEmit -p .
    ```
  - 修正 design_spec 中派生步骤的 `cd` 路径，确保脚本完整可执行。

### [一般] 8. stub 模板中 `Select` / `Text` 等组件类在 `declare module` 外的声明与 tsc 解析路径不一致

- **位置**：`design_spec.md` 通过 plan_task.md 引用的 stub 模板（第 389-416 行，plan_task.md）
- **问题**：
  - plan_task.md stub 模板将 `Progress` / `Select` / `Text` / `Button` / `Row` / `Column` / `Stack` 等组件类放在 `declare module '@kit.ArkUI'` 块外，用全局 `declare class` 声明。
  - 这种声明方式在 TypeScript 中是全局可见的，但 ArkUI 的真实组件是通过 `import { Row, Column, ... } from '@kit.ArkUI'` 引入的——如果 tsc 解析时遇到未导入的全局 `declare class`，可能在 strict 模式下产生"implicit global type"的歧义错误。
  - design_spec 没有明确组件类的导入路径，但实际 .ets 文件中 `Row()` / `Column()` / `Text()` 等是**全局可用**的（ArkTS 编译器注入），不通过 import。如果 stub 写成全局 `declare class`，需要确认 tsc 在 strict 模式下不会因"未导入的全局类型"报错。
- **影响**：取决于 tsc 版本和 `experimentalDecorators: true` 的容忍度。
- **期望修正方向**：
  - 将所有组件类声明移入 `declare module '@kit.ArkUI'` 块内作为 `export class`；
  - 或保持全局声明但在 stub 顶部加 `declare global { ... }` 包裹。

### [轻微] 9. `ConnectivityIndicator` 高度单位混用字符串与数字

- **位置**：`design_spec.md` 第 770-771 行、第 788-797 行
- **问题**：
  - `.width('100%')` 使用字符串（百分比）；
  - `.height(4)` 使用数字（vp/px）。
  - ArkUI 同时接受两种形式（取决于属性），但混用降低代码一致性。
- **影响**：极轻微，不影响功能。
- **期望修正方向**：保持当前混用即可（百分比宽度 + 固定像素高度是合理搭配），仅在 Props 注释中说明设计选择（如"顶部细条固定 4px 高度，宽度自适应屏幕"）。

### [轻微] 10. `BarChartRenderer` 占位实现路径含糊（"占位文字" vs "2-3 根矩形柱"）

- **位置**：`design_spec.md` 第 521-525 行
- **问题**：
  - 设计说："渲染 'v1.0 柱状图占位' 文字（`ctx.fillText('BarChart v1.0 placeholder', ...)`）或渲染简单的 2-3 根矩形柱"。
  - 两种实现差异显著（文字 vs 图形），Coder 需自行选择。
- **影响**：Coder 实施期自行决定即可，不阻塞。
- **期望修正方向**：明确二选一（建议文字占位——更简洁、不需要绘制逻辑），去掉"或"分支。

### [轻微] 11. `PaginatedList` `currentPage` 起始值与 `loadNextPage` 递增逻辑存在 off-by-one 风险

- **位置**：`design_spec.md` 第 630-640 行
- **问题**：
  - `currentPage` 初始为 1，`loadNextPage` 调用 `this.loadPage(this.currentPage)` 后 `this.currentPage++`。
  - 第一次调用传 `1`，递增后变 2；
  - 第二次调用传 `2`（第二页）。
  - 这看起来正确，但设计没有说明后端分页是从 1 还是 0 开始。如果后端 API 是 0-indexed（如 `/disease/list?page=0`），首次传 1 会跳过第一页。
  - API 文档（3_client-api-reference.md）通常分页从 1 开始，但设计未引用此约束。
- **影响**：轻微，Coder 需自行验证。
- **期望修正方向**：在 Props 注释或行为契约中明确"currentPage 从 1 开始，与后端分页约定一致"。

### [轻微] 12. `LineChartRenderer` `data: number[]` 空数组的边界未约定

- **位置**：`design_spec.md` 第 432-433 行、第 466-469 行
- **问题**：
  - `data` 可能为空数组（首次加载未返回数据点）；
  - 绘制逻辑 `const min = Math.min(...data)` 在空数组下返回 `Infinity`，`Math.max(...data)` 返回 `-Infinity`，`range = Infinity - (-Infinity) = Infinity || 1 = Infinity`。
  - 后续 `moveTo` / `lineTo` 计算会产生 `Infinity` 坐标，Canvas 绘制异常。
- **影响**：边缘场景导致 Canvas 绘制错误。
- **期望修正方向**：在 `drawChart` 开头增加 `if (data.length === 0) { return; }` 防御。

### [轻微] 13. 设计 §组件级边界 SensorCard 描述中 `value === 0` 表述不严谨

- **位置**：`design_spec.md` 第 906-907 行
- **问题**：
  - 表述"`value === 0` → 正常显示'0'（非空判断）"——但 sensor 数据中 `value === 0` 是合法值（温度 0℃），不应被解释为"空"。
  - 这条注释的目的可能是"防止 `value === undefined` 时显示 undefined"，但 sensor 数据 `value: number` 总是数字。
- **影响**：无实际影响（注释解释而非行为约束），但措辞易误导。
- **期望修正方向**：删除该条目或改为"`value` 为合法 number → 直接显示（含 0）"。

## 修改要求

### 必须修正（严重）

1. **`ImageViewer.pixelMap` 类型与 ImageKit stub 同步**：明确 `pixelMap: PixelMap | null`（不是 `object | null`），并在 R3b 阶段提供完整的 `kit-image.d.ts` stub 模板（含 `PixelMap` 接口和 `createImageSource()` / `createPixelMap()` 完整签名），避免从 `object` 迁移到 `PixelMap` 时双向不兼容。

2. **`DeviceSelector.selectedIndex` 与 AppStorage 持久值一致性**：在 `aboutToAppear` 中读取 AppStorage 持久值并同步到 `selectedIndex`（按 device_id 匹配），不能永远从 0 开始。消除 UI 与 AppStorage 撕裂。

### 应当修正（一般）

3. **`PaginatedList` `@BuilderParam` 类型约束**：明确父组件必须用 `@Builder` 标注传入方法；提供父组件调用示例（`@Builder private renderItem(...)`）；验证 ArkTS 编译器对泛型 `@BuilderParam` 的支持。

4. **`ControlButton` Props 注释中明确父组件 `@State` 要求**：在 Props 注释里说明"父组件必须用 `@State isOn: boolean` 持有状态"，而不是仅写在风险声明里。

5. **`ImageViewer.onError` 回调签名与 stub 一致**：明确 `onError(callback: () => void)` 或 `onError(callback: (event?: object) => void)`，与 stub 严格对齐。

6. **`DeviceSelector.onSelect` 回调 `value` 参数改为必填**：与 ArkUI 实际签名对齐，简化组件实现（直接用 `value` 写 AppStorage）。

7. **编译验证脚本路径修正**：在派生 `.ts` 副本步骤中明确 `cd /tmp/arkts-check/src-ts/main/ets/components`，确保脚本完整可执行。

8. **stub 组件类声明统一**：将 `Select` / `Text` / `Button` 等组件类统一在 `declare module '@kit.ArkUI'` 块内 `export class` 声明，避免全局声明歧义。

### 建议改进（轻微）

9. `ConnectivityIndicator` 高度/宽度单位混用——保留并加注释即可。

10. `BarChartRenderer` 占位实现二选一——明确选文字占位。

11. `PaginatedList.currentPage` 起始值引用 API 文档分页约定。

12. `LineChartRenderer.drawChart` 增加空数组防御。

13. 删除 `SensorCard` 边界"value === 0"歧义条目。

## 通过依据汇总

- **严重问题**：2 项（ImageViewer pixelMap 类型不兼容 + DeviceSelector 持久化撕裂）
- **一般问题**：6 项（PaginatedList 泛型 / ControlButton 父组件约束 / onError 签名 / onSelect 签名 / 验证脚本路径 / stub 组件类声明）
- **轻微问题**：5 项（不影响正确性）
- **通过条件**：修正 2 项严重 + 至少 4 项一般后可批准。

## r3 修订闭环验证

| # | r3 修订 | 验证结果 |
|---|--------|---------|
| 1 | kit-arkui.d.ts 补全模板 | 部分采纳——模板完整但未包含 `Canvas` / `CanvasRenderingContext2D` / `Image.onError` 等 R3b 类型声明 |
| 2 | tsconfig 路径 4 层修正 | 采纳——但 design_spec.md 编译验证脚本路径仍存在目录切换错误（见 [一般] 7） |
| 3 | AppStorage stub 声明 | 采纳——但 `DeviceSelector` 行为契约与持久化一致性有严重问题（见 [严重] 2） |
| 4-15 | 其余 12 项 | 均按 r3 修订执行，无遗留 |