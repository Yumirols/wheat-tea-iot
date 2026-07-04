# OOD 设计方案审查报告（v1）

## 审查结果

REJECTED

## 逐维度审查

### 1. 类型系统可行性

**[一般]** 核心抽象 §12 页面组件中 `@State private connectivityStatus: 'online' | 'offline'` 的类型定义不包括 `'loading'` 状态值，但同一章节中 `aboutToAppear` 会执行 `this.connectivityStatus = 'loading'`，且状态转换矩阵（loading→online→offline→online）和 `ConnectivityIndicator`（接收 `'loading' | 'online' | 'offline'`）均依赖 `'loading'`。ArkTS 编译器会对越界赋值报编译错误。

**[一般]** 核心抽象 §19 `ImageViewer` 及决策 9 假设 `DiseaseRecord.image_path` 可直接通过 `baseURL + image_path` 拼接为 `Image(src)` 组件的 URL 加载路径。但 API 文档（`docs/3_client_api_reference.md` §2.4.2）明确提供了 `GET /image/{image_id}` 二进制流端点作为图片获取的标准路径，未声明 `/images/` 路径可直接作为静态 URL 访问。设计中虽有备用路径（`PixelMap` 解码链），但主路径假设的 API 依据不足，构成不可忽视的设计缺陷——若服务端未将 `image_path` 作为公开 URL 暴露，则 §19 的主路径不可行。

**[轻微]** `PollingManager.start(key, fn, interval)` 的 `PollingCallback` 显式类型定义已补充至 `common/models.ets`，类型定义与 ArkTS 的函数类型语法兼容。通过。

### 2. 标准库与生态覆盖

**[通过]** `@ohos.net.http` 提供的 `createHttp()` / `request()` / `destroy()` 能力可以支撑 `api.ets` 层的原始传输封装设计。`promptAction.showToast()` 的 toast 反馈机制与参考项目一致。`setTimeout` / `clearTimeout` 可支撑 `PollingManager` 的串行轮询调度。`BusinessError` 从 `@kit.BasicServicesKit` 导入的使用方式与参考项目代码一致。

**[通过]** `router.pushUrl()` / `router.replaceUrl()` 的页面导航方式与 ArkUI 框架能力匹配。`@Prop` / `@Link` / `@State` 装饰器的使用方式符合 ArkUI 声明式范式。

**[轻微]** API Key 请求头在设计中使用 `X-API-Key` 写法，但 API 参考文档（§1.3）使用 `X-Api-Key`（'Api' 中 'p' 小写）。HTTP 头字段名大小写不敏感，但为与文档一致建议统一为 `X-Api-Key`。

### 3. 语言特性可行性

**[通过]** 错误处理策略中统一使用 `catch((err: BusinessError)` 的约定与参考项目代码（`DisplayPage.ets` 第 262 行 `catch((err: BusinessError)`）一致，已修复 N6 问题。

**[通过]** `aboutToAppear()` 同步生命周期的使用方式正确：不 `await` 异步 `loadData()`，而是通过 `.catch()` 处理拒绝的 Promise，与参考项目 `initData()` 的异步触发模式一致。

**[通过]** `loadData()` 统一返回 `Promise<void>`，内部 try-catch 同步异常转为 `Promise.reject` 的模式在 ArkTS 中可行。

**[通过]** `PollingManager` 使用递归 `setTimeout` 实现串行轮询的模式在 ArkTS 中可行，串行定时漂移行为已清晰标注为设计特性。

**[通过]** 模块化结构（`pages/` → `services/` → `common/`）和依赖方向符合 ArkTS 的模块导入机制。Service 以模块级实例（单例）暴露的设计方式在 ArkTS 中可行。

### 4. 设计一致性

**[通过]** 各核心抽象的职责描述清晰，N1-N6 已按要求修复：`ControlButton` 改用 `@Link`、`connectivityStatus` 状态转换矩阵补充完整、`AlarmBanner` 核心抽象补充、`PollingManager` 串行漂移行为标注、`@State alarmMessage/alarmSeverity` 补充、`catch((err: Error)` 统一替换。

**[通过]** 场景 A-F 的行为链路完整，未发现缺失环节。`connectivityStatus` 转换矩阵覆盖了 loading→online→offline→online 的完整闭环。

**[通过]** 模块间依赖方向清晰（`pages/` → `services/` → `common/`），无循环依赖。`CommandService` → `DeviceService` 的跨 Service 硬耦合已标注为已知耦合并记录解耦方向。

**[轻微]** `PollingManager` 在 `EntryAbility.onBackground()` / `onForeground()` 中的生命周期集成仅描述了行为要求，未明确说明 `EntryAbility.ets` 如何获取 `PollingManager` 的引用（需 import 后调用 `suspendAll()` / `resumeAll()`）。虽属实现细节，但建议在 §9 协作方式中简要说明。

### 5. 设计质量

**[通过]** 职责划分遵循单一职责原则：Service 层封装 HTTP 业务逻辑，Page 层管理 UI 状态，Component 层负责渲染。`HttpClient` 作为业务门面与 `api.ets` 作为原始传输层的分工明确。

**[通过]** 抽象层次恰当：`RetryPolicy` 和 `CacheManager` 作为 `common/` 层基础设施被业务层复用，避免了各 Service 重复实现。

**[通过]** 设计便于测试：Service 层与 UI 层解耦，`api.ets` 可被 mock 以独立验证 `HttpClient` 的业务逻辑。

**[通过]** 数据模型统一使用 `interface` 而非 `class`，符合 ArkTS 传统和 JSON 解析场景的最佳实践。

## 修改要求

### 问题 1（一般 — §12 `connectivityStatus` 类型不匹配）

- **问题**：`@State private connectivityStatus: 'online' | 'offline'` 的类型定义未包含 `'loading'` 状态值，但该变量在 `aboutToAppear` 中被赋值为 `'loading'`，且状态转换矩阵中 `'loading'` 是合法状态。ArkTS 编译器会对越界赋值报编译错误。
- **原因**：类型定义与运行时状态空间不一致，直接影响实现的可行性。
- **建议方向**：将 `connectivityStatus` 的类型声明改为 `'loading' | 'online' | 'offline'`，同时确保所有相关引用（页面 §12、ConnectivityIndicator §20、状态转换矩阵）统一使用此完整联合类型。

### 问题 2（一般 — §19 `image_path` URL 直接访问假设未充分验证）

- **问题**：`ImageViewer` 的主路径假设 `baseURL + image_path` 可被 `Image(src)` 直接加载为网络图片，但 API 文档（§2.4.2）提供了 `GET /image/{image_id}` 二进制流端点作为标准图片获取方式，未明确说明 `image_path` 对应的 URL 可直接公开访问。
- **原因**：若服务端未将 `image_path` 路径作为公开静态资源 URL 暴露，则 §19 的主路径不可行，整个图片查看功能依赖备用路径实现。
- **建议方向**：在决策 9 中明确标注此假设需在实际服务器环境下验证。考虑两种方案：
  - **方案 A**（经验证可行）：维持主路径 `baseURL + image_path`，并在 `ImageViewer` 的职责中补充备用降级逻辑（若 `Image` 组件加载失败则回退到备用路径）。
  - **方案 B**（依据 API 端点）：以 `GET /image/{image_id}` 为主路径，通过 `ImageService.getImagePixelMap(imageId)` + `ArrayBuffer` → `ImageSource` → `PixelMap` 解码链获取图片，将 `image_path` 的直接 URL 加载降级为备用优化路径。
  - 若采用方案 B，`DiseaseRecord` 模型中还需补充 `image_id` 字段映射（API 响应中 `id` 即对应 `image_id`），并将 `ImageService` 的协作方式同步更新。
