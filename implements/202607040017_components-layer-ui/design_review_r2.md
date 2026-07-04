# 设计审查报告（R3 DR=2）

## 审查结果

APPROVED

## 发现

### [严重] 无

### [一般] 无

### [轻微] 1. 装饰器汇总表与 ControlButton 实际接口命名不一致

- **位置**：`design_spec.md` 第 63 行
- **问题**：装饰器使用策略汇总表声明 ControlButton 的 `@State` 字段为 `previousState/isLoading`，但 ControlButton 实际组件接口（第 559-560 行）声明的字段名为 `previousState/isPending`。表内 PaginatedList 的 `isLoading` 是正确的，ControlButton 的 `isLoading` 与实际命名 `isPending` 不一致。
- **影响**：纯文档性不一致，不影响实现——实际代码本身（第 559-560 行）定义明确且自洽，Coder 按组件章节实现即可，不会出错。汇总表属于全局策略索引，不会被编码直接消费。
- **是否阻塞**：否。此为纯粹的汇总表速记错误，可在下轮迭代中顺手修正（将第 63 行 ControlButton 条目改为 `previousState/isPending`），不影响本轮 R3 编码与编译验证。

## r1 遗留问题闭环验证

| r1 # | 严重度 | r1 审查意见 | DR=2 修订结果 | 验证 |
|------|--------|-------------|-------------|------|
| 1 | 严重 | ImageViewer pixelMap 类型与 stub 双向不兼容 | 改为 `@State pixelMap: image.PixelMap \| null`（第 726 行）；kit-image.d.ts stub 模板同步声明 `PixelMap` / `ImageSource` / `createImageSource` / `createPixelMap`（第 1171-1188 行） | 已闭合 |
| 2 | 严重 | DeviceSelector selectedIndex 与 AppStorage 撕裂 | aboutToAppear 中增加 `AppStorage.get<string>('selectedDeviceId')` 读取并按 device_id 匹配索引同步 selectedIndex（第 335-341 行）；onSelect 中 `value: string` 必填直接写入 AppStorage（第 347 行） | 已闭合 |
| 3 | 一般 | PaginatedList @BuilderParam 父组件约束未明确 | Props 注释明确"必须使用 @Builder 修饰方法后传入"（第 674 行）；提供父组件调用示例代码（第 676-685 行）；增加泛型 @BuilderParam ArkTS 兼容性回退方案说明（第 695 行） | 已闭合 |
| 4 | 一般 | ControlButton @Link 父组件约束未标注 | Props 注释追加"父组件必须用 @State isOn: boolean 持有该变量"（第 586 行）；给出父组件用法示例（第 588-592 行） | 已闭合 |
| 5 | 一般 | ImageViewer onError 回调签名与 stub 不一致 | 改为 `.onError((_event?: object): void => { this.fallbackToPixelMap(); })`（第 739 行）；stub 补全清单注明 `Image.onError(callback: (event?: object) => void)`（第 1151 行） | 已闭合 |
| 6 | 一般 | DeviceSelector onSelect value?: string 与实际签名不一致 | 改为 `value: string` 必填（第 347 行）；直接用 value 写 AppStorage；stub `SelectAttribute.onSelect` 同步为 `value: string` 必填（第 1154 行） | 已闭合 |
| 7 | 一般 | 编译验证脚本 mkdir/cp/for 路径不连续 | 重写为分目录独立派生 .ts 副本，每步明确 `cd` 到目标目录（第 1097-1111 行） | 已闭合 |
| 8 | 一般 | stub 组件类全局 declare class 与 ArkUI 真实导入路径不一致 | R3b 注意事项明确全部组件类必须在 `declare module '@kit.ArkUI'` 块内 `export class`（第 1149 行）；列出完整补全清单（10 装饰器 + 10 组件类 + ProgressType/SelectOption/AppStorage 等）（第 1150-1156 行） | 已闭合 |
| 9 | 轻微 | ConnectivityIndicator 高度/宽度单位混用 | Props 注释追加单位约定说明：宽度 `'100%'`（响应式）+ 高度数字 `4`（vp，固定 4px 细条）（第 815 行） | 已闭合 |
| 10 | 轻微 | BarChartRenderer 占位实现路径含糊 | 明确选择文字占位：`ctx.fillText('BarChart v1.0 placeholder', 10, height/2)`（第 536 行），去掉矩形柱分支 | 已闭合 |
| 11 | 轻微 | PaginatedList currentPage 起始值与后端分页约定未引用 | Props 注释追加"currentPage 从 1 开始，与后端分页约定一致（参考 docs/3_client-api-reference.md）"（第 637 行） | 已闭合 |
| 12 | 轻微 | LineChartRenderer drawChart 空数组导致 Infinity 坐标 | 绘制逻辑第 0 步加空数组防御 `if (data.length === 0) { return; }`（第 475 行） | 已闭合 |
| 13 | 轻微 | SensorCard 边界"value === 0"表述易误导 | 改为"`value` 为合法 number → 直接显示（含 0，0℃/0% 等都是合法传感器值）"（第 948 行） | 已闭合 |

## 通过依据

- **r1 严重问题（2 项）**：均已彻底闭合（pixelMap 类型强类型化 + DeviceSelector 持久化同步）
- **r1 一般问题（6 项）**：均已彻底闭合（@BuilderParam 约束 + @Link 父组件约束 + onError/onSelect 签名 + 验证脚本 + stub 声明统一）
- **r1 轻微问题（5 项）**：均已彻底闭合（高度单位 + 占位选择 + 分页约定 + 空数组防御 + value===0 措辞）
- **本轮新发现（0 项严重/0 项一般/1 项轻微）**：仅 1 项装饰器汇总表与 ControlButton 实际命名的轻微速记差异（不影响编码正确性）
- **通过条件**：满足 APPROVED 标准（无严重、无一般）

## 总结

DR=2 修订完整闭合了 r1 审查报告提出的全部 13 项反馈（2 严重 + 6 一般 + 5 轻微）。ImageViewer pixelMap 类型与 stub 同步消除双向不兼容；DeviceSelector aboutToAppear 读取持久值消除 UI/持久化撕裂；其余 11 项约束、签名、脚本、stub 声明均已精化。设计已达到可编码状态，建议进入 R3 实施阶段。