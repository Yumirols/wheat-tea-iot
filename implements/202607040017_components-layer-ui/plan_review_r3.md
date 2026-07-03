# 计划审查报告（R3 r3）

## 审查结果

APPROVED

## 发现

### 验证 r3 修订解决 r1/r2 遗留问题的效果

| # | 来源 | 问题 | r3 处理方式 | 验证 |
|---|------|------|-------------|------|
| 1 | r2 [严重] | `kit-arkui.d.ts` stub 缺少 ArkUI 装饰器与组件类型 | 在验证策略第 0 步要求补全 130+ 行完整 stub 模板（@Component/@State/@Prop/@Link/@Builder/@BuilderParam/@Entry/@Watch/@StorageLink/@StorageProp 全部声明） | ✅ 模板完整。额外发现：当前 15 行 stub 实际已能让 `@Component`/`@State`/`@Entry` 通过 tsc 编译（因 `experimentalDecorators: true` 允许任何装饰器语法），但补全更明确 |
| 2 | r2 [严重] | tsconfig.json 路径 `src-ts/main/ets/...` 与 R2 验证流程不一致 | r3 确认实际路径为四层 `src-ts/main/ets/components/`，与现有 tsconfig.json include 对齐 | ✅ 已通过 `cat /tmp/arkts-check/tsconfig.json` 确认 include 使用四层结构 |
| 3 | r2 [严重] | `AppStorage.setOrCreate<string>` 兼容性未验证 | 在 stub 模板中声明 `AppStorage` 类的 `setOrCreate<T>/set<T>/get<T>/has/delete/keys` 静态方法 | ✅ stub 模板已含完整 AppStorage 接口；明确 ArkTS 严格模式调用形式（不带泛型） |
| 4 | r2 [一般] | `@Require` 装饰器描述自相矛盾 | 删除 `@Require` 方案；明确"build() 中兜底渲染默认文案 `'加载失败，请重试'`" | ✅ 修订表 #4 已处理；task 第 252 行明确"不使用 `@Require` 装饰器" |
| 5 | r2 [一般] | `SensorCard.alarmBits: number[]` 与 R1 `parseAlarmFlag(flag): string[]` 契约冲突 | Props 改为 `alarmLabels: string[]`（中文标签数组） | ✅ 修订表 #5 已处理；已确认 R1 `utils.ets` 第 42-69 行 `parseAlarmFlag(flag: number): string[]` 返回中文标签数组，Props 类型对齐 |
| 6 | r2 [一般] | `ConnectivityIndicator` 的顶层 `@Builder` 导出与 ArkUI 标准用法不一致 | R3a 移除顶层 `@Builder` export；`ConnectivityIndicator` 移至 R3b | ✅ 修订表 #6 已处理；R3a 缩减为 5 个组件 |
| 7 | r2 [一般] | `SensorCard.timestamp` 空值处理未约定 | 明确 `Text(this.timestamp !== '' ? formatTimestamp(this.timestamp) : '--')` | ✅ 修订表 #7 已处理；task 第 158 行明确约定 |
| 8 | r2 [一般] | `DeviceSelector` 的 `<Select>` 组件 props 形式未明确 | 明确 `options/selected/onSelect` 三个 props 形式及 `SelectOption = { value: string }` 映射 | ✅ 修订表 #8 已处理；task 第 180-186 行精确规定 |
| 9 | r2 [一般] | `SeverityBadge` 与 `AlarmBanner` 的 `severity` 类型不一致 | 两个组件统一为 `severity: string`（与 R1 `DiseaseRecord.severity: string` 对齐），内部 switch 严格匹配英文 | ✅ 修订表 #9 已处理；已确认 R1 `models.ets` 中 `DiseaseRecord.severity` 为 `string` |
| 10 | r2 [一般] | `LoadingState.onRetry` 必传约束未明确 | 明确"status === 'error' 时 onRetry 必须提供（约定约束，非编译期强约束）" | ✅ 修订表 #10 已处理；task 第 109-110 行明确约定 |
| 11 | r2 [轻微] | tsconfig.json 修改未提供完整 diff | 提供修改后的完整 include 数组 | ✅ task 第 444-457 行给出完整 tsconfig.json 内容 |
| 12 | r2 [轻微] | LoadingState 文案硬编码中文无 i18n 规划 | 采纳；明确 R5+ 提取 `$r('app.string.*')` 资源 | ✅ task 第 568-571 行明确 i18n 时间点 |
| 13 | r2 [轻微] | 组件 Props 缺少完整 ArkTS 装饰器签名 | 每个组件给出完整 ArkTS 装饰器签名 | ✅ task 第 144-154、168-174、194-204、220-226、240-250 行给出 5 个组件完整签名 |
| 14 | r2 [轻微] | R3b `PixelMap` stub 模板不完整 | 采纳；R3b stub 模板在 R3b 任务文件中展开 | ✅ task 第 563 行指向 R3b 任务文件 |
| 15 | r1 遗留 | `SeverityBadge` 类型未完全对齐 `AlarmBanner` | 通过修订 #9 闭合（统一为 `string`） | ✅ 已闭合 |

### 关键事实验证

#### 1. `kit-arkui.d.ts` stub 当前状态确认
- 已读取 `/tmp/arkts-check/stubs/kit-arkui.d.ts`（15 行，仅声明 `window.WindowStage`）
- 已通过 `tsc --noEmit -p .` 验证：当前 stub 能让含 `@Entry`/`@Component`/`@State` 的 `Index.ets` 通过 tsc 编译
- **结论**：当前 15 行 stub 已足够支持 R3a 5 个组件的 tsc 编译（因 `experimentalDecorators: true`）。r3 提议的 130+ 行扩展 stub 模板虽更精确但**非必要**——这是过度设计但不影响正确性。

#### 2. tsconfig.json include 路径确认
- 已读取 `/tmp/arkts-check/tsconfig.json`，include 数组为：
  ```json
  "include": [
    "src-ts/main/ets/common/**/*.ts",
    "src-ts/main/ets/services/**/*.ts",
    "src-ts/main/ets/entryability/**/*.ts",
    "stubs/**/*.d.ts"
  ]
  ```
- r3 提议在 `entryability` 之后、`stubs` 之前新增 `"src-ts/main/ets/components/**/*.ts"`，位置与现有顺序一致
- R2 code_report 第 41-45 行使用 `src-ts/common/` 是**文档错误**（与实际 tsconfig 不一致），但 R2 验证实际使用的是四层路径
- **结论**：r3 路径约定与实际 tsconfig.json 完全一致，验证策略可执行

#### 3. ArkTS 装饰器/模式可用性确认
- **`@Require` 装饰器**：ArkTS 在 API 9+ 提供，但严格模式下与 `@Prop` 配合的 `@Require` 在 R1 已确立的 stub 中未声明。r3 选择约定约束（不 throw，build() 中兜底渲染）符合 ArkTS 最佳实践且规避 stub 风险。**决策正确**。
- **顶层 `@Builder` export**：ArkTS 标准支持（设计文档 §20 明确要求 ConnectivityIndicator "提供 @Builder"），但与 ArkUI 标准组件用法有冲突。r3 将 ConnectivityIndicator 移至 R3b 并在 R3a 仅使用组件形式是**合理防御性收缩**。
- **AppStorage**：ArkTS 标准全局对象，`setOrCreate<T>` / `set<T>` / `get<T>` 为标准 API。r3 在 stub 中声明完整接口，调用形式明确为不带泛型（`AppStorage.setOrCreate('selectedDeviceId', '')`）。**与 ArkUI 官方文档一致**。

#### 4. R1/R2 固化契约引用准确
- `DeviceInfo.device_id` 字段名：已确认 R1 `models.ets` 第 16 行
- `parseAlarmFlag(flag: number): string[]` 返回中文标签：已确认 R1 `utils.ets` 第 42-69 行
- `formatTimestamp(iso: string): string`：已确认 R1 `utils.ets` 第 22-36 行
- `ConnectivityStatus` 类型定义：已确认 R1 `models.ets` 第 276 行
- `HttpClient.BASE_URL` / `HEADER_KEY` 导出：R2 code_report 已确认

#### 5. R3a 范围缩减合理性
- 原 12 组件一次性实现（r1 发现 #9）→ 拆分为 R3a（5 基础）+ R3b（7 进阶）
- R3a 5 个组件（SeverityBadge / AlarmBanner / LoadingState / SensorCard / DeviceSelector）零 Canvas / ImageKit / `@BuilderParam` / `@Link` / 顶层 `@Builder` 风险
- R3b 7 个组件（含 ConnectivityIndicator / ChartView / LineChartRenderer / BarChartRenderer / ControlButton / PaginatedList / ImageViewer）均含明确高风险语法
- **范围划分合理**，单轮失败风险点可控

#### 6. 验证策略可执行性
- 第 0 步（补全 kit-arkui.d.ts）：技术上可选（现有 15 行 stub 已通过 tsc），但 r3 选择补全以**更精确反映 ArkUI API**——属于"增强清晰度"而非"修正错误"
- 第 1 步（更新 tsconfig.json include）：路径与实际匹配，可执行
- 第 2 步（mkdir -p / cp）：POSIX 路径 + Windows 盘符路径在 Git Bash 中兼容（与 R2 一致）
- 第 3-5 步（派生 .ts + tsc）：与 R2 流程一致

### 轻微观察（非阻塞）

1. **[轻微] stub 模板中 `Select` 类导出位置不太标准**：r3 stub 将 `Select` / `Text` / `Button` / `Row` / `Column` / `Stack` 等组件类放在 `declare module '@kit.ArkUI'` 块外使用 `declare class` 声明——这在 ArkTS 严格模式下不一定能正确解析为全局组件，但因 `experimentalDecorators: true` 已使现有 15 行 stub 编译通过，这一扩展**不会导致回归**。仅作为改进建议。

2. **[轻微] `stub` 模板与 R3a 实际需求范围不严格匹配**：R3a 5 个组件实际不依赖 `promptAction`、`Select`（DeviceSelector 移至 R3b 后也未使用）、`Text`/`Button`/`Row`/`Column` 等。补全这些类型是为 R3b 准备（task 第 365 行也承认这一点），但 R3a 实际编译**不需要**这些声明。

3. **[轻微] `AppStorage.setOrCreate` 不带泛型的形式在 ArkTS 中确实有效**（已通过 ArkUI 官方文档确认），但 stub 中 `setOrCreate<T>` 仍声明为泛型方法——这符合 TS 类型推导规范，调用方省略泛型参数时由 tsc 推断。**无问题**。

## 整体评价

R3a 任务在 r1/r2 轮基础上已完成**所有遗留问题的闭环处理**：

1. **15 项 r1/r2 发现** 全部处理（3 严重 + 5 一般 + 5 轻微 + r1 遗留 2 项）
2. **stub 补全** 提供完整模板（虽然过度设计，但不影响正确性）
3. **路径约定** 与实际 tsconfig.json 完全一致
4. **范围缩减** 合理（5 基础 + 7 进阶分两批）
5. **Props 装饰器签名** 完整
6. **R1/R2 固化契约引用** 准确
7. **i18n 时间点** 明确（R5+）

R3a 可批准进入实施阶段。

## 通过条件

无严重、无一般问题。3 项轻微观察为改进建议，不影响正确性与可执行性。

## 结论

APPROVED
