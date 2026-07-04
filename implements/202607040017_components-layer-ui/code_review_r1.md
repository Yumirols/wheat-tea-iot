# 代码审查报告（R3 r1）

## 审查结果

APPROVED

## 发现

本次审查对 R3 Coder 实现的全部 12 个 UI 组件进行了逐文件审查，对照 `design_spec.md`（R3 DR=2 修订）逐条验证。

### 1. 完整性验证

全部 12 个组件文件均已实现并就位于 `harmony-app/entry/src/main/ets/components/`：

| # | 组件 | 文件路径 | @Component | @Prop | @State | @Link | @BuilderParam |
|---|------|---------|-----------|-------|--------|-------|---------------|
| 1 | SeverityBadge | SeverityBadge.ets | 1 | 1 | 0 | 0 | 0 |
| 2 | AlarmBanner | AlarmBanner.ets | 1 | 4 | 0 | 0 | 0 |
| 3 | LoadingState | LoadingState.ets | 1 | 3 | 0 | 0 | 0 |
| 4 | SensorCard | SensorCard.ets | 1 | 5 | 0 | 0 | 0 |
| 5 | DeviceSelector | DeviceSelector.ets | 1 | 1 | 1 | 0 | 0 |
| 6 | ChartView | ChartView.ets | 1 | 4 | 0 | 0 | 0 |
| 7 | LineChartRenderer | LineChartRenderer.ets | 1 | 3 | 1 | 0 | 0 |
| 8 | BarChartRenderer | BarChartRenderer.ets | 1 | 3 | 1 | 0 | 0 |
| 9 | ControlButton | ControlButton.ets | 1 | 2 | 2 | 1 | 0 |
| 10 | PaginatedList | PaginatedList.ets | 1 | 2 | 4 | 0 | 1 |
| 11 | ImageViewer | ImageViewer.ets | 1 | 2 | 2 | 0 | 0 |
| 12 | ConnectivityIndicator | ConnectivityIndicator.ets | 1 | 1 | 0 | 0 | 0 |

装饰器使用统计完全符合设计规格：
- `@Component`: 12 个（全覆盖）
- `@Link`: 1 个（仅 ControlButton.isOn）
- `@BuilderParam`: 1 个（仅 PaginatedList.renderItem）
- `@Watch`: 0 个（符合"本轮不使用 @Watch"声明）

### 2. Props/State 接口与 design_spec 一致性

逐文件核对结果：

- **[SeverityBadge]** `@Prop severity: string` 与设计一致；颜色三色 + 灰色兜底逻辑完整
- **[AlarmBanner]** `@Prop message` / `severity` / `onClose?` / `onTap?` 与设计一致；`message === ''` 跳过渲染逻辑正确实现
- **[LoadingState]** `@Prop status` / `errorMessage` / `onRetry?` 与设计一致；三态分支完整，错误态空字符串兜底 `'加载失败，请重试'` 已实现
- **[SensorCard]** 五个 `@Prop` 与设计完全一致；`import { formatTimestamp } from '../common/utils'` 正确；`timestamp === ''` 显示 `'--'` 已实现；告警色判断 `alarmLabels.length > 0` 正确
- **[DeviceSelector]** `@Prop devices: DeviceInfo[]` + `@State selectedIndex` 与设计一致；`aboutToAppear` 中 `AppStorage.setOrCreate` + 持久值读取同步 `selectedIndex` 完整实现
- **[ChartView]** `@Prop chartType: 'line' | 'bar' = 'line'` / `dataPoints: number[]` / `width = 360` / `height = 200` 默认值正确
- **[LineChartRenderer]** `@Prop data` / `width = 360` / `height = 200` + `@State isReady` 与设计一致
- **[BarChartRenderer]** 同 LineChartRenderer；占位实现为 `ctx.fillText('BarChart v1.0 placeholder', 10, height/2)`，与设计规格明确选择一致
- **[ControlButton]** `@Link isOn: boolean` + `@Prop label` + `@Prop onToggle` + `@State previousState` + `@State isPending` 与设计完全一致
- **[PaginatedList]** `@BuilderParam renderItem` + `@Prop loadPage` + `@Prop pageSize = 20` + 4 个 `@State` 与设计一致；泛型 `<T>` 语法正确
- **[ImageViewer]** `@Prop imagePath` / `imageId` + `@State pixelMap: image.PixelMap | null` + `@State loadStatus` 与设计一致；强类型 `image.PixelMap` 与 stub 同步
- **[ConnectivityIndicator]** `@Prop status: ConnectivityStatus = 'loading'` 与设计一致；width `'100%'` + height `4` 单位约定正确

### 3. R1/R2 上游层零修改验证

`git status --short` 与 `git diff main --stat` 结果显示：
- `common/*.ets`：未修改（R1 固化）
- `services/*.ets`：未修改（R2 固化）
- `entryability/EntryAbility.ets`：未修改（R1 固化）
- `pages/Index.ets`：未修改（保持 Hello World 模板）

git 工作树中仅 `implements/requirement.md` 有非组件修改（与本次任务无关），`components/` 目录与 `code_report.md` 为新增文件。

### 4. Canvas 渲染策略验证

- **[LineChartRenderer]** `onReady` 回调中一次性调用 `drawChart`；实现包含空数组防御（`if (data.length === 0) return;`）、清空画布、X/Y 轴绘制、归一化（`range = max - min || 1`）、折线段绘制完整流程
- **[BarChartRenderer]** `onReady` 回调中调用 `drawBars`，仅实现文字占位 `ctx.fillText('BarChart v1.0 placeholder', 10, height/2)`，与设计规格明确选择一致（文字占位而非矩形柱）
- 两个组件均无 `@Watch` 数据变更监听，依赖父组件 `key` 强制重建策略（与设计规格 v1.0 限制声明一致）

### 5. AppStorage 双向同步（DeviceSelector）

- `aboutToAppear` 中先 `AppStorage.setOrCreate('selectedDeviceId', '')`（不覆盖已有值）→ 读取 `AppStorage.get<string>('selectedDeviceId')` → 按 `device_id` 匹配索引后同步 `selectedIndex`
- `onSelect(index, value)` 中 `this.selectedIndex = index` + `AppStorage.set('selectedDeviceId', value)`，正确使用 ArkUI 提供的 `value` 参数直接写入
- 消除了二次启动 UI 与持久化撕裂（R3 r1 #2 审查意见已闭合）

### 6. @Link 双向绑定（ControlButton）

- `@Link isOn: boolean` + `@State previousState` + `@State isPending` 实现乐观 UI
- 注释明确说明父组件必须用 `@State isOn: boolean` 持有，给出父组件用法示例（`$isSprayOn` 语法）
- `handleToggle` 实现：记录 `previousState` → 乐观翻转 → 异步调用 → 失败回滚 → `finally` 释放 `isPending`
- 完整覆盖设计规格 6 步行为契约

### 7. ImageViewer 主路径/降级路径边界

- 主路径：`<Image src={BASE_URL + imagePath}>` 直连，`onError(_event?: object): void` 触发降级（与设计规格 #5 一致）
- 降级路径：`fallbackToPixelMap` 中 `ImageService.getImagePixelMap` → `ArrayBuffer` → `image.createImageSource(buf)` → `source.createPixelMap()` → `@State pixelMap` 更新
- 三态加载：`idle` / `loading` / `loaded` / `error` 清晰分离
- 主路径失败 → 降级路径加载中 → 降级路径成功展示 → 降级路径失败显示占位，边界完整

### 8. 错误处理与边界场景

逐组件核对：
- **SeverityBadge**：未知 `severity` 值走灰色兜底，文字回显原字符串
- **AlarmBanner**：`message === ''` 跳过渲染；未知 `severity` 走灰色兜底；`onClose` / `onTap` 使用可选链 `?.()` 安全调用
- **LoadingState**：`errorMessage === ''` 兜底 `'加载失败，请重试'`；`onRetry` 可选链调用
- **SensorCard**：`timestamp === ''` 显示 `'--'`；`alarmLabels` 默认 `[]`；`value === 0` 直接显示（合法传感器值）
- **DeviceSelector**：`devices.length === 0` 时 `findIndex` 返回 -1，`selectedIndex` 保持初始 0；AppStorage 持久值不在列表中也保持 0
- **ControlButton**：`onToggle` 抛错回滚 `previousState` + `console.error` + 释放 `isPending`
- **PaginatedList**：`loadPage` 抛错 `console.error` + 保留已有数据；`isLoading` 守卫避免重复触发
- **LineChartRenderer**：空数组防御（`data.length === 0` 直接 return，避免 `Math.min(...[])` 返回 `Infinity`）
- **ImageViewer**：主路径 `onError` 切换降级；降级路径 `createPixelMap` 抛错显示"图片加载失败"

### 9. 命名风格与注释质量

- 组件 `struct` 名统一 PascalCase（`SeverityBadge`, `AlarmBanner` 等）
- Props/State 变量统一 camelCase（`selectedIndex`, `previousState`, `loadStatus` 等）
- 内部状态变量无 `_` 前缀（符合 ArkTS 风格）
- 全部 12 个组件均通过 `export { ComponentName }` 形式导出
- 每个组件顶部均有完整中文文档注释，包含 Props 说明、行为契约、父组件约束、依赖说明
- 关键方法（`drawChart` / `loadNextPage` / `handleToggle` / `fallbackToPixelMap`）均有 JSDoc 注释

### 10. 依赖关系

逐文件导入检查：
- `SeverityBadge` / `AlarmBanner` / `LoadingState`：零导入（仅用 ArkUI 内置组件）
- `SensorCard`：`import { formatTimestamp } from '../common/utils'`
- `DeviceSelector`：`import { AppStorage } from '@kit.ArkUI'` + `import { DeviceInfo } from '../common/models'`
- `ChartView`：`import { LineChartRenderer } from './LineChartRenderer'` + `import { BarChartRenderer } from './BarChartRenderer'`
- `LineChartRenderer` / `BarChartRenderer`：零导入（仅用 Canvas + CanvasRenderingContext2D）
- `ControlButton`：零导入（仅用 Button）
- `PaginatedList`：`import { PaginatedData } from '../common/models'`
- `ImageViewer`：`import { image } from '@kit.ImageKit'` + `import { ImageService } from '../services/ImageService'` + `import { BASE_URL } from '../services/HttpClient'`
- `ConnectivityIndicator`：`import { ConnectivityStatus } from '../common/models'`

无循环引用；仅 `ChartView → LineChartRenderer/BarChartRenderer` 与 `ImageViewer → services` 两条跨文件依赖，均为单向。

依赖层级符合设计规格：
- 5 个 R3a 组件仅依赖 `common/` + `@kit.ArkUI`
- 7 个 R3b 组件中 6 个仅依赖 `@kit.ArkUI` + `common/`，仅 `ImageViewer` 依赖 `services/` + `@kit.ImageKit`

### 11. tsc strict 验证真实性

通过注入对照实验确认 tsc 验证真实有效：
1. 在 `DeviceSelector.ts` 中将 `d.device_id === stored` 改为 `=== (stored as number)` → tsc 报错 TS2367（types 'string' and 'number' have no overlap）→ 确认类型检查生效
2. 在 `SeverityBadge.ts` 中添加 `badReference: string = this.severity as any;` → tsc 报错 TS2729（used before its initialization）→ 确认 strict mode 生效
3. 恢复后 `tsc --noEmit -p .` exit 0 → 全部 12 个组件通过 strict 类型检查

注意事项（不构成问题）：
- `transform.py` 将 `build() { ... }` body 替换为 `return null as any`，因此 UI DSL 语法（如 `Row() { Text('...') }`）未被 tsc 直接检查
- `@Prop` / `@State` / `@Link` 等装饰器在 stub 中为 no-op 函数，字段类型标注的语义正确性需真实 ArkTS 编译器（hvigorw）验证
- `PaginatedList<T>` 泛型约束在 stub 装饰器模型下未被严格 enforce（`build()` body 被替换），需 hvigorw 验证泛型实例化

这些限制在 `design_spec.md` 与 `code_report.md` 中均已明确声明，与 R2 等价验证策略一致。

### 12. 设计偏差评估

`code_report.md` 中声明的偏差均合理且已文档化：

| 偏差 | 评估 |
|------|------|
| 验证目录从 `/tmp/arkts-check/` 改为 `E:/tmp/arkts-check2/` | 合理（避开 sandbox 文件回滚） |
| stub 组件类既在 `declare module '@kit.ArkUI'` 内 export 又在外补全 `declare class` | 合理（JSX 全局识别需要） |
| `strictPropertyInitialization: false` | 合理（ArkTS 装饰器语义误报） |

这些偏差均不违反设计规格的核心要求（"tsc strict 模式类型检查通过"），且明确说明了原因。

### 审查结论

本次实现完整覆盖了 design_spec.md 中全部 12 个 UI 组件的设计规格，Props/State 接口与设计完全对齐，ArkTS 装饰器使用合规（`@Component` 12 次、`@Link` 1 次仅 ControlButton、`@BuilderParam` 1 次仅 PaginatedList、无 `@Watch`），R1/R2 上游层零修改，Canvas 一次性绘制与父组件 key 重建策略正确，AppStorage 双向同步方案完整，`@Link` 双向绑定 + 乐观 UI 回滚正确实现，ImageViewer 主路径/降级路径边界清晰，错误处理覆盖各组件边界场景，依赖关系无循环引用，tsc strict 模式验证真实通过。

实现质量符合 R3 交付标准，予以 APPROVED。