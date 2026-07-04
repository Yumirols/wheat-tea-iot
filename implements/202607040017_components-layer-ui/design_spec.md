# 设计规格（R3 DR=2 修订）

## 概述

实现 `components/` 层全部 12 个 UI 组件。完成后 `harmony-app` 必须能够通过 ArkTS 编译（`tsc --noEmit` strict 模式），无 error。

**范围**：
- 12 个 UI 组件（按计划文档分为 R3a 5 个 + R3b 7 个，本设计覆盖全部 12 个的完整设计规格）

**R1/R2 边界**：
- **不修改** common 层（6 个文件已 R1 固化）
- **不修改** services 层（7 个文件已 R2 固化）
- **不修改** EntryAbility、Index.ets、EntryBackupAbility
- **不修改** module.json5、main_pages.json、oh-package.json5
- 本轮不涉及 pages 层（R4 任务）

**与 R1/R2 的关系**：
- 组件仅依赖 `common/` 层（models + constants + utils.formatTimestamp）
- `DeviceSelector` 在注释中引用 `DeviceService` 但**不调用**（实际调用由 R4 Page 层完成）
- `SensorCard` 依赖 `common/utils.parseAlarmFlag`（由父组件调用后传入 `alarmLabels: string[]`）

**v1.0 范围声明**：
- Canvas 渲染：v1.0 接受**一次性绘制**（不在响应式数据变化时自动重绘），父组件通过 `key` 强制重建实现重绘
- `@Link`：仅 `ControlButton` 使用（双向绑定父组件状态）
- `@BuilderParam`：仅 `PaginatedList` 使用（接收父组件传入的 `renderItem` 模板）
- 顶层 `@Builder` export：**不提供**——所有组件仅通过 `<ComponentName {...props} />` 形式使用

---

## 文件规划

| 文件路径 | 操作 | 职责 |
|---------|------|------|
| `harmony-app/entry/src/main/ets/components/SeverityBadge.ets` | 新建 | 严重度文字徽标（mild/moderate/severe 三色 + 中文标签） |
| `harmony-app/entry/src/main/ets/components/AlarmBanner.ets` | 新建 | 告警横幅（三色背景 + 关闭按钮 + 点击回调） |
| `harmony-app/entry/src/main/ets/components/LoadingState.ets` | 新建 | 统一加载占位（loading/error/empty 三态 + 重试按钮） |
| `harmony-app/entry/src/main/ets/components/SensorCard.ets` | 新建 | 传感器参数卡片（数值+单位+时间戳+告警标签高亮） |
| `harmony-app/entry/src/main/ets/components/DeviceSelector.ets` | 新建 | 设备下拉选择器（AppStorage 单向写） |
| `harmony-app/entry/src/main/ets/components/ChartView.ets` | 新建 | 历史趋势图表容器（委托 ChartRendererAPI） |
| `harmony-app/entry/src/main/ets/components/LineChartRenderer.ets` | 新建 | 折线图渲染器（v1.0 一次性 Canvas 绘制） |
| `harmony-app/entry/src/main/ets/components/BarChartRenderer.ets` | 新建 | 柱状图渲染器（v1.0 占位实现） |
| `harmony-app/entry/src/main/ets/components/ControlButton.ets` | 新建 | 控制按钮（`@Link` 双向绑定 + 乐观 UI 回滚） |
| `harmony-app/entry/src/main/ets/components/PaginatedList.ets` | 新建 | 分页列表容器（`@BuilderParam` + 滚动加载） |
| `harmony-app/entry/src/main/ets/components/ImageViewer.ets` | 新建 | 图片查看器（主路径直连 + 降级 PixelMap 路径） |
| `harmony-app/entry/src/main/ets/components/ConnectivityIndicator.ets` | 新建 | 连接状态指示器（顶部细条三色） |

---

## 公共设计约定

### 命名风格
- 组件 `struct` 名：PascalCase（`SensorCard`、`AlarmBanner` 等）
- Props 变量：camelCase
- 内部状态变量：camelCase，加 `_` 前缀无（ArkTS 风格——直接命名）
- 导出形式：`export { ComponentName }`（与 R1/R2 一致）

### ArkTS 装饰器使用策略

| 装饰器 | 用途 | 使用组件 |
|--------|------|---------|
| `@Component` | 声明 UI 组件 struct | 全部 12 个 |
| `@Entry` | 声明页面入口 | （R4 页面使用，本轮组件不涉及） |
| `@State` | 组件内部可变状态 | DeviceSelector（`selectedIndex`）、ControlButton（`previousState`/`isLoading`）、PaginatedList（`records`/`currentPage`/`hasMore`/`isLoading`）、ImageViewer（`pixelMap`/`loadStatus`）、LineChartRenderer（`isReady`） |
| `@Prop` | 父→子单向数据流 | 全部展示型组件（SensorCard、AlarmBanner、SeverityBadge、LoadingState、DeviceSelector、ConnectivityIndicator、ChartView、ImageViewer、PaginatedList、BarChartRenderer、LineChartRenderer、ControlButton） |
| `@Link` | 双向数据绑定（子→父） | ControlButton（`isOn`） |
| `@Watch` | 状态变更监听 | ControlButton（`@Watch('isOn')`——实际不需要，使用 `@Link` 自身触发重绘即可，本轮不使用 `@Watch`） |
| `@Builder` | 方法级 UI 模板 | ChartView（`buildChart`）、LineChartRenderer（坐标轴/折线分段）、ImageViewer（占位 UI） |
| `@BuilderParam` | 接收父组件传入的 UI 模板 | PaginatedList（`renderItem`） |
| `@StorageLink` | 与 AppStorage 双向绑定 | （R4 Page 层使用，本轮组件不涉及） |
| `@StorageProp` | 与 AppStorage 单向同步 | （R4 Page 层使用，本轮组件不涉及） |

### `@Prop` vs `@State` vs `@Link` 选择理由

| 场景 | 选择 | 理由 |
|------|------|------|
| 父→子展示，不修改 | `@Prop` | 编译期只读约束，UI 触发更新由父组件 `@State` 变更驱动 |
| 组件内部 UI 状态 | `@State` | 组件独立维护（如 `selectedIndex`） |
| 父子双向同步 | `@Link` | 乐观 UI 要求子组件修改父组件状态（如 `ControlButton`） |
| 父组件传入 UI 模板 | `@BuilderParam` | 复用渲染逻辑，父组件提供列表项模板（如 `PaginatedList`） |

---

## 组件详细设计

### 1. SeverityBadge.ets

#### Props/State 接口

```typescript
@Component
struct SeverityBadge {
  @Prop severity: string;  // 英文 mild/moderate/severe 或其它任意字符串
  build() {
    /* switch (this.severity) */
  }
}
export { SeverityBadge };
```

**Props 说明**：
- `severity: string` —— 必填，与 `DiseaseRecord.severity: string` 对齐。内部 `switch` 严格匹配英文 `mild`/`moderate`/`severe`，其它值走默认分支。

#### 行为契约

- `severity === 'mild'` → 背景 `#4CAF50`（绿），文字"轻度"
- `severity === 'moderate'` → 背景 `#FF9800`（橙），文字"中度"
- `severity === 'severe'` → 背景 `#F44336`（红），文字"重度"
- 其它字符串值 → 背景 `#9E9E9E`（灰），文字为原 `severity` 字符串（如传入"轻度"则显示"轻度"，传入"unknown"则显示"unknown"）

**实现要点**：
```typescript
build() {
  Row() {
    Text(/* 根据 switch 结果决定 */)
      .fontColor(Color.White)
      .fontSize(12)
  }
  .backgroundColor(/* 根据 switch 结果决定 */)
  .padding(4)
  .borderRadius(4)
}
```

#### 内部状态管理
- 无 `@State`——纯展示型组件，所有数据来自 `@Prop severity`

#### 依赖
- 无（仅 `@kit.ArkUI` 装饰器 + 组件类型 + Color 枚举）

---

### 2. AlarmBanner.ets

#### Props/State 接口

```typescript
@Component
struct AlarmBanner {
  @Prop message: string;
  @Prop severity: string;
  @Prop onClose?: () => void;
  @Prop onTap?: () => void;
  build() {
    if (this.message === '') {
      /* 不渲染 */
    }
  }
}
export { AlarmBanner };
```

**Props 说明**：
- `message: string` —— 必填，告警文本；**约定**：`message === ''` 时不渲染
- `severity: string` —— 必填，与 `SeverityBadge.severity` 同语义（英文 `mild`/`moderate`/`severe`）
- `onClose?: () => void` —— 可选，关闭按钮点击回调
- `onTap?: () => void` —— 可选，横幅整体点击回调

#### 行为契约

- `message === ''` → `if (this.message === '')` 中跳过整个 `build()`（保证父组件可传空字符串隐藏）
- `severity === 'mild'` → 背景 `#E8F5E9`（浅绿）
- `severity === 'moderate'` → 背景 `#FFF3E0`（浅橙）
- `severity === 'severe'` → 背景 `#FFEBEE`（浅红）
- 其它值 → 背景 `#F5F5F5`（灰，兜底）
- 右上角"×"关闭按钮（`<Text>` + `onClick`）→ `this.onClose?.()`
- 整个横幅 `onClick` → `this.onTap?.()`

**实现要点**：
```typescript
build() {
  if (this.message === '') {
    return;  // 跳过渲染
  }
  Row() {
    Text(this.message)
      .layoutWeight(1)
    Text('×')
      .fontSize(20)
      .onClick(() => { this.onClose?.(); })
  }
  .backgroundColor(/* 根据 switch */)
  .padding(12)
  .onClick(() => { this.onTap?.(); })
}
```

#### 内部状态管理
- 无 `@State`——纯展示 + 回调型组件

#### 依赖
- 无

---

### 3. LoadingState.ets

#### Props/State 接口

```typescript
@Component
struct LoadingState {
  @Prop status: 'loading' | 'error' | 'empty';
  @Prop errorMessage: string;
  @Prop onRetry?: () => void;
  build() {
    /* 三态分支 + 错误文案兜底 */
  }
}
export { LoadingState };
```

**Props 说明**：
- `status: 'loading' | 'error' | 'empty'` —— 必填，三态枚举
- `errorMessage: string` —— 必填（字符串可为空 `''`）
  - **约定约束（非编译期）**：`status === 'error'` 时 `errorMessage` 必须提供非空字符串
  - 实现层兜底：`status === 'error' && errorMessage === ''` 时降级显示 `'加载失败，请重试'`
- `onRetry?: () => void` —— 可选，错误态"重试"按钮回调
  - **约定约束（非编译期）**：`status === 'error'` 时 `onRetry` 必须提供
  - 实现层不强制（Props 注释中标注约定）

#### 行为契约

- `status === 'loading'` → `<Progress type={ProgressType.Circular}>` + `<Text>加载中...</Text>`
- `status === 'error'` → 错误图标（`<Text>⚠</Text>`）+ `<Text>{显示文案}</Text>` + `<Button>重试</Button>`（`onClick: () => { this.onRetry?.(); }`）
- `status === 'empty'` → 空图标（`<Text>∅</Text>`）+ `<Text>暂无数据</Text>`

**实现要点**：
```typescript
build() {
  if (this.status === 'loading') {
    Column() {
      Progress({ type: ProgressType.Circular })
      Text('加载中...')
    }
  } else if (this.status === 'error') {
    Column() {
      Text('⚠').fontSize(32)
      Text(this.errorMessage !== '' ? this.errorMessage : '加载失败，请重试')
      Button('重试').onClick(() => { this.onRetry?.(); })
    }
  } else {
    Column() {
      Text('∅').fontSize(32)
      Text('暂无数据')
    }
  }
}
```

#### 内部状态管理
- 无 `@State`——纯展示 + 回调型

#### 依赖
- `@kit.ArkUI` 中的 `Progress` / `ProgressType.Circular` / `Button` / `Text` / `Column`

---

### 4. SensorCard.ets

#### Props/State 接口

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

**Props 说明**：
- `label: string` —— 必填，参数名（如"温度"）
- `value: number` —— 必填，数值
- `unit: string` —— 必填，单位后缀（如"℃"）
- `timestamp: string` —— 必填，ISO 时间字符串
  - **约定**：`timestamp === ''` 时显示 `'--'`
- `alarmLabels: string[] = []` —— 可选，告警标签数组（中文），默认 `[]`
  - 由父组件调用 `parseAlarmFlag(snapshot.alarm_flag)` 后传入

#### 行为契约

- 数值大字号显示（`fontSize(28)`）
- 末尾显示 `unit`（拼接或独立 Text）
- 底部显示 `Text(this.timestamp !== '' ? formatTimestamp(this.timestamp) : '--')`
- `alarmLabels.length > 0` → 背景 `#FFEBEE`（浅红告警色）；否则 `#FFFFFF`（默认白）

**实现要点**：
```typescript
import { formatTimestamp } from '../common/utils';

build() {
  Column() {
    Text(this.label).fontSize(14).fontColor(Color.Gray)
    Row() {
      Text(String(this.value)).fontSize(28).fontWeight(FontWeight.Bold)
      Text(this.unit).fontSize(14).fontColor(Color.Gray)
    }
    Text(this.timestamp !== '' ? formatTimestamp(this.timestamp) : '--')
      .fontSize(12)
      .fontColor(Color.Gray)
  }
  .padding(12)
  .backgroundColor(this.alarmLabels.length > 0 ? '#FFEBEE' : '#FFFFFF')
  .borderRadius(8)
}
```

#### 内部状态管理
- 无 `@State`——纯展示型

#### 依赖
- `common/utils.formatTimestamp`（从 `'../common/utils'` 导入）

---

### 5. DeviceSelector.ets

#### Props/State 接口

```typescript
import { AppStorage } from '@kit.ArkUI';
import { DeviceInfo } from '../common/models';

@Component
struct DeviceSelector {
  @Prop devices: DeviceInfo[];
  @State selectedIndex: number = 0;
  aboutToAppear() {
    AppStorage.setOrCreate('selectedDeviceId', '');
    // 读取 AppStorage 持久化值并同步到 selectedIndex（避免 UI 与持久化撕裂）
    const stored: string | undefined = AppStorage.get<string>('selectedDeviceId');
    if (stored !== undefined && stored !== '') {
      const idx: number = this.devices.findIndex((d: DeviceInfo) => d.device_id === stored);
      if (idx >= 0) {
        this.selectedIndex = idx;
      }
    }
  }
  build() {
    Select({
      options: this.devices.map((d: DeviceInfo) => { return { value: d.device_id }; }),
      selected: this.selectedIndex,
      onSelect: (index: number, value: string): void => {
        this.selectedIndex = index;
        AppStorage.set('selectedDeviceId', value);
      }
    });
  }
}
export { DeviceSelector };
```

**Props 说明**：
- `devices: DeviceInfo[]` —— 必填，设备列表（由父组件传入，**不**在组件内调用 `DeviceService`）

**内部状态**：
- `@State selectedIndex: number = 0` —— 当前选中索引

#### 行为契约

- `aboutToAppear()` → `AppStorage.setOrCreate('selectedDeviceId', '')`（**不带泛型**）初始化 AppStorage 键
  - 然后读取 AppStorage 持久值 `AppStorage.get<string>('selectedDeviceId')`
  - 若持久值非空且在 `devices` 列表中找到对应索引 → `this.selectedIndex = idx`
  - 若持久值为空或不在列表中 → `selectedIndex` 保持初始 0
  - **目的**：确保第二次启动时 UI 显示与 AppStorage 选中设备一致（避免反向撕裂）
- 用户切换选项（`onSelect` 回调，`value` 必填字符串） → `this.selectedIndex = index` + `AppStorage.set('selectedDeviceId', value)`
- 父 Page 层契约：通过 `@StorageLink('selectedDeviceId')` 监听变化触发数据刷新

**AppStorage 语义**（与 R4 Page 层契约）：
- **初始化**：`AppStorage.setOrCreate('selectedDeviceId', '')` 保证键存在（不覆盖已有值）
- **持久值同步**：`aboutToAppear` 中从 AppStorage 读取持久值并同步到 `selectedIndex`，消除二次启动 UI 与持久化撕裂
- **写入语义**：用户切换设备时 `AppStorage.set('selectedDeviceId', value)`
- **父 Page 层职责**：通过 `@StorageLink('selectedDeviceId')` 监听变化触发 Service 重新拉取

#### 内部状态管理
- `@State selectedIndex` —— 组件内 UI 状态

#### 依赖
- `@kit.ArkUI` 的 `Select` / `SelectOption` / `AppStorage`
- `common/models.DeviceInfo`（仅类型引用，**不**调用 `DeviceService`）

---

### 6. ChartView.ets

#### Props/State 接口

```typescript
@Component
struct ChartView {
  @Prop chartType: 'line' | 'bar' = 'line';
  @Prop dataPoints: number[];
  @Prop width: number = 360;
  @Prop height: number = 200;
  build() {
    if (this.chartType === 'line') {
      LineChartRenderer({ data: this.dataPoints, width: this.width, height: this.height });
    } else {
      BarChartRenderer({ data: this.dataPoints, width: this.width, height: this.height });
    }
  }
}
export { ChartView };
```

**Props 说明**：
- `chartType: 'line' | 'bar' = 'line'` —— 必填（带默认值），选择渲染器
- `dataPoints: number[]` —— 必填，Y 轴数据点数组
- `width: number = 360` —— 容器宽度（默认 360px）
- `height: number = 200` —— 容器高度（默认 200px）

#### 行为契约

- `chartType === 'line'` → 实例化 `LineChartRenderer` 并传递 `data` / `width` / `height`
- `chartType === 'bar'` → 实例化 `BarChartRenderer` 并传递 `data` / `width` / `height`
- **v1.0 不支持响应式重绘**（Canvas 限制）：父组件切换设备时通过 `key: 'chart-' + chartRebuildKey` 强制重建 ChartView 实例

**v1.0 简化方案**：
- `LineChartRenderer` 在 `onReady` 回调中获取 `CanvasRenderingContext2D` 并一次性绘制全部数据点
- 数据变更不触发自动重绘；父组件通过修改 `key` 重建

#### 内部状态管理
- 无 `@State`——纯容器/路由组件

#### 依赖
- `./LineChartRenderer`
- `./BarChartRenderer`
- `@kit.ArkUI` 装饰器

---

### 7. LineChartRenderer.ets

#### Props/State 接口

```typescript
@Component
struct LineChartRenderer {
  @Prop data: number[];
  @Prop width: number = 360;
  @Prop height: number = 200;
  @State private isReady: boolean = false;
  private context: CanvasRenderingContext2D | null = null;
  build() {
    Canvas(this.context)
      .width(this.width)
      .height(this.height)
      .onReady(() => {
        if (this.context !== null) {
          this.drawChart(this.context);
        }
        this.isReady = true;
      });
  }
  private drawChart(ctx: CanvasRenderingContext2D): void {
    /* 坐标轴 + 折线绘制 */
  }
}
export { LineChartRenderer };
```

**Props 说明**：
- `data: number[]` —— 必填，Y 轴数据点
- `width: number = 360` —— 画布宽度
- `height: number = 200` —— 画布高度

#### 行为契约

- `onReady` 回调中获取 `CanvasRenderingContext2D` 并调用 `drawChart` 一次性绘制
- 绘制逻辑：
  0. **空数组防御**：`if (data.length === 0) { return; }`（防止 `Math.min(...[])` 返回 `Infinity` 触发坐标计算异常）
  1. 清空画布：`ctx.clearRect(0, 0, width, height)`
  2. 绘制 X 轴：底部水平线
  3. 绘制 Y 轴：左侧垂直线
  4. 归一化数据：`const min = Math.min(...data)` / `const max = Math.max(...data)` / `const range = max - min || 1`
  5. 折线段绘制：`ctx.beginPath() / ctx.moveTo(...) / ctx.lineTo(...) / ctx.stroke()`
  6. 坐标值标记（可选）：在 X 轴下方标注索引
- **v1.0 范围**：
  - 单 Y 轴单折线
  - 无触摸交互
  - 无动画过渡
  - 静态绘制

#### 内部状态管理
- `@State private isReady: boolean = false` —— Canvas 初始化完成标记
- `private context: CanvasRenderingContext2D | null = null` —— 画布上下文引用

#### 依赖
- `@kit.ArkUI` 的 `Canvas` / `CanvasRenderingContext2D`

---

### 8. BarChartRenderer.ets

#### Props/State 接口

```typescript
@Component
struct BarChartRenderer {
  @Prop data: number[];
  @Prop width: number = 360;
  @Prop height: number = 200;
  @State private isReady: boolean = false;
  private context: CanvasRenderingContext2D | null = null;
  build() {
    Canvas(this.context)
      .width(this.width)
      .height(this.height)
      .onReady(() => {
        if (this.context !== null) {
          this.drawBars(this.context);
        }
        this.isReady = true;
      });
  }
  private drawBars(ctx: CanvasRenderingContext2D): void {
    /* 占位实现 */
  }
}
export { BarChartRenderer };
```

**Props 说明**：
- `data: number[]` —— 必填，柱高数据
- `width: number = 360` —— 画布宽度
- `height: number = 200` —— 画布高度

#### 行为契约

- `onReady` 回调中调用 `drawBars` 一次性绘制
- **v1.0 占位实现（明确为文字占位）**：仅调用 `ctx.fillText('BarChart v1.0 placeholder', 10, height / 2)` 渲染占位文字，不绘制矩形柱
  - 文字字体大小：14px
  - 文字位置：`(10, height / 2)`（左对齐、垂直居中）
- **不**实现柱状图交互

#### 内部状态管理
- `@State private isReady: boolean = false`
- `private context: CanvasRenderingContext2D | null = null`

#### 依赖
- `@kit.ArkUI` 的 `Canvas` / `CanvasRenderingContext2D`

---

### 9. ControlButton.ets

#### Props/State 接口

```typescript
@Component
struct ControlButton {
  @Link isOn: boolean;
  @Prop label: string;
  @Prop onToggle: (target: boolean) => Promise<void> = async (_: boolean): Promise<void> => { /* default no-op */ };
  @State private previousState: boolean = false;
  @State private isPending: boolean = false;
  build() {
    Button(this.isOn ? '已开启' : '已关闭')
      .onClick(() => { this.handleToggle(); })
      .enabled(!this.isPending);
  }
  private async handleToggle(): Promise<void> {
    const target: boolean = !this.isOn;
    this.previousState = this.isOn;
    this.isOn = target;  // 乐观 UI
    this.isPending = true;
    try {
      await this.onToggle(target);
    } catch (err: unknown) {
      this.isOn = this.previousState;  // 回滚
      console.error('ControlButton toggle error', JSON.stringify(err));
    } finally {
      this.isPending = false;
    }
  }
}
export { ControlButton };
```

**Props 说明**：
- `@Link isOn: boolean` —— 双向绑定父组件状态
  - **父组件约束（必填）**：父组件必须用 `@State isOn: boolean` 持有该变量（`@Link` 仅支持双向同步 `@State`，不接受 `@Prop` 或普通变量）
  - 父组件用法示例：
    ```typescript
    @State private isSprayOn: boolean = false;
    
    ControlButton({ isOn: $isSprayOn, label: '喷淋', onToggle: this.handleSpray });
    ```
- `@Prop label: string` —— 按钮标签（如"喷淋"）
- `@Prop onToggle: (target: boolean) => Promise<void>` —— 切换回调（父组件实现 `CommandService.send` 调用）

**内部状态**：
- `@State private previousState: boolean` —— 切换前状态（用于回滚）
- `@State private isPending: boolean` —— 加载中标记（点击后置 `true`，操作完成后置 `false`）

#### 行为契约

- 用户点击按钮：
  1. 记录 `previousState = this.isOn`
  2. **乐观 UI 翻转**：`this.isOn = !this.isOn`（通过 `@Link` 同步到父组件）
  3. 置 `isPending = true`（按钮 disabled）
  4. 异步调用 `onToggle(target)`（target 为新状态）
  5. 成功 → `isPending = false`
  6. 失败 → `this.isOn = previousState`（回滚）+ `console.error` + `isPending = false`

#### 内部状态管理
- `@Link isOn` —— 双向绑定
- `@State previousState` —— 回滚用
- `@State isPending` —— 加载中

#### 依赖
- `@kit.ArkUI` 的 `Button`
- 无其他模块依赖

---

### 10. PaginatedList.ets

#### Props/State 接口

```typescript
import { PaginatedData } from '../common/models';

@Component
struct PaginatedList<T> {
  // 父组件必须用 @Builder 标注该方法后传入：
  //   @Builder private renderItem(item: T, index: number): void { ... }
  //   <PaginatedList renderItem={this.renderItem} ... />
  @BuilderParam renderItem: (item: T, index: number) => void;
  @Prop loadPage: (page: number) => Promise<PaginatedData<T>>;
  @Prop pageSize: number = 20;
  @State private records: T[] = [];
  @State private currentPage: number = 1;  // 与后端分页约定一致：currentPage 从 1 开始（参考 API 文档）
  @State private hasMore: boolean = true;
  @State private isLoading: boolean = false;
  build() {
    List() {
      ForEach(this.records, (item: T, index: number) => {
        this.renderItem(item, index);
      })
    }
    .onScrollIndex((end: number) => {
      if (end >= this.records.length - 5 && this.hasMore && !this.isLoading) {
        this.loadNextPage();
      }
    })
  }
  aboutToAppear(): void {
    this.loadNextPage();
  }
  private async loadNextPage(): Promise<void> {
    this.isLoading = true;
    try {
      const data: PaginatedData<T> = await this.loadPage(this.currentPage);
      this.records = this.records.concat(data.records);
      this.hasMore = this.records.length < data.pagination.total;
      this.currentPage++;
    } catch (err: unknown) {
      console.error('PaginatedList load error', JSON.stringify(err));
    } finally {
      this.isLoading = false;
    }
  }
}
export { PaginatedList };
```

**Props 说明**：
- `@BuilderParam renderItem: (item: T, index: number) => void` —— 必填，列表项渲染模板
  - **父组件约束**：必须使用 `@Builder` 修饰方法后传入（ArkUI 严格模式要求 `@BuilderParam` 接收 `@Builder` 引用，不能是普通函数）
  - **父组件调用示例**：
    ```typescript
    @Builder private renderItem(item: DiseaseRecord, index: number): void {
      ListItem() { ... }
    }
    
    PaginatedList<DiseaseRecord>({
      renderItem: this.renderItem,
      loadPage: (page: number) => DiseaseService.getList(page, this.pageSize)
    });
    ```
- `@Prop loadPage: (page: number) => Promise<PaginatedData<T>>` —— 必填，分页加载函数（父组件实现 `DiseaseService.getList` 调用）
- `@Prop pageSize: number = 20` —— 每页条数（供父组件参考，本组件不直接使用）

**内部状态**：
- `@State records: T[]` —— 累计加载的记录
- `@State currentPage: number = 1` —— 下一页页码（**从 1 开始，与后端分页约定一致**）
- `@State hasMore: boolean` —— 是否还有更多
- `@State isLoading: boolean` —— 加载中标记

**ArkTS 泛型 `@BuilderParam` 兼容性**：泛型 `PaginatedList<T>` 的 `@BuilderParam` 字段在 ArkTS 编译期可能有限制；若 R3b 实施期遭遇编译错误，回退方案：使用 `as any` 转型或拆分为非泛型具体类型组件。

#### 行为契约

- `aboutToAppear` → 调用 `loadNextPage(1)` 加载第一页
- 滚动到 `end >= records.length - 5`（倒数第 5 条）时自动触发下一页加载
- 加载中时避免重复触发（`!this.isLoading`）
- 失败时 `console.error` 记录，不中断列表

#### 内部状态管理
- 全部状态由组件内部管理（`@State`），父组件不直接介入

#### 依赖
- `@kit.ArkUI` 的 `List` / `ForEach` / `@BuilderParam`
- `common/models.PaginatedData`（类型引用）

---

### 11. ImageViewer.ets

#### Props/State 接口

```typescript
import { image } from '@kit.ImageKit';
import { ImageService } from '../services/ImageService';
import { HttpClient } from '../services/HttpClient';

@Component
struct ImageViewer {
  @Prop imagePath: string;  // 服务端返回的相对路径（如 /images/.../img_xxx.jpg）
  @Prop imageId: string;    // 纯 ID（如 img_20260703_061500_021），用于降级路径
  @State private pixelMap: image.PixelMap | null = null;  // 降级路径解出的 PixelMap（类型与 stub 同步）
  @State private loadStatus: 'idle' | 'loading' | 'loaded' | 'error' = 'idle';
  build() {
    Stack() {
      if (this.loadStatus === 'loading') {
        Progress({ type: ProgressType.Circular });
      } else if (this.loadStatus === 'error') {
        Text('图片加载失败');
      } else {
        if (this.pixelMap !== null) {
          Image(this.pixelMap);
        } else {
          Image(HttpClient.BASE_URL + this.imagePath)
            .onError((_event?: object): void => { this.fallbackToPixelMap(); });
        }
      }
    }
  }
  private async fallbackToPixelMap(): Promise<void> {
    this.loadStatus = 'loading';
    try {
      const buf: ArrayBuffer = await ImageService.getImagePixelMap(this.imageId);
      const source: image.ImageSource = image.createImageSource(buf);
      const pm: image.PixelMap = await source.createPixelMap();
      this.pixelMap = pm;
      this.loadStatus = 'loaded';
    } catch (err: unknown) {
      this.loadStatus = 'error';
      console.error('ImageViewer fallback error', JSON.stringify(err));
    }
  }
}
export { ImageViewer };
```

**Props 说明**：
- `@Prop imagePath: string` —— 必填，URL 相对路径（主路径）
- `@Prop imageId: string` —— 必填，纯 ID（降级路径）

**内部状态**：
- `@State pixelMap: image.PixelMap | null` —— 降级路径解出的 PixelMap（与 `@kit.ImageKit` stub 同步声明，避免从 `object` 迁移到 `PixelMap` 时双向不兼容）
- `@State loadStatus` —— 加载状态

#### 行为契约

- **主路径**：`<Image src={HttpClient.BASE_URL + this.imagePath}>` 直接加载
  - 服务端对 `/images/...` 目录放行免鉴权
  - `onError` 触发 → 切换到降级路径
- **降级路径**：`ImageService.getImagePixelMap(imageId)` → `ArrayBuffer` → `image.createImageSource(buf).createPixelMap()` → `Image(pixelMap)`
- 加载中：`<Progress>` 居中
- 加载失败：显示"图片加载失败"占位

#### 内部状态管理
- `@State pixelMap` / `@State loadStatus` —— 降级路径状态

#### 依赖
- `services/HttpClient` 的 `BASE_URL`
- `services/ImageService` 的 `getImagePixelMap`
- `@kit.ImageKit` 的 `image.createImageSource` / `createPixelMap`（R3b 实施前需补全 stub）
- `@kit.ArkUI` 的 `Image` / `Progress` / `Stack`

---

### 12. ConnectivityIndicator.ets

#### Props/State 接口

```typescript
import { ConnectivityStatus } from '../common/models';

@Component
struct ConnectivityIndicator {
  @Prop status: ConnectivityStatus = 'loading';
  build() {
    Row() {
      Text(/* 根据 status 决定 */)
        .fontSize(10)
        .fontColor(Color.White)
    }
    .width('100%')
    .height(4)
    .backgroundColor(/* 根据 switch 决定 */)
  }
}
export { ConnectivityIndicator };
```

**Props 说明**：
- `@Prop status: ConnectivityStatus = 'loading'` —— 必填（带默认），联合类型 `'loading' | 'online' | 'offline'`
- **单位约定**：容器宽度使用字符串 `'100%'`（响应式自适应屏幕），高度使用数字 `4`（vp 单位，固定 4px 细条）

#### 行为契约

- `status === 'loading'` → 背景 `#FFC107`（黄），文字"连接中..."（可选）
- `status === 'online'` → 背景 `#4CAF50`（绿），文字"已连接"（可选）
- `status === 'offline'` → 背景 `#F44336`（红），文字"离线"（可选）
- **v1.0 简化为纯色条**（不显示文字），4px 高度，覆盖页面顶部

**实现要点**：
```typescript
build() {
  Row()
    .width('100%')
    .height(4)
    .backgroundColor(
      this.status === 'online' ? '#4CAF50' :
      this.status === 'offline' ? '#F44336' :
      '#FFC107'
    )
}
```

#### 内部状态管理
- 无 `@State`——纯展示型

#### 依赖
- `common/models.ConnectivityStatus`（类型引用）

---

## 装饰器使用策略汇总

| 装饰器 | 全局使用次数 | 出现组件 | 备注 |
|--------|-------------|---------|------|
| `@Component` | 12 | 全部 12 个组件 | ArkTS 组件 struct 标记 |
| `@Entry` | 0 | 无 | R4 页面层使用 |
| `@State` | 8 | DeviceSelector(1) / ControlButton(2) / PaginatedList(4) / ImageViewer(2) / LineChartRenderer(1) / BarChartRenderer(1) | 仅组件内部状态 |
| `@Prop` | ~30 | 全部展示型组件 | 父→子单向数据流 |
| `@Link` | 1 | ControlButton(`isOn`) | 双向绑定 |
| `@Builder` | 3-5 | ChartView / LineChartRenderer / ImageViewer / PaginatedList 父组件 | 方法级 UI 模板 |
| `@BuilderParam` | 1 | PaginatedList(`renderItem`) | 接收父组件模板 |
| `@StorageLink` | 0 | 无 | R4 Page 层使用 |
| `@StorageProp` | 0 | 无 | R4 Page 层使用 |
| `@Watch` | 0 | 无 | 本轮不引入（`@Link` 自身触发重绘） |

---

## Canvas 渲染策略

### v1.0 一次性绘制

`LineChartRenderer` / `BarChartRenderer` 内部 Canvas 绘制策略：

1. **`onReady` 回调触发一次性绘制**：在 Canvas 组件 `onReady` 中获取 `CanvasRenderingContext2D` 并执行完整绘制
2. **数据变更不触发自动重绘**：当 `@Prop data` 变化时（父组件修改），由于 ArkTS Canvas 不内置响应式重绘机制，**不**自动重绘
3. **父组件 key 强制重建**：父组件（如 `DashboardPage`）持有 `@State chartRebuildKey: string`，切换设备时 `chartRebuildKey = nowMs()`，ChartView 通过 `<ChartView key={'chart-' + chartRebuildKey} ... />` 强制重建实例，触发 `onReady` 重新绘制

**v1.0 限制声明**：
- 不支持触摸交互（`onTouch` 回调不实现）
- 不支持动画过渡
- 不支持局部刷新（每次重绘清空全画布）
- 不支持图例 / 多折线（仅单 Y 轴单折线）
- `BarChartRenderer` 占位实现（仅 2-3 根矩形或文字占位）

### R4 Page 层配合约束

`DashboardPage` 需维护：
```typescript
@State private chartRebuildKey: string = String(Date.now());

// 切换设备时
async onDeviceChange(newDeviceId: string): Promise<void> {
  AppStorage.set('selectedDeviceId', newDeviceId);
  this.chartRebuildKey = String(Date.now());  // 强制重绘图表
}
```

---

## AppStorage 双向同步方案

### 单一写入源 + 持久值读取

**DeviceSelector 是 `selectedDeviceId` AppStorage 键的唯一写入源**，同时在初始化时读取持久值。

| 操作 | 写入方/读取方 | 同步机制 |
|------|-------------|---------|
| 页面初始化（首次） | `DeviceSelector.aboutToAppear` → `AppStorage.setOrCreate(..., '')` | AppStorage 初始化保证 |
| 页面初始化（二次启动） | `DeviceSelector.aboutToAppear` → `AppStorage.get` → `selectedIndex` 同步 | 读取持久值匹配 devices 索引 |
| 用户切换设备 | `DeviceSelector.onSelect` → `AppStorage.set(value)` | ArkUI AppStorage 响应式 |
| 父组件读取 | R4 Page 层 `@StorageLink('selectedDeviceId')` | 自动响应变化 |

### 关键约束

- **DeviceSelector 在 aboutToAppear 中读取 AppStorage**：消除二次启动 UI 与持久化状态的撕裂
- **Page 层用 `@StorageLink`**：`@StorageLink('selectedDeviceId') selectedDeviceId: string` 自动响应变化
- **Page 层触发数据刷新**：监听 `selectedDeviceId` 变化 → 调用 `SensorService.getLatest(selectedDeviceId)`

### 初始化顺序

```
App 启动（二次）
  → Index Page 加载
  → DashboardPage aboutToAppear
    → 渲染 DeviceSelector
      → DeviceSelector.aboutToAppear
        → AppStorage.setOrCreate('selectedDeviceId', '')  // 已存在则保留
        → AppStorage.get<string>('selectedDeviceId')    // 读取持久值
        → selectedIndex 同步到对应索引                  // UI 与持久化一致
    → 渲染其他 SensorCard（@Prop 驱动）
```

---

## 错误处理与边界

### 通用边界

| 场景 | 行为 | 涉及组件 |
|------|------|---------|
| `props` 为空字符串 | 显示占位或默认文案 | SensorCard(timestamp) / AlarmBanner(message) |
| `props` 为空数组 | 不渲染告警高亮 | SensorCard(alarmLabels) |
| `props` 为默认值（`''`/`[]`） | 不抛错，安全降级 | 全部展示型组件 |
| 回调函数未提供 | `this.onTap?.()` 安全调用 | AlarmBanner / LoadingState / ControlButton |
| Canvas 初始化失败 | 降级为空白画布 | LineChartRenderer / BarChartRenderer |
| 网络图片加载失败 | 切换到降级 PixelMap 路径 | ImageViewer |
| PixelMap 解码失败 | 显示"图片加载失败"占位 | ImageViewer |

### 组件级边界

**SensorCard**：
- `timestamp === ''` → 显示 `'--'`
- `value` 为合法 number → 直接显示（含 0，0℃/0% 等都是合法传感器值）
- `alarmLabels` 为 undefined → 走默认值 `[]`（ArkTS 默认值生效）

**AlarmBanner**：
- `message === ''` → `if` 跳过整个 build，不渲染
- `severity` 为未知值 → 灰色兜底

**LoadingState**：
- `status === 'error' && errorMessage === ''` → 兜底显示 `'加载失败，请重试'`（**不 throw**）
- `onRetry` 未提供 → `this.onRetry?.()` 静默无操作

**DeviceSelector**：
- `devices.length === 0` → `<Select>` 渲染空选项（不抛错）；`aboutToAppear` 中 `findIndex` 返回 -1 → `selectedIndex` 保持 0
- AppStorage 已存在值 → `setOrCreate` 不覆盖（保留已有值）；`aboutToAppear` 读取持久值后按 `device_id` 匹配索引同步 `selectedIndex`

**ControlButton**：
- `onToggle` 抛错 → `isOn = previousState` 回滚 + `console.error` 记录
- `onToggle` 永久 pending → `isPending = true` 卡死（v1.0 限制，不引入超时）

**PaginatedList**：
- `loadPage` 抛错 → `console.error` 记录，已有数据保留，`hasMore` 不变更
- 重复触发 → `isLoading` 守卫避免

**ImageViewer**：
- 主路径 `onError` → 自动切换降级路径
- 降级路径 `getImagePixelMap` 抛错 → 显示"图片加载失败"占位

**ConnectivityIndicator**：
- `status` 为未知值 → 走 `default` 分支（黄/灰）

### 不在组件层处理的错误

- **网络层错误**：由 `HttpClient` / `Service` 层抛出，组件层不捕获（不持有异步副作用）
- **Service 业务错误**：由 R4 Page 层捕获后通过 `LoadingState` 展示
- **AppStorage 写入失败**：不显式处理（ArkUI AppStorage 内建容错）

---

## 依赖关系图

### 组件层 → common 层

```
components/SeverityBadge
  └─→ (无)

components/AlarmBanner
  └─→ (无)

components/LoadingState
  └─→ (无)

components/SensorCard
  └─→ common/utils (formatTimestamp)

components/DeviceSelector
  ├─→ @kit.ArkUI (Select, SelectOption, AppStorage)
  └─→ common/models (DeviceInfo)

components/ChartView
  ├─→ components/LineChartRenderer
  └─→ components/BarChartRenderer

components/LineChartRenderer
  └─→ @kit.ArkUI (Canvas, CanvasRenderingContext2D)

components/BarChartRenderer
  └─→ @kit.ArkUI (Canvas, CanvasRenderingContext2D)

components/ControlButton
  └─→ @kit.ArkUI (Button)

components/PaginatedList
  ├─→ @kit.ArkUI (List, ForEach, @BuilderParam)
  └─→ common/models (PaginatedData)

components/ImageViewer
  ├─→ services/HttpClient (BASE_URL)
  ├─→ services/ImageService (getImagePixelMap)
  └─→ @kit.ImageKit (image.createImageSource, createPixelMap)

components/ConnectivityIndicator
  └─→ common/models (ConnectivityStatus)
```

### 完整依赖拓扑

```
components/
    ├─→ common/ (models, utils)  // 类型 + 工具函数
    ├─→ @kit.ArkUI               // 装饰器 + 组件类型
    └─→ services/                // 仅 ImageViewer（HttpClient.BASE_URL + ImageService）
```

**关键约束**：
- 5 个基础组件（R3a）**仅**依赖 `common/` + `@kit.ArkUI`
- 7 个进阶组件（R3b）中：
  - 5 个（ChartView/LineChartRenderer/BarChartRenderer/ControlButton/PaginatedList）**仅**依赖 `@kit.ArkUI` + `common/`
  - 1 个（ImageViewer）依赖 `services/` + `@kit.ImageKit`
  - 1 个（ConnectivityIndicator）仅依赖 `common/`

### 暴露给 R4 Page 层的公开接口

| 组件 | Props 签名 | R4 消费者 |
|------|-----------|-----------|
| `SeverityBadge` | `severity: string` | DiseaseRecordsPage（列表项） |
| `AlarmBanner` | `message, severity, onClose?, onTap?` | Index, DashboardPage |
| `LoadingState` | `status, errorMessage, onRetry?` | 全部 Page |
| `SensorCard` | `label, value, unit, timestamp, alarmLabels?` | Index, DashboardPage |
| `DeviceSelector` | `devices: DeviceInfo[]` | Index, DashboardPage |
| `ChartView` | `chartType, dataPoints, width?, height?` | DashboardPage |
| `LineChartRenderer` | `data, width?, height?` | （ChartView 内部使用） |
| `BarChartRenderer` | `data, width?, height?` | （ChartView 内部使用） |
| `ControlButton` | `isOn: @Link, label, onToggle` | ControlPage |
| `PaginatedList<T>` | `renderItem: @BuilderParam, loadPage, pageSize?` | DiseaseRecordsPage |
| `ImageViewer` | `imagePath, imageId` | DiseaseRecordsPage（详情） |
| `ConnectivityIndicator` | `status: ConnectivityStatus` | 全部 Page |

---

## 编译验证基线

### 验证命令

```bash
hvigorw assembleHap --mode module -p product=default
```

**应满足**：
- exit code = 0
- 无 `error:` 行
- 允许 `warning:` 行

### R2 等价验证（本地无 hvigorw）

完整可执行验证脚本（每一步指定明确的工作目录）：

```bash
# 1. 同步源文件到验证环境（4 层路径约定 src-ts/main/ets/...，与 tsconfig.json include 一致）
rm -rf /tmp/arkts-check/src-ts
mkdir -p /tmp/arkts-check/src-ts/main/ets/common
mkdir -p /tmp/arkts-check/src-ts/main/ets/services
mkdir -p /tmp/arkts-check/src-ts/main/ets/entryability
mkdir -p /tmp/arkts-check/src-ts/main/ets/components
cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/common/*.ets       /tmp/arkts-check/src-ts/main/ets/common/
cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/services/*.ets      /tmp/arkts-check/src-ts/main/ets/services/
cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/entryability/*.ets  /tmp/arkts-check/src-ts/main/ets/entryability/
cp E:/dev/wheat-tea-iot/harmony-app/entry/src/main/ets/components/*.ets    /tmp/arkts-check/src-ts/main/ets/components/

# 2. 派生 .ts 副本（在每个组件目录内执行，确保 *.ets 匹配到）
cd /tmp/arkts-check/src-ts/main/ets/common
for f in *.ets; do base=$(basename "$f" .ets); cp "$f" "$base.ts"; done

cd /tmp/arkts-check/src-ts/main/ets/services
for f in *.ets; do base=$(basename "$f" .ets); cp "$f" "$base.ts"; done

cd /tmp/arkts-check/src-ts/main/ets/entryability
for f in *.ets; do base=$(basename "$f" .ets); cp "$f" "$base.ts"; done

cd /tmp/arkts-check/src-ts/main/ets/components
for f in *.ets; do base=$(basename "$f" .ets); cp "$f" "$base.ts"; done

# 3. tsc strict 检查
cd /tmp/arkts-check && tsc --noEmit -p .
```

### 验收标准

- tsc exit 0，0 errors
- 12 个组件文件全部通过 strict 模式类型检查
- 5 个 R3a 组件零外部 Kit 依赖（除 `@kit.ArkUI`）
- 7 个 R3b 组件 stub 依赖齐全（`@kit.ArkUI` 的 Canvas 类型 + `@kit.ImageKit` 的 image 类型）

---

## R3 偏差说明（与 plan_task.md 的差异）

| 偏差项 | plan_task.md 描述 | 本设计实现 | 原因 |
|--------|-----------------|-----------|------|
| **范围拆分** | R3a 5 个 + R3b 7 个 | 本设计**统一覆盖 12 个** | 一次提交完整设计规格，编码期按 R3a/R3b 分批执行 |
| **`DeviceSelector` AppStorage 初始化** | `AppStorage.setOrCreate('selectedDeviceId', '')` + 读取持久值同步 `selectedIndex` | **R3 r1 修订**：删除"不读 AppStorage"原方案，改为读取持久值消除反向撕裂 |
| **`DeviceSelector` 不读 AppStorage** | selectedIndex 初始 0 | **R3 r1 修订**：改为`aboutToAppear` 读取持久值，按 device_id 匹配索引后同步 `selectedIndex`，避免二次启动反向撕裂 |
| **`SensorCard.alarmLabels`** | `string[]` 默认 `[]` | 同 plan_task.md | r1/r2 遗留 #5 已闭合 |
| **`SeverityBadge` / `AlarmBanner` severity** | `string` | 同 plan_task.md | r1/r2 遗留 #6/#9 已闭合 |
| **`LoadingState.errorMessage`** | 不使用 `@Require` | 同 plan_task.md | r1/r2 #4 修正 |
| **`LoadingState.onRetry`** | 约定约束 | 同 plan_task.md | r1/r2 #10 修正 |
| **`ConnectivityIndicator` 顶层 `@Builder` export** | 不提供 | 同 plan_task.md | r1/r2 #6 修正，仅组件形式 |
| **`ImageViewer` 主路径** | `<Image src={baseURL + path}>` | 同 plan_task.md | 直连 + 降级双路径 |
| **`LineChartRenderer` v1.0 范围** | 单 Y 轴单折线，无触摸 | 同 plan_task.md | v1.0 简化方案 |
| **`BarChartRenderer` v1.0** | 预留架构 | **本设计明确为文字占位**（`fillText('BarChart v1.0 placeholder', 10, height/2)`），不绘制矩形柱 | 文字占位更简洁，与 plan_task.md"占位实现"一致 |
| **`PaginatedList` 泛型参数** | 内部使用 `T` | 同 plan_task.md | 类型复用支持任意记录类型 |
| **`ControlButton` `@Link isOn`** | `@Link` 双向绑定 | 同 plan_task.md | r1/r2 明确 `@Link` 而非 `@Prop` |
| **Canvas 重绘策略** | 父组件 key 强制重建 | 同 plan_task.md | v1.0 简化方案 |
| **i18n** | 硬编码中文 | 同 plan_task.md | R5+ 提取资源 |

### R3b 单独注意事项

R3b 实施前需补全的 stub（在 `/tmp/arkts-check/stubs/` 下）：

1. **`kit-arkui.d.ts`** 补全：

   全部组件类（`Row` / `Column` / `Text` / `Button` / `Image` / `List` / `Canvas` 等）必须在 `declare module '@kit.ArkUI'` 块**内**以 `export class` 形式声明，避免全局 `declare class` 与 ArkUI 真实导入路径不一致。完整补全内容（节选）：
   - ArkUI 全局装饰器（10 个）：`@Component` / `@Entry` / `@State` / `@Prop` / `@Link` / `@Builder` / `@BuilderParam` / `@Watch` / `@StorageLink` / `@StorageProp`
   - 组件类（作为 `declare module '@kit.ArkUI'` 的 `export class`，**非**全局声明）：`Row` / `Column` / `Text` / `Button` / `Image`（含 `onError(callback: (event?: object) => void)`）/ `List` / `ForEach` / `Stack` / `Canvas` / `Progress`
   - `CanvasRenderingContext2D` 接口（含 `clearRect` / `beginPath` / `moveTo` / `lineTo` / `stroke` / `fillText` 等方法，`onReady` 回调类型 `(event?: object) => void`）
   - `ProgressType` 枚举（`Circular` / `Linear` 等）
   - `SelectOption` / `SelectAttribute`（`onSelect(callback: (index: number, value: string) => void)`——`value` 必填，与 ArkUI 实际签名一致）
   - `AppStorage` 类（`setOrCreate(key, value)` / `set(key, value)` / `get<T>(key)` / `has` / `delete` / `keys`，泛型参数不要求调用方显式标注）
   - `promptAction.showToast` / `showDialog`（R3b 准备）

2. **`kit-image.d.ts`** 新建：

   完整 stub 模板：

   ```typescript
   // /tmp/arkts-check/stubs/kit-image.d.ts
   declare type AsyncCallback<T> = (err: BusinessError | null, data?: T) => void;
   declare interface BusinessError extends Error {
     code: number;
     name: string;
     message: string;
   }

   declare module '@kit.ImageKit' {
     export namespace image {
       // 图像像素图接口
       export interface PixelMap {
         getWidth(): number;
         getHeight(): number;
         getPixelBytes(): ArrayBuffer;
         release(): void;
       }

       // 图像源接口（createImageSource 返回值）
       export interface ImageSource {
         createPixelMap(options?: object): Promise<PixelMap>;
       }

       // 工厂函数：从 ArrayBuffer 创建图像源
       export function createImageSource(buf: ArrayBuffer | string): ImageSource;
     }
   }
   ```

   类型映射说明：
   - `pixelMap` 字段类型为 `image.PixelMap | null`（不是 `object | null`），与 stub 同步
   - `source` 字段类型为 `image.ImageSource`
   - `createPixelMap()` 返回类型为 `Promise<image.PixelMap>`

3. **`tsconfig.json`** 追加：
   - `paths` 中新增 `"@kit.ImageKit": ["stubs/kit-image.d.ts"]`
   - `include` 中确认 `src-ts/main/ets/components/**/*.ts`

---

## 风险与边界声明

| 风险点 | 边界 / 缓解 |
|--------|------------|
| `LineChartRenderer` 一次性绘制不支持响应式重绘 | v1.0 范围内接受；父组件通过 `key` 强制重建 |
| `PaginatedList<T>` 泛型组件在 ArkTS 中可能限制 | 泛型用于内部状态类型推断；R4 调用时需提供具体类型 |
| `ImageViewer` 降级路径异步 `createPixelMap` 抛错 | catch 后 `loadStatus = 'error'`，不崩溃 |
| `ControlButton` `@Link` 父组件需 `@State` | 文档注释中明确；R4 Page 层 `isOn` 用 `@State` 持有 |
| `DeviceSelector` 读取 AppStorage 持久值同步 `selectedIndex` | 在 `aboutToAppear` 中读取 `AppStorage.get` 后按 `device_id` 匹配索引，避免二次启动 UI 与持久化撕裂 |
| `BarChartRenderer` 仅占位 | v1.0 不要求完整柱状图；ChartView `chartType === 'bar'` 切换时可见占位效果 |
| `PaginatedList` `@BuilderParam` 父组件需用 `@Builder` 方法提供 | R4 调用约定文档化 |
| `ImageViewer` `@State pixelMap: image.PixelMap \| null` 强类型 | 与 `@kit.ImageKit` stub 同步声明；不采用 `object` 弱类型（避免双向不兼容） |

---

## 修订说明（R3 DR=2）

本轮处理 R3 DR=1 审查报告（design_review_r1.md）的 13 项反馈（2 严重 + 6 一般 + 5 轻微）。

| # | 严重度 | 审查意见 | 修改措施 |
|---|--------|----------|----------|
| 1 | 严重 | `ImageViewer.pixelMap: object \| null` 与 ImageKit stub 双向不兼容 | 改为 `@State pixelMap: image.PixelMap \| null`，与 R3b `kit-image.d.ts` stub 同步声明 `PixelMap` / `ImageSource` 接口；`source: image.ImageSource`、`createPixelMap(): Promise<image.PixelMap>` 全部同步精化 |
| 2 | 严重 | `DeviceSelector.selectedIndex` 始终为 0，与 AppStorage 持久值撕裂 | `aboutToAppear` 中增加 `AppStorage.get<string>('selectedDeviceId')` 读取，按 `device_id` 匹配 `devices` 索引后同步 `selectedIndex`；同时修正 `onSelect` 中 `value: string` 必填，直接用 `value` 写 AppStorage |
| 3 | 一般 | `PaginatedList.@BuilderParam` 父组件约束未明确 | Props 注释明确"父组件必须用 `@Builder` 标注该方法后传入"；给出父组件调用示例代码；增加泛型 `@BuilderParam` ArkTS 兼容性回退方案说明 |
| 4 | 一般 | `ControlButton.@Link isOn` 父组件约束未在 Props 注释中标注 | Props 注释追加"父组件必须用 `@State isOn: boolean` 持有该变量（`@Link` 仅支持双向同步 `@State`）"；给出父组件用法示例 |
| 5 | 一般 | `ImageViewer.onError` 回调签名与 stub 不一致 | 改为 `.onError((_event?: object): void => { ... })`，与 ArkUI 标准 `onError(callback: (event?: object) => void)` 一致 |
| 6 | 一般 | `DeviceSelector.onSelect` 回调 `value?: string` 与 ArkUI 实际签名不一致 | 改为 `value: string` 必填；组件实现直接用 `value` 写 AppStorage，去掉 `this.devices[index].device_id` 冗余查找 |
| 7 | 一般 | 编译验证脚本 mkdir/cp/for 路径不连续 | 重写完整脚本：每步明确 `cd` 到目标目录后执行；分目录独立派生 .ts 副本，避免单次 for 循环路径错乱 |
| 8 | 一般 | stub 组件类全局 `declare class` 与 ArkUI 真实导入路径不一致 | R3b 补全 stub 章节明确全部组件类必须作为 `declare module '@kit.ArkUI'` 内 `export class` 声明；列出 kit-arkui.d.ts 完整补全清单（10 装饰器 + 10 组件类 + ProgressType/SelectOption/AppStorage 等） |
| 9 | 轻微 | `ConnectivityIndicator` 高度/宽度单位混用 | Props 注释追加单位约定说明："宽度 `'100%'`（响应式）+ 高度数字 `4`（vp，固定 4px 细条）" |
| 10 | 轻微 | `BarChartRenderer` 占位实现路径含糊（文字 vs 矩形柱） | 明确选择文字占位：`ctx.fillText('BarChart v1.0 placeholder', 10, height/2)`，去掉"或 2-3 根矩形柱"分支 |
| 11 | 轻微 | `PaginatedList.currentPage` 起始值与后端分页约定未引用 | Props 注释追加"currentPage 从 1 开始，与后端分页约定一致（参考 `docs/3_client-api-reference.md`）" |
| 12 | 轻微 | `LineChartRenderer.drawChart` 空数组导致 `Infinity` 坐标 | 绘制逻辑第 0 步加空数组防御 `if (data.length === 0) { return; }`，作为步骤 0 放在所有计算前 |
| 13 | 轻微 | `SensorCard` 边界"value === 0"表述易误导 | 改为"`value` 为合法 number → 直接显示（含 0，0℃/0% 等都是合法传感器值）"，删除歧义 |
| 补充 | — | R3b `kit-image.d.ts` 之前仅提接口名，无完整 stub 模板 | 在 R3b 注意事项中给出完整 stub 模板（含 `PixelMap` 接口 + `getPixelBytes` 等方法 + `createImageSource(buf) → ImageSource` + `ImageSource.createPixelMap() → Promise<PixelMap>`） |

---

## 配置与依赖清单

### 第三方 SDK 依赖

| 模块 | 用途 | 消费组件 |
|------|------|---------|
| `@kit.ArkUI` | 装饰器 + 组件类型 + AppStorage | 全部 12 个 |
| `@kit.ImageKit` | `image.createImageSource` / `createPixelMap` | ImageViewer（R3b） |

### 不变更的文件

- `harmony-app/entry/oh-package.json5`
- `harmony-app/oh-package.json5`
- `harmony-app/entry/src/main/module.json5`
- `harmony-app/entry/src/main/resources/base/profile/main_pages.json`
- `harmony-app/entry/src/main/ets/common/*.ets`（6 个 R1 固化文件）
- `harmony-app/entry/src/main/ets/services/*.ets`（7 个 R2 固化文件）
- `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets`（R1 固化）
- `harmony-app/entry/src/main/ets/entrybackupability/EntryBackupAbility.ets`
- `harmony-app/entry/src/main/ets/pages/Index.ets`（保持 Hello World 模板）
