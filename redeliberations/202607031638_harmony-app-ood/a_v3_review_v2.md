# OOD 设计方案审查报告（v6）

## 审查结果

APPROVED

## 逐维度审查

### 1. 类型系统可行性

**[通过]** 数据模型全部使用 `interface`，组件使用 `@Entry` + `@Component` 装饰器，符合 ArkTS 约束。

**[通过]** `@State` / `@Prop` / `@Link` 的装饰器选择与 ArkUI API 21 能力完全匹配。`@Link` 的 `$variable` 引用传递语法与参考项目 `DisplayPage.ets` 中 `LampControlButton` 的使用模式一致。

**[通过]** 泛型抽象 `ApiResponse<T>`、`CacheEntry<T>`、`PaginatedData<T>` 在 ArkTS 泛型系统能力范围内。

**[通过]** 联合类型 `'loading' | 'online' | 'offline'`、`'mild' | 'moderate' | 'severe'` 为 ArkTS 原生支持。

**[通过]** `type PollingCallback = () => Promise<void>` 显式类型定义有效，ArkTS 模块级 `export type` 语法支持。

**[通过]** `ChartRendererAPI` 接口用于图表渲染器策略模式——ArkTS `interface` 仅提供编译时结构类型检查，不要求运行时实现继承，设计中渲染器切换基于 `@Prop chartType` 条件逻辑而非 `instanceof`，模式可行。

**[轻微]** `TextResult` / `BinaryResult` 联合类型替代原 `NetworkResult`：ArkTS 支持联合类型，但 `api.ets` 内部返回区分需通过运行时判别（如类型守卫或结构判别），建议在后续实现层明确判别策略。

### 2. 标准库与生态覆盖

**[通过]** `@ohos.net.http` 作为 HTTP 传输层基础，`http.createHttp()`/`destroy()` 生命周期管理、`expectDataType: ARRAY_BUFFER`、`createMultipartFormData()` 均与标准库能力匹配。

**[通过]** `promptAction.showToast()`、`router.pushUrl()`/`replaceUrl()`、`Image(src)` 组件均为 ArkUI 标准 API，在参考项目中已验证。

**[通过]** `ArrayBuffer` → `ImageSource` → `PixelMap` 解码链为 ArkTS 原生能力（`@ohos.multimedia.image`），降级路径方案可行。

**[通过]** `BusinessError` 来自 `@kit.BasicServicesKit`，在参考项目中已验证使用。

**[通过]** `@Builder` 用于 `ConnectivityIndicator` 的页面内嵌渲染——ArkUI 支持 `@Builder` 装饰的函数和方法。

### 3. 语言特性可行性

**[通过]** 错误处理策略：`catch((err: BusinessError)` 约定与参考项目 `DisplayPage.ets:262` 一致。

**[通过]** 并发设计：`async/await` + `@ohos.net.http` 回调异步模型不阻塞 UI 线程，与 ArkTS 单线程事件循环模型兼容。

**[通过]** `PollingManager` 串行模式（递归 `setTimeout` 替代 `setInterval`）在 ArkTS 中完全可行——`setTimeout` 为全局 API，递归调用不产生栈溢出（因异步回调在下一事件循环执行，调用栈已清空）。

**[通过]** `EntryAbility.onBackground()` → `PollingManager.suspendAll()` 方案可行——`PollingManager` 为模块级单例，`EntryAbility` 可直接导入调用。

**[通过]** 模块结构 `pages/ → services/ → common/` 依赖方向清晰，ArkTS 模块系统天然支持。

**[通过]** `aboutToAppear()` 中通过 `loadData().catch(...)` 触发异步加载的写法与参考项目 `initData()` 模式一致（参考项目使用 `.then().catch()` 非 `await` 语法）。

**[通过]** 缓存键命名约定（`sensor_latest_`、`device_list_` 等前缀）不使用运行时反射或动态类型，纯字符串拼接，完全符合 ArkTS 限制。

### 4. 设计一致性

**[通过]** 核心抽象 §1-§21 职责描述清晰，各 Service 职责边界明确。

**[通过]** 场景 A-F 的行为覆盖了全部核心协作链路，无缺失环节。

**[通过]** `connectivityStatus` 状态转换矩阵（§错误处理策略）覆盖 `loading→online→offline→online` 完整闭环，转换规则与 §12 的 `loadData()` catch 逻辑对齐。

**[通过]** `ControlButton` 的 `@Link` 决策与场景 B 的乐观 UI 回滚行为一致，`aboutToUpdate` 引用已移除。

**[通过]** `AlarmBanner` 核心抽象 §17 补充完成，包含 `@Prop message: string`、`@Prop severity`、点击跳转和关闭交互。

**[通过]** `@State alarmMessage/alarmSeverity` 已在 §12 页面组件 `@State` 列表中声明。

**[通过]** `PollingManager` 串行定时漂移行为已在职责描述中明确标注，包含有效频率公式和设计意图。

**[通过]** 模块间依赖方向无循环依赖：`pages/ → services/ → common/`，`components/ → common/models.ets`，`services/ → common/`。

**[一般]** §19 `ImageViewer` 降级路径引用 `ImageService.getImagePixelMap(imageId)`，但 §8 `ImageService` 核心抽象中未定义此方法（§8 仅声明 `getRaw(path)` 返回 `ArrayBuffer`）。降级路径需要 `ArrayBuffer → ImageSource → PixelMap` 解码链，`getImagePixelMap` 方法缺失或职责归属不明确。

### 5. 设计质量

**[通过]** 职责划分遵循 SRP——Service 层仅做数据获取和转换，不持有 UI 状态；页面层仅关注状态和渲染。

**[通过]** 两层 HTTP 封装（`api.ets` 原始传输层 + `HttpClient` 业务门面层）职责划分清晰，便于单元测试（可 mock `api.ets` 层）。

**[通过]** `PollingManager` 集中管理轮询生命周期，消除各页面各自 `setInterval` 的残留风险。

**[通过]** 决策 5（`@State` 本地状态而非全局状态管理）对于 5 页规模的应用避免了 ArkTS 缺乏成熟全局状态库的困境。

**[通过]** 乐观 UI 回滚策略参考了参考项目 `DisplayPage.ets` 的灯控制模式，`@State previousState` 保存 + 失败回滚的模式可直接映射到实现。

**[通过]** `CacheManager` + `RetryPolicy` 作为独立基础设施，可 mock、可替换。

**[一般]** §19 `ImageViewer` 降级路径的 `ArrayBuffer → PixelMap` 解码职责归属未明确：若归属 `ImageService`，应在 §8 补充 `getPixelMap(imageId): Promise<PixelMap>` 方法；若归属 `ImageViewer`，应由 `ImageViewer` 直接调用 `ImageService.getRaw()` 后自行解码。当前设计在 §8 和 §19 之间存在不一致描述。

**[轻微]** `PollingCallback` 定义于 `common/models.ets`——该文件本为数据模型定义集合，轮询回调类型属行为类型而非数据模型，建议考虑放置在 `PollingManager.ets` 中并与使用处同文件导出。

**[轻微]** 各页面 `@State connectivityStatus` 初始值 `'online'` 的设计避免了启动闪白，但初始为 `'online'` 时 `ConnectivityIndicator` 显示绿色，`aboutToAppear` 立即切换为 `'loading'`（黄色），存在短暂闪烁窗口。建议在实现层评估是否初始为 `'loading'` 更优。

## 修改要求（REJECTED 时存在）

（无 — APPROVED）

## 处理说明

- 第 4 维度的一般问题：§19 和 §8 之间 `getImagePixelMap` 方法职责归属不一致，需在实现前明确归属方
- 第 5 维度的一般问题：`ArrayBuffer → PixelMap` 解码职责链需在后续详细设计中闭环，建议在 `ImageService` 中补充 `getPixelMap(imageId): Promise<PixelMap>` 方法或明确标注解码在 `ImageViewer` 侧完成
- 其余 2 项为轻微改进建议，不阻塞通过
