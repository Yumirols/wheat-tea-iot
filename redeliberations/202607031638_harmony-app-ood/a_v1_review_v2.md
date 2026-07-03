# OOD 设计方案审查报告（v2）

## 审查结果

REJECTED

## 逐维度审查

### 1. 类型系统可行性

**[通过]**

- 数据模型使用 ArkTS `interface` 定义符合技术栈约束，API JSON 响应天然匹配结构化类型，无运行时开销
- 服务层采用模块级变量的单例模式（`export const`），ArkTS 模块系统天然支持，无需类构造
- `api.ets` 作为纯函数导出（无状态工具函数），ArkTS 模块级导出完全可行
- `HttpClient.get<T>() / post<T>()` 泛型方法在 ArkTS 泛型系统能力范围内，编译期类型安全
- 页面组件使用 `@State` / `@Link` / `Prop` 装饰器符合 ArkUI 声明式范式，与参考项目 `DisplayPage.ets` 一致
- 设计中无继承体系依赖（设计决策明确指出 ArkTS 不支持继承），所有抽象通过模块导入实现依赖关系

### 2. 标准库与生态覆盖

**[通过]**

- `@ohos.net.http` 用于 HTTP 通信，与技术栈约束一致；参考项目 `DisplayPage.ets` 已验证 `http.createHttp()` / `.request()` 模式可行
- `promptAction.showToast()` 用于用户反馈，在技术栈约束范围内且被参考项目广泛使用
- `hilog` 用于日志记录，来自 `@kit.PerformanceAnalysisKit`，约束中已明确确认
- `router.pushUrl()` / `router.replaceUrl()` 用于页面导航，与参考项目 `landing.ets` 用法一致
- `Canvas` / `Chart` 组件在 ArkUI 中均有可用实现，ChartView 组件设计合理
- `http.MultiFormData` 在 `@ohos.net.http` 中可用于构建 multipart/form-data 上传请求，`ImageService` 的设计假设成立

### 3. 语言特性可行性

**[通过]**

- 错误处理策略使用 `async/await` + `try-catch`，与参考项目 `DisplayPage.ets` 的模式完全一致
- 轮询使用 `setInterval` 在 UI 线程调度，参考项目 `DisplayPage.ets:270` 已验证此模式可行
- `PollingManager` 集中管理 `setInterval` / `clearInterval` 生命周期，避免页面切换时定时器残留，设计合理
- `api.ets` 管理 `http.createHttp()` / `destroy()` 的完整生命周期，每次请求创建新实例（参考项目同样每个请求独立创建 `http.createHttp()`）
- 模块结构（`pages/`、`services/`、`common/`、`components/`）与现有项目骨架兼容
- `EntryAbility.onBackground()` / `onForeground()` 生命周期事件可用于统一暂停/恢复轮询

### 4. 设计一致性

**[一般]** 场景描述与调度表存在轮询 key 命名不一致

- **场景 A**（§场景 A）中 `PollingManager` 的 key 为 `'alarm'`，但**轮询调度约束表**（§并发设计/轮询调度约束）中 IndexPage 的 key 为 `'index_alarm'`
- **场景 D**（§场景 D）中 key 为 `'dashboard'`，但**轮询调度约束表**中 DashboardPage 的 key 为 `'dashboard_sensor'`
- 上述两处不一致会导致实现阶段对 `PollingManager` 的 key 产生歧义，无法确定哪个是正确命名

**[一般]** `ImageService` 获取二进制图片的路径未在 `HttpClient` 接口设计中定义

- `HttpClient` 的接口仅提供 `get<T>()` / `post<T>()` 两个泛型方法，均返回 `ApiResponse<T>`（JSON 结构）
- `GET /image/{image_id}` 返回原始二进制流，与 `ApiResponse<T>` 的 JSON 结构不兼容
- 设计陈述 `ImageService`"通过 `HttpClient` 完成 HTTP 传输"（§8 协作方式），但未定义 `HttpClient` 上获取非 JSON 二进制响应的接口路径
- **后果**：实现者无法确定二进制图片获取是应通过 `HttpClient` 的新方法（如 `getBinary()`）、还是应绕过 `HttpClient` 直接调用 `api.ets`、或是另有机制

**[通过]** 其他协作关系形成闭环：
- 场景 A 完整覆盖了设备列表加载 → 传感器快照 → 告警轮询的全链路
- 场景 B 完整覆盖了前置在线检查 → 命令下发 → 响应处理 → 日志刷新的全流程
- 场景 C 完整覆盖了筛选初始化 → 分页加载 → 详情展开 → 图片查看的全链路
- 模块依赖方向 `pages/ → services/ → common/` 及 `components/ → common/` 无循环依赖

### 5. 设计质量

**[通过]** 职责划分清晰，遵循单一职责原则：
- 每个 Service 对应一个业务领域（Sensor / Disease / Command / Advisory / Device / Image）
- `PollingManager` 独立于 UI 页面，职责聚焦于轮询生命周期管理
- `api.ets` 与 `HttpClient` 的两层分离合理：传输层与业务门面职责边界清晰

**[通过]** 抽象层次恰当：
- 服务层提取避免了页面直接操作 `@ohos.net.http`，与参考项目中 HTTP 逻辑写在页内的模式相比有明显改进
- 未引入过度设计（如全局状态管理、依赖注入框架等）

**[轻微]** 错误码范围表述不够精确

- 设计描述为"通用业务错误码（1001–5000）"，但实际错误码为非连续分布：`1001`–`1005`、`2001`、`3001`、`5000`
- `1004`（API Key 无效）、`1005`（频率限制）和 `3001`（华为 IoTDA 调用失败）未被区分
- 不影响实现可行性，但建议精确列出各错误码的场景

**[轻微]** `api.ets` 核心抽象中提及的 `NetworkResult` 结构未在 `common/models.ets` 的类型定义表中出现

- `api.ets` 职责描述提到"返回原始 `http.HttpResponse` 或统一的 `NetworkResult` 结构"
- 但 `common/models.ets` 的接口表中未定义 `NetworkResult` 类型
- 属于设计级别的疏漏，不影响可行性，建议补充定义

## 修改要求

### 问题 1：轮询 key 命名不一致

- **问题**：`PollingManager.start('alarm', ...)`（场景 A）与调度表中的 `'index_alarm'` 不一致；`PollingManager.start('dashboard', ...)`（场景 D）与调度表中的 `'dashboard_sensor'` 不一致
- **原因**：场景描述和调度约束表使用了不同的 key 命名风格，实现者无法确定正确名称
- **建议方向**：统一为带页面前缀的风格（如 `index_alarm`、`dashboard_sensor`、`advisory_refresh`），确保场景描述与调度表一致

### 问题 2：ImageService 二进制图片获取路径未定义

- **问题**：`ImageService` 需通过 `HttpClient` 完成 HTTP 传输获取二进制图片，但 `HttpClient` 仅提供了返回 `ApiResponse<T>` 的 `get<T>()` 泛型方法，无法承载二进制响应的获取
- **原因**：`HttpClient` 的接口设计面向 JSON API 响应结构，图片二进制的非 JSON 响应需要不同的获取路径，设计未明确该路径
- **建议方向**（三选一）：
  - **方案 A**：在 `HttpClient` 上增加 `getRaw(path)` 方法，返回 `ArrayBuffer`，绕过 JSON 解析路径
  - **方案 B**：`ImageService` 绕过 `HttpClient`，直接调用 `api.ets` 的 `request()` 获取原始响应
  - **方案 C**：`HttpClient` 增加 `responseType` 参数（`'json' | 'arraybuffer'`），`ImageService` 调用时指定为 `'arraybuffer'`
