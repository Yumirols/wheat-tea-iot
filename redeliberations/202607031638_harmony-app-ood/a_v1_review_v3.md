# OOD 设计方案审查报告（v3）

## 审查结果

APPROVED

## 逐维度审查

### 1. 类型系统可行性

**[通过]** 所有类型形态选择均与 ArkTS 类型系统能力匹配：
- 数据模型使用 `interface` → 与 `JSON.parse()` 天然兼容，编译期类型检查，运行时无开销
- `api.ets` 选择纯函数导出（模块级函数）→ ArkTS 模块级导出即可满足，无需类的继承体系
- `HttpClient` 选择模块级变量单例 → `export const` 天然实现，ArkTS 中无需类构造
- Service 层与组件层使用函数/模块导出 → 无需继承体系，ArkTS 支持充分
- 页面组件使用 `@Entry` + `@Component` + `struct` → 标准 ArkUI 范式
- 泛型方法 `get<T>()` / `post<T>()` → ArkTS 基础泛型能力覆盖，`ApiResponse<T>` / `PaginatedData<T>` 等标准泛型模式均可行
- `@Prop` / `@Link` 装饰器数据流 → 与 ArkUI 声明式设计语义一致
- `getRaw()` 返回 `ArrayBuffer` → `http.HttpResponse.result` 支持 `ArrayBuffer` 类型，兼容

**[轻微]** `NetworkResult` 接口定义 `rawBody: string`，但 `getRaw()` 二进制路径需要 `ArrayBuffer` 类型。`api.ets` 的返回值类型应覆盖 `string | ArrayBuffer` 两种场景（`http.HttpResponse.result` 原始类型即为 `string | Object | ArrayBuffer`），实现时需对齐。

### 2. 标准库与生态覆盖

**[通过]** 所有依赖的标准库能力均可获得：
- `@ohos.net.http` → 用于 `api.ets` 原始传输层
- `@kit.PerformanceAnalysisKit` (hilog) → 日志记录
- `@ohos.promptAction` → Toast 提示
- `@kit.ArkUI` 的 `router` → 页面导航
- ArkUI `Canvas` → `ChartView` 趋势图绘制（有 Canvas 原生组件支持，`Chart` 为可选方案）
- `setInterval` → 轮询调度
- `BusinessError` (`@kit.BasicServicesKit`) → 异步错误捕获
- `multipart/form-data` → `http.MultiFormData` 类可构建表单数据
- `module.json5` `ohos.permission.INTERNET` → 已参照参考项目确认
- 参考项目 `DisplayPage.ets` 中的 `@Link` + `Progress` 加载态、`promptAction.showToast` 错误反馈、`setInterval` 轮询等模式均与设计一致

**[轻微]** ArkUI 标准库当前没有专用的 Chart 组件（`@ohos.ohos.chart` 非标准 ArkUI 发行组件），`ChartView` 的实现需依赖 `Canvas` 自绘或引入第三方图表组件。此问题在实现阶段可解决，不阻塞设计。

### 3. 语言特性可行性

**[通过]** 设计覆盖了 ArkTS 的核心语言特性约束：
- 错误处理：`try-catch` + `async/await` + `BusinessError` 模式与参考项目 `DisplayPage.ets` / `landing.ets` 一致
- 网络请求异步模型：`async/await` 非阻塞 + `setInterval` 轮询，UI 状态更新在 `await` 恢复后的主线程上下文中执行
- `http.createHttp()` 生命周期管理（每次请求创建新实例、完成后销毁）已在设计层面明确，防止资源泄漏
- 模块/包结构（`pages/` → `services/` → `common/`）清晰地反映了依赖方向，无循环依赖
- 无全局可变状态共享（API Key 仅 `HttpClient` 持有，设备 ID 通过 `router` 参数传递），避免了跨页面状态同步问题

**[轻微]** 设计描述中多处引用 `null`（来自 API 文档的 JSON 响应描述），但 ArkTS 类型系统不支持 `null` 类型。实现时需转换为 `undefined` 或使用可选属性（如 `field?: Type`）。此问题属于 ArkTS 与 JSON 之间的类型映射细节，不影响设计层面的可行性。

### 4. 设计一致性

**[通过]** 设计整体一致且完整：
- 所有模块职责描述清晰，与需求中五大功能域（环境展示、告警推送、历史趋势、设备控制、病虫害记录）一一对应
- 模块间依赖方向明确且无循环：`pages/` → `services/` → `common/`，`components/` → `common/models.ets`
- `api.ets` 与 `HttpClient` 的两层职责边界清晰（原始传输层 vs 业务门面层），需求中的修订意见已在 v3 中完整覆盖
- 关键行为契约（场景 A–E）覆盖了所有核心交互流程，包括首页加载、设备控制、分页浏览、仪表盘刷新、页面切换轮询
- 错误处理策略完整，区分网络层、HTTP 状态码、业务错误码、JSON 解析、UI 操作五类异常，并分别定义了用户反馈方式
- API 接口映射完整：`DeviceService` ↔ `/device/list`、`SensorService` ↔ `/sensor/*`、`DiseaseService` ↔ `/disease/*`、`CommandService` ↔ `/command/*`、`AdvisoryService` ↔ `/advisory`、`ImageService` ↔ `/image/*`
- v2/v3 修订说明中的问题均已修正（key 命名对齐、`getRaw()` 二进制路径、错误码精确列举、`NetworkResult` 类型表补充）

**[通过]** 依赖关系图清晰，无缺失环节，行为契约足以指导后续实现。

### 5. 设计质量

**[通过]** 设计质量良好：
- **单一职责原则**：每个 Service 对应一类 API 端点（`SensorService`、`DiseaseService`、`CommandService`、`AdvisoryService`、`DeviceService`、`ImageService`），职责边界清晰；`PollingManager` 独立管理轮询生命周期，不与 UI 耦合
- **抽象层次恰当**：不做过度的抽象（无工厂模式、无 IoC 容器——这些在 ArkTS 中既无必要也无成熟支持），但也没有设计不足（Service 层将 HTTP 交互与 UI 分离、`api.ets` 隔离 SDK 变更影响）
- **便于实现**：Service 接口与 API 端点 1:1 映射，组件接口通过 `@Prop`/`@Link` 明确声明，实现者可直接按模块并行开发
- **可测试性**：Service 层可通过对 `HttpClient` 层打桩进行测试；组件通过 `@Prop` 输入可独立渲染预览
- **乐观 UI 更新策略**（决策 7）与参考项目 `DisplayPage.ets` 一致，失败时回滚 `@State`

**[轻微]** 模块级单例模式（`HttpClient`、各 Service）在 ArkTS 中是最简洁的实现方式，但这使得单元测试时难以替换为 mock 实现。若后续需要更完善的测试隔离，可考虑在 Service 构造函数中注入 `HttpClient` 依赖（而非直接在模块级引用单例）。当前设计对此规模的项目是合理的权衡。

## 修改要求

无严重或一般性问题，审查通过。

---
