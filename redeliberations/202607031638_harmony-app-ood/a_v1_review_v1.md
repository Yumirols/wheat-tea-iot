# OOD 设计方案审查报告（v1）

## 审查结果

REJECTED

## 逐维度审查

### 1. 类型系统可行性

**[通过]** `ApiResponse<T>` / `PaginatedData<T>` 泛型接口在 ArkTS 泛型系统能力范围内，ArkTS 支持 `interface` 泛型参数。

**[通过]** Service 以模块级实例（单例）方式暴露给页面，ArkTS 支持模块级变量导出，不依赖类继承机制。

**[通过]** `@State` / `@Prop` / `@Link` 装饰器以及 `$variable` 双向绑定语法完全在 ArkUI 框架能力范围内，与参考项目 `DisplayPage.ets` 的实际使用模式一致。

**[通过]** 数据模型统一使用 `interface` 定义，与 API 响应 JSON 的结构化类型天然匹配。ArkTS 中 `interface` 编译期类型检查无运行时开销。

### 2. 标准库与生态覆盖

**[通过]** `@ohos.net.http` 用于 HTTP 请求、`@ohos.promptAction` 用于 Toast 提示、`hilog` (`@kit.PerformanceAnalysisKit`) 用于日志、`router` (`@kit.ArkUI`) 用于页面导航 — 均与参考项目模式一致且为鸿蒙 SDK 标准能力。

**[通过]** `setInterval` / `clearInterval` 用于轮询调度，ArkTS 支持标准的定时器 API。

**[轻微]** `ChartView` 组件设计提及使用 ArkUI 的 `Canvas` 或 `Chart` 组件。`Chart` 组件在 API 21 中的可用性和功能边界需在实现阶段确认，但设计已提供 `Canvas` 作为备选路径，不阻塞架构可行性。

### 3. 语言特性可行性

**[通过]** `async/await` 异步模型 + `try-catch` 错误处理模式与参考项目一致，ArkTS 完全支持。

**[通过]** `PollingManager` 通过 `setInterval` 实现轮询 + `EntryAbility.onBackground/onForeground` 生命周期控制暂停/恢复的方案在 ArkTS 中可行。

**[通过]** 页面路由注册需要在 `resources/base/profile/main_pages.json` 中提前声明，设计提及了 5 个 `@Entry` 页面，符合此约束（实现阶段需逐一注册）。

**[通过]** 模块依赖方向（`pages/ → services/ → common/`）与 ArkTS 的 `import` 机制一致，无循环依赖。

### 4. 设计一致性

**[一般]** `common/api.ets` 与 `services/HttpClient.ets` 的职责边界不清晰。

需求中的项目骨架包含 `common/api.ets`（原始 HTTP 请求封装），设计在 `services/` 中新增了 `HttpClient.ets`（HTTP 客户端单例）。但设计未阐明两者的关系：`HttpClient` 是封装 `api.ets` 还是直接使用 `@ohos.net.http`？若 `HttpClient` 跳过 `api.ets`，则 `common/api.ets` 成为死代码；若 `HttpClient` 依赖 `api.ets`，则存在不必要的间接层。这种歧义会影响后续实现时的模块组织决策。

**[一般]** 未覆盖图像上传/下载功能对应的服务抽象。

API 接口（4.6 节）定义了 `POST /image/upload`（multipart/form-data）和 `GET /image/{image_id}`（二进制流），但设计中的服务层没有对应的 `ImageService` 或任何页面/组件提及图像处理。需求六大核心功能中虽未显式列出图像上传为用户可见功能，但 API 接口是客户端必须消费的，缺少对应的抽象层意味着在实现时该功能将被随意放置（如散落在页面代码中），违背了架构的服务层封装原则。

**[通过]** 5 个业务场景契约（A–E）形成了完整的用户交互闭环，各页面与服务之间的协作关系清晰，无缺失环节。

**[通过]** 模块间依赖方向明确（`pages/ → services/ → common/` 和 `components/ → common/`），无循环依赖。

### 5. 设计质量

**[通过]** 职责划分符合单一职责原则：每个 Service 对应一个业务域（传感器、病虫害、命令、设备、建议），`PollingManager` 独立管理轮询生命周期。

**[通过]** 抽象层次恰当：Service 层封装 HTTP 细节但不涉及 UI 状态，页面层管理 UI 状态但不直接操作 HTTP — 层次清晰。

**[通过]** 可测试性好：Service 不依赖于 UI 组件，可通过注入 mock `HttpClient` 进行单元测试。

**[通过]** 组件复用设计合理：`SensorCard`、`ControlButton`、`PaginatedList`、`SeverityBadge` 等被多个页面重用，减少重复代码。

**[轻微]** 设计决策 7（乐观 UI 更新）中，`CommandService` 描述为"在校验设备在线状态后才执行下发"，但场景 B 的协作流程中未体现 `DeviceService` 前置检查。建议在实现级补充该校验步骤，或统一决策是否依赖服务端 `code=1003` 做离线判断。

## 修改要求（REJECTED 时存在）

### 问题 1：`common/api.ets` 与 `services/HttpClient.ets` 职责边界不清晰

- **问题**：设计在保留 `common/api.ets`（需求骨架中已有的 HTTP 封装）的同时新增 `services/HttpClient.ets`，但未定义两者之间的关系和分工。
- **原因**：这种歧义导致后续实现时开发者不知道应使用哪个模块发起 HTTP 请求，可能产生重复代码或错误的依赖方向。
- **建议方向**：明确以下方案之一：(a) 保留 `api.ets` 作为 `@ohos.net.http` 的原始封装（如统一处理 `createHttp/destroy` 生命周期），`HttpClient` 在其基础上构建，添加 API Key、错误码映射等业务逻辑；或 (b) 移除 `api.ets`，让 `HttpClient` 直接封装 `@ohos.net.http` 并承担完整职责。建议在模块职责表中补充 `api.ets` 的定位说明。

### 问题 2：未覆盖图像上传/下载功能的服务抽象

- **问题**：API 定义了 `POST /image/upload` 和 `GET /image/{image_id}` 两个接口，但设计中的服务层缺少对应的处理模块。
- **原因**：图像上传涉及 `multipart/form-data` 格式请求（与常规 JSON API 不同），二进制流获取也涉及不同的响应处理方式。如果没有对应的服务抽象，实现时要么将其逻辑散落在页面层，要么在某个现有 Service（如 `DiseaseService`）中掺杂图像处理职责，破坏单一职责原则。
- **建议方向**：新增 `ImageService`（或在现有模块中定义一个清晰的图像处理接口），封装图片上传和获取的 HTTP 交互。考虑到图像上传使用 `multipart/form-data` 而非 JSON，建议`HttpClient` 的通用接口预留 `Content-Type` 可覆盖能力，或 `ImageService` 直接使用 `@ohos.net.http` 构造 `multipart` 请求。
