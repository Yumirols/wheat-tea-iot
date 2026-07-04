# 计划审查报告（R3 r2）

## 审查结果

REJECTED

## 发现

### [严重] 1. R3a 实际范围仍未充分缩小，"零 Canvas/ImageKit/BuilderParam 风险" 声明不成立

- **位置**：`plan_task.md` 第 30-50 行（R3a 文件清单）、第 156-200 行（详细任务范围）
- **问题**：
  - R3a 声称"零 Canvas 风险、零 ImageKit 风险、零 `@BuilderParam` 风险"，但 `ConnectivityIndicator.ets` 需 export 一个 `@Builder function ConnectivityIndicatorBuilder(status: ConnectivityStatus)`（第 199 行）。
  - `@Builder` 装饰器虽不是 `@BuilderParam`，但 task 第 281-282 行明确："`@Builder` 函数（不带 `Param` 后缀）必须**顶层**定义（不在 struct 内）"——这本身就是 ArkTS 的一个严格模式陷阱，与 `@BuilderParam` 同属 ArkUI 装饰器"陷阱集合"。
  - task 第 276 行声称"如发现缺失需先补全 stub 再验证"，但**没有**任何 R3a 验证步骤要求检查 `@kit.ArkUI` stub 是否包含 `@Builder` / `promptAction` / `Progress` / `ProgressType` / `Select` 装饰器声明。
  - 当前 `/tmp/arkts-check/stubs/kit-arkui.d.ts` 只导出 `window.WindowStage`，**不含**任何组件装饰器（`@Component` / `@Builder` / `@Entry` / `@State` / `@Prop` 等）。
  - 验证：当前 `kit-arkui.d.ts` 文件只有 19 行内容（已通过 Bash 确认），不包含任何 `promptAction` / `Progress` / `ProgressType` / `Select` / `@Builder` 装饰器声明。
- **影响**：
  - 实施期在 `tsc --noEmit -p .` 时将遇到大量"无法找到名称 'promptAction'"或"装饰器 '@Component' 未知"等编译错误，无法区分是 stub 缺失还是组件代码错误。
  - 与"零外部 Kit 风险"的设计目标**自相矛盾**——R3a 实际依赖了 R1 阶段未在 stub 中声明的 ArkUI 装饰器与组件类型。
- **期望修正方向**：
  - **选项 A（推荐）**：在 R3a 任务文件中**明确要求**在验证策略第 1 步同步检查/补全 `/tmp/arkts-check/stubs/kit-arkui.d.ts`，增加 ArkUI 装饰器（`@Component` / `@Builder` / `@Entry` / `@State` / `@Prop`）和组件类型（`promptAction` / `Progress` / `ProgressType` / `Select`）的声明，并列明需补全的 stub 模板。
  - **选项 B**：将 `ConnectivityIndicator.ets` 的 `@Builder` 拆分为 R3b，本轮 R3a 仅实现 5 个组件。

---

### [严重] 2. `tsconfig.json` `include` 路径仍不匹配实际目录结构

- **位置**：`plan_task.md` 第 250 行（验证策略步骤 1）、第 254 行（步骤 2 的 `mkdir -p` 路径）
- **问题**：
  - task 第 254 行写：`mkdir -p /tmp/arkts-check/src-ts/main/ets/components`
  - task 第 255 行写：`cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/components/*.ets /tmp/arkts-check/src-ts/main/ets/components/`
  - task 第 250 行写：`include` 数组中追加 `"src-ts/main/ets/components/**/*.ts"`
  - 已通过 Bash 确认当前 `/tmp/arkts-check/src-ts/main/ets/` 目录**确实**存在 `common/` / `entryability/` / `entrybackupability/` / `pages/` / `services/` 子目录，但**没有** `components/`（`harmony-app/` 项目中也尚未创建该目录）。
  - 当前 `tsconfig.json` 的 `include` 数组仅覆盖 `src-ts/common/**/*.ts` / `src-ts/services/**/*.ts` / `src-ts/entryability/**/*.ts`（已通过文件读取确认）——这些路径**没有** `main/` 前缀，与 R2 验证策略中的 `src-ts/common/` 路径假设一致。
  - **路径不一致**：R3a 任务的路径是 `src-ts/main/ets/components/**/*.ts`，而当前 `tsconfig.json` 实际匹配的是 `src-ts/common/**/*.ts`（无 `main/ets/` 前缀）。R2 验证报告（第 13-49 行）的命令使用的是 `src-ts/common/` / `src-ts/services/` / `src-ts/entryability/` 三层结构，而非 `src-ts/main/ets/...` 四层结构。
  - R2 的 cp 命令是 `cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/common/*.ets /tmp/arkts-check/src-ts/common/`（直接 cp 到 `src-ts/common/`，没有 `main/ets/` 中间层）。
- **影响**：
  - 如果按 R3a task 第 250 行写的 `include: "src-ts/main/ets/components/**/*.ts"`，**不会**匹配任何实际复制的 `.ts` 文件（实际路径是 `src-ts/components/` 或 `src-ts/main/ets/components/`），tsc 仍会"误判通过"。
  - 验证策略整体不可执行——步骤 2 的 `mkdir -p` 路径与步骤 1 的 `include` 路径、步骤 3 的 `cd` 路径、当前实际目录结构均不匹配。
- **期望修正方向**：
  - **统一 R2/R3 路径约定**：要么保持 R2 风格（`src-ts/common/` / `src-ts/services/` / `src-ts/entryability/` 三层，**无** `main/ets/` 中间层），include 追加 `"src-ts/components/**/*.ts"`；要么改为新风格（`src-ts/main/ets/components/` 四层），**但**需要同步更新 R2 的 cp 流程。
  - **明确选择其中一种路径约定**，并修正 task 全部相关步骤（mkdir / cp / include / tsc）。

---

### [严重] 3. R3a 中 `AppStorage.setOrCreate` 与 ArkTS 类型系统的兼容性未验证

- **位置**：`plan_task.md` 第 161-165 行（DeviceSelector 行为）
- **问题**：
  - task 第 163 行写：`AppStorage.setOrCreate<string>('selectedDeviceId', '')`（泛型调用语法）。
  - ArkTS 严格模式对 `AppStorage.setOrCreate` 的泛型签名支持**没有**明确文档保证；R1 的 stub 也**没有**声明 `AppStorage`（仅在 `kit-arkui.d.ts` 中声明了 `window.WindowStage`）。
  - 如果实施期按 ArkUI 文档用 `AppStorage.setOrCreate('selectedDeviceId', '')`（无泛型），可能与 task 要求不一致；如果按 task 写 `AppStorage.setOrCreate<string>(...)`，可能与 ArkUI 实际签名不匹配。
  - task 同样要求 `AppStorage.set<string>('selectedDeviceId', devices[newIndex].device_id)`（第 165 行），但 `AppStorage.set` 实际可能返回 `void`（无返回值），语法 `AppStorage.set<string>(...)` 在某些版本中**仅**支持 `setOrCreate` 不支持 `set`。
- **影响**：实施期 `tsc` 报错。
- **期望修正方向**：
  - 明确 `AppStorage` 在 ArkTS 严格模式下的正确调用形式（结合 ArkUI 官方文档或华为 OpenHarmony 文档确认）。
  - 补充 `AppStorage` 的 stub 声明到 `/tmp/arkts-check/stubs/kit-arkui.d.ts`，**或**在 R3a 验证步骤中明确"如 stub 缺失需先补全"。
  - 删除泛型语法或保留泛型语法需二选一，并提供依据（ArkUI 文档版本）。

---

### [一般] 4. R3a 中 `LoadingState` 错误消息约束使用 `@Require` 装饰器与 R1 stub 不一致

- **位置**：`plan_task.md` 第 303-304 行（LoadingState 错误消息约束）
- **问题**：
  - task 第 303 行写："当 `status === 'error'` 时 `errorMessage` 必须提供（实际编码时可在 struct 中以 `@Require errorMessage: string` 或在 `build()` 中 `if (this.status === 'error' && !this.errorMessage) throw new Error(...)` 断言）"
  - task 第 304 行写："为简化 R3a，本轮采用**约定约束**而非 `@Require` 装饰器（ArkTS `@Require` 在 R1 stub 中未声明；采用约定 + 文档注释即可）"
  - 这两行**自相矛盾**——第 303 行提出两种方案（含 `@Require`），第 304 行明确否决 `@Require`。
  - 实际有效约束应是"约定 + 文档注释"，但 task 没有提供具体的"约定"内容（如：在 build() 中抛错？在 aboutToAppear 中抛错？）。
- **影响**：实施期有歧义，可能误用 `@Require` 装饰器导致 stub 缺失报错。
- **期望修正方向**：
  - 删除第 303 行的 `@Require` 选项，仅保留"约定 + 文档注释"方案。
  - **明确**约定内容：在 `build()` 中通过 `if (this.status === 'error' && !this.errorMessage) { /* render with '加载失败，请重试' as fallback */ }` 兜底渲染（不要 throw 避免页面崩溃）。
  - 或在 Props 注释中写"建议父组件传非空 `errorMessage`，否则降级显示默认文案"。

---

### [一般] 5. `SensorCard` 的 `alarmBits: number[]` Props 与后端字段不一致

- **位置**：`plan_task.md` 第 147-150 行（SensorCard Props 定义）
- **问题**：
  - task 第 149 行写：`alarmBits: number[]`（默认 `[]`），并描述"告警位高亮"行为："`alarmBits.length > 0` 时背景色切为浅红 `#FFEBEE`"。
  - 已确认 R1 已固化的 `SensorSnapshot` 字段中只有 `alarm_flag: number`（位掩码数值，第 47 行），**没有** `alarmBits` 数组。
  - 任务要求"父组件传入 `alarmBits: number[]`"意味着父组件（如 `DashboardPage`）需要先调用 `common/utils.parseAlarmFlag(alarm_flag)` 解析为 `string[]`（即"温度过高"等中文标签），再过滤或映射为 `number[]`。
  - 实际上 `parseAlarmFlag(flag: number): string[]` 已经在 R1 固化（utils.ets 第 42 行），返回的是**中文标签字符串数组**，不是 `number[]`。
  - task 未约定：父组件应传 `string[]`（标签）还是 `number[]`（位码）？两种实现差异显著。
- **影响**：
  - 实施期需自行选择"位码 → 标签 → 过滤"或"位码 → 高亮判断"策略，导致组件与父组件接口不清晰。
  - 重复实现 `parseAlarmFlag` 解析逻辑，违背"组件职责单一"原则。
- **期望修正方向**：
  - **选项 A（推荐）**：将 Props 改为 `alarmLabels: string[]`（中文标签数组，默认 `[]`），由父组件调用 `parseAlarmFlag(alarm_flag)` 解析后传入。组件职责聚焦在 UI 渲染（`length > 0` 时高亮）。
  - **选项 B**：保留 `alarmBits: number[]` 但明确"父组件传 `ALARM_FLAG_*` 常量组成的数组"，并在任务描述中说明父组件需根据 `SensorSnapshot.alarm_flag` 位掩码 `&` 运算提取位码列表。

---

### [一般] 6. `ConnectivityIndicator.ets` 的 `@Builder` 函数与组件文件混存导致 ArkTS 限制被掩盖

- **位置**：`plan_task.md` 第 198-199 行（ConnectivityIndicator 行为）、第 281-282 行（已知约束）
- **问题**：
  - task 第 199 行写："同时 `export @Builder function ConnectivityIndicatorBuilder(status: ConnectivityStatus)` 供父组件在 `build()` 中按条件嵌入（`@Builder` 函数必须顶层定义，不能在 struct 内）"
  - 这种"组件 + Builder 顶层 export"在 ArkUI 中**合法但易出错**：
    - `@Builder` 函数作为顶层 export 意味着它**不**绑定到具体组件实例，无法访问 `@State` 状态
    - 父组件传入 `@Builder` 时仍需手动传参（`ConnectivityIndicatorBuilder(this.status)`），与普通函数调用无异
    - 与 ArkUI 的标准用法"组件 export → 父组件用 `<MyComponent prop={...} />` 嵌入"**不一致**
  - 设计文档 §20（第 389-397 行）仅说"提供 `@Builder` 供页面直接嵌入 `build()` 布局"，**没有**指定必须 export 顶层 `@Builder`。
- **影响**：
  - 实施期可能产生两种实现：
    1. 顶层 export `@Builder`（按 task 当前要求）
    2. 仅提供组件 + 内部 `@Builder` 方法（更符合 ArkUI 标准）
  - 两种实现方式对外 API 不一致，R4 Page 层接入时会有歧义。
- **期望修正方向**：
  - **明确**提供方式：要么"组件 + 顶层 export Builder"（用于 `@Builder` 函数式嵌入），要么"仅组件"（用于 `<ConnectivityIndicator status={...} />` 嵌入）。
  - **建议**：仅提供组件（更符合 ArkUI 标准用法），删除顶层 `@Builder` export。如果保留 Builder export，需说明父组件的精确调用语法（`build() { Row() { if (this.status === 'loading') { this.ConnectivityIndicatorBuilder('loading') } } }` 这种形式）。

---

### [一般] 7. R3a 中 `formatTimestamp` 的空值/无效值行为未约定

- **位置**：`plan_task.md` 第 147-152 行（SensorCard 行为）、第 137-139 行（utils 固化契约）
- **问题**：
  - task 要求 `SensorCard` 显示 `formatTimestamp(timestamp)`（第 149 行）。
  - 但 R1 固化的 `formatTimestamp(iso: string): string` 没有约定对空字符串、非法 ISO 字符串、`null` 等的处理行为。
  - `SensorSnapshot.timestamp` 来自后端 API，正常情况下非空；但如果设备离线或首次拉取，`timestamp` 可能为 `''` 或异常值。
  - 任务未说明 `formatTimestamp('')` 应返回 `''` / `'--'` / `'无效时间'` 哪种。
- **影响**：
  - 实施期会自行选择默认值，导致不同组件显示风格不一致。
- **期望修正方向**：
  - 在 `SensorCard` Props 注释中增加"timestamp 为空时显示 `'--'`（或其它统一占位）"。
  - 或在 R3a 实施说明中约定 `formatTimestamp` 在 `SensorCard` 中的调用形式：`Text(this.timestamp ? formatTimestamp(this.timestamp) : '--')`。

---

### [一般] 8. R3a 中 `DeviceSelector` 的 `<Select>` 组件 props 映射未约定

- **位置**：`plan_task.md` 第 157-160 行（DeviceSelector 行为）
- **问题**：
  - task 第 158 行写："渲染 `<Select>` 组件（ArkUI 内建），选项来自 `devices`（option 显示 `device_id`，value 也为 `device_id`）"
  - ArkUI `<Select>` 组件的 API 形式有：
    - 选项数组 `options: Array<SelectOption>`（其中 `SelectOption = { value: string, icon?: Resource }`）
    - 必须用 `selected` 绑定当前选中项
    - 用 `onSelect(callback: (index: number, value: string) => void)` 监听选择变化
  - task 仅说"option 显示 device_id，value 也为 device_id"——这是**显示**映射，未约定 ArkUI 组件**实际**的 props 形式。
  - 例如：`this.selectIndex`（数字索引）vs `this.selectValue`（字符串值）哪个作为 `<Select>` 的 `selected`？
- **影响**：
  - 实施期对 ArkUI `<Select>` API 细节有不同理解，可能导致选不中/选错设备。
- **期望修正方向**：
  - 明确 ArkUI `<Select>` 组件的 props 形式：`options: devices.map(d => ({ value: d.device_id }))`、`selected: this.selectedIndex`、`onSelect: (index: number) => { ... }`。
  - 说明"选中文本（option 文本）"如何映射（ArkUI 标准用法是 `value` 同时作为显示文本，但可在外面包一层 `Text(d.device_id)` 模拟）。

---

### [一般] 9. R3a 中 `SeverityBadge` 的 `string` 兜底类型与 `AlarmBanner` 联合类型不一致

- **位置**：`plan_task.md` 第 186-191 行（SeverityBadge Props）、第 95-96 行（AlarmBanner Props）
- **问题**：
  - task 第 187 行：`SeverityBadge.ets` Props 为 `severity: 'mild' | 'moderate' | 'severe' | string`（联合类型 + `string` 兜底）
  - task 第 95-96 行：`AlarmBanner.ets` Props 为 `severity: 'mild' | 'moderate' | 'severe'`（**不含** `string` 兜底）
  - 这两个组件接收相同语义的 `severity` 字段，类型签名却不一致。
  - 实际后端数据（`DiseaseRecord.severity: string`）在 R1 固化（第 93 行），**仅**是 `string`，没有限定英文枚举。
  - 如果父 Page 统一传 `string`（如 `'mild'` / `'中度'` / 任意其它值），AlarmBanner 在 strict 模式下会因类型不匹配报"不能将 string 分配给 'mild' | 'moderate' | 'severe'"错误。
- **影响**：
  - 父 Page 层调用 `AlarmBanner({ message: '...', severity: 'mild' })` 正常；调用 `AlarmBanner({ message: '...', severity: record.severity })`（record.severity 是 string）报错。
  - 设计上不一致——同名字段在不同组件类型签名不同。
- **期望修正方向**：
  - 统一两个组件的 `severity` 类型：
    - **选项 A**：都使用 `'mild' | 'moderate' | 'severe' | string`（含 `string` 兜底），父组件无需关心具体值。
    - **选项 B**：都使用 `string`（与后端 `DiseaseRecord.severity: string` 对齐），组件内部用 `switch` 严格匹配英文值。
  - **建议选项 B**——更符合 ArkTS "结构化类型 + 灵活输入"原则。

---

### [一般] 10. R3a 中 `LoadingState` 的 `onRetry` 可选性约束与设计文档冲突

- **位置**：`plan_task.md` 第 109-110 行、207-208 行（LoadingState Props）、第 301-304 行（已知约束）
- **问题**：
  - task 第 109-110 行：`onRetry?: () => void`（**可选** `?:`）
  - 设计文档 §21 衍生定义（**未**在 task 中直接引用）：`@Prop onRetry?: () => void`（设计文档未明确该字段在 `status === 'error'` 时是否必传）
  - task 第 301-304 行（已知约束）**只**讨论了 `errorMessage` 的必传性，**没有**讨论 `onRetry` 的必传性。
  - 但 task 第 211 行行为描述："error → 错误图标 + errorMessage + '重试'按钮（点击触发 onRetry）"——`onRetry` 似乎**应该**在 `status === 'error'` 时必传，否则用户点击"重试"按钮无响应。
- **影响**：
  - 实施期如果严格按"可选"实现，可能导致父组件忘记传 `onRetry` 时按钮点了无效。
- **期望修正方向**：
  - 明确"当 `status === 'error'` 时 `onRetry` 必须提供"（与 `errorMessage` 同等的约定约束），并在 Props 注释中写明。
  - 或将 `onRetry` 在 `status === 'error'` 时改为必传（去掉 `?`），但需在 build() 中处理 `status !== 'error'` 时 `onRetry` 为 `undefined` 的情况（ArkTS strict 模式下 `@Prop` 非可选字段不能为 `undefined`）。

---

### [一般] 11. R3a 验证策略中 `cp` 命令使用 Windows 路径分隔符在 Git Bash 中的兼容性问题

- **位置**：`plan_task.md` 第 254-255 行
- **问题**：
  - task 第 254 行写：`mkdir -p /tmp/arkts-check/src-ts/main/ets/components`（POSIX 路径）
  - task 第 255 行写：`cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/components/*.ets /tmp/arkts-check/src-ts/main/ets/components/`（Windows 风格盘符路径）
  - 在 Git Bash on Windows 中，POSIX 路径（`/tmp/...`）和 Windows 盘符路径（`E:/...`）**通常可以混用**，但**已有** R2 验证流程使用的是 `E:/dev/...` 形式（code_report.md 第 43-45 行已确认）。
  - R2 验证流程的 cp 命令是 `cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/common/*.ets /tmp/arkts-check/src-ts/common/`——注意这里是 `src-ts/common/`（无 `main/ets/` 中间层），与 R3a 任务的 `src-ts/main/ets/components/` **不一致**。
- **影响**：
  - R3a 验证步骤与 R2 已验证流程的路径假设**不一致**，增加了实施期的路径混乱风险。
- **期望修正方向**：
  - **统一** R2/R3 路径约定（与 [严重] 2 同根问题）：明确使用 `src-ts/components/`（与 R2 的 `src-ts/common/` 同层）或 `src-ts/main/ets/components/`（与源文件 `entry/src/main/ets/components/` 同结构），二选一。
  - **建议沿用 R2 风格**（`src-ts/components/`），include 改为 `"src-ts/components/**/*.ts"`，与已验证的 R2 流程保持一致。

---

### [轻微] 12. R3a 验证策略第 1 步（更新 tsconfig.json）描述不精确

- **位置**：`plan_task.md` 第 250 行
- **问题**：
  - task 第 250 行写："在 `/tmp/arkts-check/tsconfig.json` 的 `include` 数组中追加 `"src-ts/main/ets/components/**/*.ts"`"
  - 未说明"追加"的具体位置（数组首/尾/中间），也未提供修改前/后的 tsconfig.json 完整内容。
- **影响**：实施期需自行判断插入位置，可能误操作。
- **期望修正方向**：
  - 提供修改后的完整 tsconfig.json 内容（或 diff 形式）。
  - 明确追加位置（按字母序或保持与 R2 现有顺序一致）。

---

### [轻微] 13. R3a 中 `LoadingState` 的"暂无数据"文案硬编码中文

- **位置**：`plan_task.md` 第 209-213 行（LoadingState 行为）
- **问题**：
  - task 第 213 行写："empty → 空图标（`<Text>∅</Text>`）+ '暂无数据' 文案"
  - "加载中..." / "暂无数据" / "重试" 等中文文案硬编码在组件内。
  - ArkUI 支持 `i18n` 国际化，但 R3a 任务未提及是否需要提取为 `string` 资源。
- **影响**：后续 i18n 时需逐个组件修改。
- **期望修正方向**：
  - 本轮可接受硬编码（v1.0 仅中文），但在"留待后续"中明确"i18n 资源化（R5+）"。
  - 或：硬编码与 `string` 资源并行（用 `$r('app.string.loading_text')`），但 R3a 阶段无 `$r` 依赖，按 v1.0 仅中文硬编码处理即可。

---

### [轻微] 14. R3a 任务文件未提供组件 Props 完整 TypeScript 签名

- **位置**：`plan_task.md` 第 138-213 行（详细任务范围）
- **问题**：
  - task 仅以自然语言描述 Props 字段名和类型（如 `label: string`、`value: number`、`alarmBits: number[]`），但**没有**提供 ArkTS 装饰器签名（如 `@Prop label: string`、`@State selectedIndex: number = 0`）。
  - 实施期对装饰器选择有歧义：哪些字段用 `@Prop`？哪些用 `@State`？父组件约束如何？
  - 已知约束章节（第 280-282 行）**只**说"单一职责"，**没有**明确每个字段的装饰器。
- **影响**：实施期需自行决定 `@Prop` vs `@State`，可能与 R4 父组件约束不匹配。
- **期望修正方向**：
  - 为每个组件的 Props/State 提供完整 ArkTS 签名（如 `@Prop label: string`、`@Prop value: number`、`@Prop unit: string`、`@Prop timestamp: string`、`@Prop alarmBits: number[] = []`），减少实施期歧义。

---

### [轻微] 15. R3a 中 R3b 前置条件的 stub 模板示例不完整

- **位置**：`plan_task.md` 第 330-333 行（R3b 前置条件）
- **问题**：
  - task 第 330-333 行给出了 `kit-image.d.ts` 的 stub 模板，但 stub 中 `PixelMap` 是 `export interface PixelMap { /* 简化占位 */ }`（空接口）。
  - R3b 实施时 `createPixelMap(): Promise<PixelMap>` 实际需要 `PixelMap` 有 `getPixelBytes()` 等方法（用于 Image 组件绑定），空接口可能导致 tsc 通过但运行时失败。
  - task 标注"实施前必须完成"——但 R3a 任务**不**实施该 stub，所以 R3a 阶段不需关注；但任务文档应**指向**一个明确的 stub 创建位置（`/tmp/arkts-check/stubs/kit-image.d.ts`）。
- **影响**：R3a 阶段无影响，但 R3b 任务文件会沿用该描述，需补充更精确的 stub 模板。
- **期望修正方向**：
  - 明确 stub 文件路径：`/tmp/arkts-check/stubs/kit-image.d.ts`（已在 task 中提及）。
  - 在 R3b 任务文件中补充 PixelMap 完整接口（`getPixelBytes(width: number, height: number): ArrayBuffer` 等方法），但本轮 R3a 可不展开。

---

## 修改要求

### 必须修正（严重）

1. **明确 `ConnectivityIndicator.ets` 的 ArkUI 装饰器依赖**：在 R3a 验证策略中**前置要求**补全 `/tmp/arkts-check/stubs/kit-arkui.d.ts`，列出需声明的 ArkUI 装饰器（`@Component` / `@Builder` / `@Entry` / `@State` / `@Prop`）和组件类型（`promptAction` / `Progress` / `ProgressType` / `Select`）。提供完整 stub 模板。**或**将 `ConnectivityIndicator.ets` 移至 R3b（其 `@Builder` 导出属于 ArkUI 严格模式陷阱）。
2. **统一 R2/R3 验证流程的路径约定**：修正 `mkdir -p` / `cp` / `tsconfig include` 三处路径，保持与 R2 已验证的 `src-ts/<layer>/` 三层结构一致。include 改为 `"src-ts/components/**/*.ts"`，cp 目标目录改为 `/tmp/arkts-check/src-ts/components/`。
3. **明确 `AppStorage.setOrCreate<string>` 的 ArkTS 兼容性**：补全 `AppStorage` 的 stub 声明到 `kit-arkui.d.ts`，或明确 ArkTS 严格模式下的正确调用形式（结合 ArkUI 官方文档）。删除泛型语法或保留泛型语法需二选一，并提供依据。

### 应当修正（一般）

4. **删除 `LoadingState.errorMessage` 约束中的 `@Require` 选项**：仅保留"约定 + 文档注释"方案，明确约定内容（build() 中兜底渲染默认文案，不 throw）。
5. **调整 `SensorCard.alarmBits` Props 语义**：改为 `alarmLabels: string[]`（中文标签），由父组件调用 `parseAlarmFlag(alarm_flag)` 解析后传入。避免与 R1 `parseAlarmFlag(flag: number): string[]` 的契约冲突。
6. **明确 `ConnectivityIndicator.ets` 的 `@Builder` 提供方式**：要么仅提供组件，要么明确父组件精确调用语法（不能模糊处理）。
7. **约定 `SensorCard.timestamp` 空值处理**：`Text(this.timestamp ? formatTimestamp(this.timestamp) : '--')`。
8. **明确 `DeviceSelector` 的 `<Select>` 组件 props 形式**：`options: devices.map(d => ({ value: d.device_id }))`、`selected: this.selectedIndex`、`onSelect: (index: number) => { ... }`。
9. **统一 `SeverityBadge` 与 `AlarmBanner` 的 `severity` 类型**：两个组件都用 `string`（与后端 `DiseaseRecord.severity: string` 对齐），组件内部 switch 严格匹配。
10. **明确 `LoadingState.onRetry` 的必传约束**：`status === 'error'` 时 `onRetry` 必须提供（约定约束，非编译期强约束）。

### 建议改进（轻微）

11. **统一 R2/R3 验证流程的路径风格**（与 [严重] 2 同根问题，已在严重问题中要求修正）。
12. **提供 tsconfig.json 修改后的完整内容**（或 diff）。
13. **i18n 文案提取**：硬编码中文可接受，但在"留待后续"中明确 i18n 资源化时间点。
14. **为每个组件的 Props/State 提供完整 ArkTS 装饰器签名**（`@Prop` / `@State` 等）。
15. **补充 R3b 的 `PixelMap` 完整 stub 模板**（本轮可仅指向 R3b 任务文件）。

---

## r1 轮发现处理情况总结

| # | r1 发现 | 严重度 | r2 处理状态 | 评价 |
|---|--------|--------|----------|------|
| 1 | `PaginatedList.loadPage` 返回结构不一致 | 严重 | **未在 R3a 处理**（R3a 不含 PaginatedList） | ✅ 合理（已移至 R3b） |
| 2 | `@kit.ImageKit` stub 缺失 | 严重 | **R3b 前置条件已明确**（第 328-333 行） | ✅ 合理（已明确实施前补全） |
| 3 | `ControlButton.onToggle` 签名不一致 | 严重 | **未在 R3a 处理**（R3a 不含 ControlButton） | ✅ 合理（已移至 R3b） |
| 4 | `ChartView` 重绘策略未明确 | 一般 | **R3b 范围（第 327 行）明确"父组件 key 强制重绘"** | ✅ 合理 |
| 5 | `PaginatedList.renderItem` 用 `@BuilderParam` | 一般 | **未在 R3a 处理**（R3a 不含 PaginatedList） | ✅ 合理（已移至 R3b） |
| 6 | `SeverityBadge` Props 类型与 `AlarmBanner` 对齐 | 一般 | **r2 部分修正**（r2 改为 `'mild' \| 'moderate' \| 'severe' \| string`），但与 AlarmBanner 仍不一致 | ⚠️ 未完全修正（见 [一般] 9） |
| 7 | `LoadingState.errorMessage` 注释与设计文档不一致 | 一般 | **r2 已明确"当 status === 'error' 时必须提供"** | ✅ 合理，但 `@Require` 描述有冲突（见 [一般] 4） |
| 8 | `ControlButton` 父组件约束说明 | 一般 | **未在 R3a 处理**（R3a 不含 ControlButton） | ✅ 合理（已移至 R3b） |
| 9 | 12 个组件一次性实现粒度过大 | 一般 | **r2 已采纳，拆分为 R3a（6 基础）+ R3b（6 进阶）** | ✅ 合理 |
| 10 | `tsconfig.json` include 未覆盖 `components/` | 一般 | **r2 验证策略第 1 步已明确"先更新 include"** | ✅ 修正了要点，但路径仍不匹配（见 [严重] 2） |
| 11 | `DeviceSelector` AppStorage 双向同步描述不完整 | 轻微 | **r2 已明确"仅写不读 + 父 Page 用 @StorageLink 监听"** | ✅ 合理 |
| 12 | `ImageViewer.imageId` 来源未明确 | 轻微 | **R3b 范围（第 333 行）已明确"由父 Page 从 image_path 提取后传入"** | ✅ 合理 |
| 13 | `BarChartRenderer` 占位语义模糊 | 轻微 | **R3b 范围（第 333 行）已明确"render 方法直接 return"** | ✅ 合理 |
| 14 | `ImageViewer.createPixelMap()` 异步语义未明确 | 轻微 | **R3b 范围（第 333 行）已明确"必须 await"** | ✅ 合理 |

**r1 轮 14 项发现的处理情况**：
- **完全修正**：7 项（#4、#7、#9、#10 部分、#11、#12、#13、#14）
- **部分修正 / 仍有问题**：1 项（#6 SeverityBadge 类型仍未与 AlarmBanner 完全对齐）
- **通过拆分任务规避**：6 项（#1、#2、#3、#5、#8 已移至 R3b，不在 R3a 范围）

**r2 轮新发现的问题**（未在 r1 轮提出）：
- **[严重]**：3 项（ArkUI 装饰器 stub 缺失、路径约定不一致、AppStorage 兼容性）
- **[一般]**：5 项（LoadingState @Require 冲突、SensorCard alarmBits 语义、ConnectivityIndicator Builder 方式、timestamp 空值、DeviceSelector Select API）
- **[轻微]**：5 项（路径风格、tsconfig 描述、i18n、Props 装饰器签名、PixelMap stub）

---

## 总结

R3 r2 在 r1 轮基础上做了大量有意义的改进：
1. **拆分任务粒度**：将 12 组件一次性实现拆分为 R3a（6 基础）+ R3b（6 进阶），降低单轮失败风险
2. **R3a 范围明确**：仅包含零 Canvas/ImageKit/BuilderParam 风险的 6 个基础组件
3. **R1/R2 契约引用准确**：已固化的 common/services 类型与 R3a 组件接口对齐
4. **tsconfig include 修正**：在验证策略中明确"先更新 include 再 tsc"

但 r2 仍存在以下**未解决问题**：

1. **3 个严重问题**：
   - `@kit.ArkUI` stub 缺失（含 ArkUI 装饰器、promptAction、Progress、Select 等），R3a 实际并非"零外部 Kit 风险"
   - R2/R3 验证流程路径约定不一致（`src-ts/main/ets/components/` vs R2 实际的 `src-ts/common/`）
   - `AppStorage` 的 ArkTS 兼容性未验证

2. **5 个一般问题**：
   - `LoadingState.errorMessage` 约束的 `@Require` 描述自相矛盾
   - `SensorCard.alarmBits: number[]` 与 R1 `parseAlarmFlag(flag): string[]` 契约冲突
   - `ConnectivityIndicator` 的 `@Builder` 导出方式与 ArkUI 标准用法不一致
   - `timestamp` 空值、`DeviceSelector` `<Select>` API、`severity` 类型一致性等接口细节

**通过条件**：修正 3 个严重问题 + 至少 3 个一般问题后可批准。

## 附加说明

### 整体评价

R3a 任务在范围划分上已经合理（6 基础组件 + 6 进阶组件分两批），**主要问题集中在三方面**：

1. **路径与 stub 缺失的复合风险**：R2 已验证的路径是 `src-ts/<layer>/` 三层结构，R3a 任务写了 `src-ts/main/ets/components/` 四层结构，且未要求补全 ArkUI 装饰器 stub。这两个问题叠加将导致 R3a 实施期 `tsc` 报错**大量**且**无法定位**（是路径不对？是 stub 缺失？还是代码错误？）。

2. **ArkUI 装饰器/组件的 stub 缺失未前置处理**：`@kit.ArkUI` 当前 stub 只有 19 行 `window.WindowStage` 声明（已确认），不含任何 ArkUI 装饰器（`@Component` / `@Builder` / `@Entry` / `@State` / `@Prop`）或组件类型（`promptAction` / `Progress` / `ProgressType` / `Select`）。R3a 实际并非"零外部 Kit 风险"。

3. **Props 语义细节与已固化契约冲突**：`SensorCard.alarmBits: number[]` 与 R1 `parseAlarmFlag(flag): string[]` 不匹配；`SeverityBadge` / `AlarmBanner` 的 `severity` 类型不一致。这些细节问题虽不阻塞编译，但会增加 R4 父组件接入的复杂度。

### 建议的 R3a 最小修正集

- **必做（3 项严重）**：
  1. 在 R3a 验证策略中**前置**补全 `kit-arkui.d.ts` stub（至少包含 `@Component` / `@State` / `@Prop` 装饰器和 `promptAction` / `Progress` / `ProgressType` / `Select` 组件类型）——可参考 OpenHarmony ArkUI 官方 API 文档
  2. 修正 R3a 验证流程的路径为 `src-ts/components/`（与 R2 一致），include 改为 `"src-ts/components/**/*.ts"`
  3. 补全 `AppStorage` 的 stub 声明，或明确 ArkTS 严格模式下的正确调用形式

- **应做（3 项一般）**：
  1. 删除 `LoadingState.errorMessage` 约束中的 `@Require` 描述
  2. 调整 `SensorCard.alarmBits` 为 `alarmLabels: string[]`
  3. 统一 `SeverityBadge` / `AlarmBanner` 的 `severity` 类型为 `string`

完成上述 6 项修正后，R3a 任务可批准。
