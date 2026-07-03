# 农眼卫士 FarmEye Guard v1.0 — OOD 设计方案可落地性审查报告质询

## 质询概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `b_v1_diag_v1.md` — 鸿蒙移动应用 OOD 设计方案可落地性审查报告 |
| 审查视角 | 质询审查报告是否**问题明确、证据充分、逻辑自洽** |
| 质询结论 | **CHALLENGED** — 发现遗漏高严重度问题 2 项、证据不充分 1 项、逻辑不完整 1 项 |

---

## 一、遗漏的高严重度问题

### CH1. 设计所有页面场景均未处理 `aboutToAppear` 的同步约束

**位置**：`a_v1_design_v3.md` 场景 A/B/C/D/E（第 309–369 行）

**问题描述**：
审查报告未发现设计文档的关键 ArkUI 框架约束遗漏。在 ArkUI（API 21）中，`aboutToAppear()` 生命周期方法为**同步函数**，不支持 `async` 关键字。但设计文档在场景 A、C、D 三个场景的行为契约中，均直接在 `aboutToAppear()` 内部编写 `await xxxService.xxx()` 代码：

```
IndexPage.aboutToAppear()
  ├─ DeviceService.getDeviceList()   // 隐含 await
  ├─ SensorService.getLatest(...)    // 隐含 await
```

在 ArkTS 中，若 `aboutToAppear` 被标记为 `async`，编译时不会报错，但 ArkUI 框架不会等待异步操作完成再执行首次 `build()` 渲染。这意味着：
- 所有页面在首次渲染时必然数据为空（或初始值）
- 设计文档**全文未提及页面初始加载状态的 UI 表现**（骨架屏 / 加载中指示器 / 空状态）
- 数据到达后通过 `@State` 赋值触发重渲染的路径虽可行，但首次渲染到数据到达之间的时间窗口存在空白状态，设计未定义此状态下的 UI 行为

**严重程度**：高 — 每个页面首次加载时均存在未定义的空白状态

**改进建议**：
- 设计应在每个页面的核心抽象中补充 `@State private isLoading: boolean`，在 `aboutToAppear` 中调用异步初始化函数（而非直接在 `aboutToAppear` 中 `await`），同步设置 `isLoading = true` → 异步获取数据 → 设置 `isLoading = false`
- 场景 A/C/D 的行为契约流水图应区分"同步初始化"和"异步数据加载"两个阶段

---

### CH2. `DeviceSelector` 设备切换的级联数据刷新路径未定义

**位置**：`a_v1_design_v3.md` 模块目录及 `components/DeviceSelector.ets`（第 37 行）

**问题描述**：
审查报告未识别设备选择变化带来的级联刷新设计缺口。设计引入了 `DeviceSelector` 组件用于多设备场景，且在依赖方向上明确 `services/` 中的多个服务（`SensorService`、`DiseaseService`、`AdvisoryService`、`CommandService`）均以 `device_id` 作为查询参数。但当用户在 `DeviceSelector` 中切换设备时：

- 哪些页面需要重新获取数据？不是所有页面都使用 `Selector`（例如 `ControlPage` 仅操作选定设备）
- 级联刷新的触发机制是什么？是 `DeviceSelector` 直接通过 `@Link` 回调到页面，页面再依次调用多个 Service？
- 切换设备时，`PollingManager` 中正在运行的轮询（基于旧 `device_id`）如何处理？是停止重启还是直接按新 `device_id` 继续？
- 跨页面共享的设备 ID（通过 `router` 参数传递）在页面间切换时，若用户在页面 B 更改了设备选择，回到页面 A 时设计未说明如何同步

**严重程度**：高 — 多设备场景的核心交互路径缺失

**改进建议**：
- 设计应在 `DeviceSelector` 的核心抽象中补充 `@Link selectedDeviceId: string` 双向绑定，以及 `onDeviceChange?: (newDeviceId: string) => void` 回调契约
- 行为契约中应新增"设备切换"场景，描述：页面层的 `onDeviceChange` 回调 → 重新调用所有依赖 `device_id` 的 Service → `PollingManager` 停止旧 key 的轮询并用新 `device_id` 重启 → 更新 `@State` 触发 UI 刷新

---

## 二、证据不充分的问题

### CH3. `b_v1_diag_v1.md` H1 的方案 A 映射性不足

**位置**：`b_v1_diag_v1.md` §H1 改进建议方案 A（第 40 行）

**问题描述**：
审查报告 H1 的建议方案 A 提出："明确 `image_path` 为服务端可访问 URL，`ImageViewer` 直接使用 `<Image src={diseaseRecord.image_path}>`，取消 `ImageService.getImage()` 二进制路径"。

但是：
- 需求文档定义的 API 为 `GET /image/{image_id}` — 这是一个带认证头的 API 端点，不是公开可访问的静态 URL
- 需求文档中 `DiseaseRecord` 的 `image_path` 字段，从字段命名惯例推断为相对路径或资源标识符而非完整 URL
- 若直接使用 `<Image src={image_path}>`，ArkUI 的 `Image` 组件发起的请求**不会携带 `X-API-Key` 认证头**，服务端将返回 401/403
- 方案 A 在实际可落地性上需要额外设计：认证 token 注入到图片 URL 中（如 `?token=xxx`），或通过 `Image` 组件的 `headers` 属性（API 21 中 Image 组件 **不支持自定义请求头**）

**严重程度**：中 — 方案建议未考虑认证约束，实际不可行

**改进建议**：
- 修正建议为：方案 B（PixelMap 解码路径）是唯一可行路径，`ImageService` 需暴露 `getImagePixelMap(imageId): Promise<PixelMap>`，该路径依次涉及 `HttpClient.getRaw()` → `image.createImageSource(ArrayBuffer)` → `createPixelMap()` 的异步管线
- 或在设计层面论证图片服务器是否支持无认证访问，但这需后端配合修改

---

## 三、逻辑不完整的问题

### CH4. `PollingManager` 回调函数中访问页面 `@State` 的上下文约束

**位置**：`b_v1_diag_v1.md` §M1 改进建议（第 122–124 行）

**问题描述**：
审查报告 M1 的建议给出轮询回调中更新页面 `@State` 的代码示例：

```typescript
PollingManager.start('index_alarm', 10000, async () => {
  const advisory = await AdvisoryService.getAdvisory();
  if (advisory.latest_detection?.severity === 'severe') {
    this.alarmMessage = ...;
  }
})
```

但该示例存在上下文隐患：
- `PollingManager` 是服务层模块级单例，其 `start()` 接收的回调函数存储在 `PollingManager` 内部注册表中，由 `setInterval` 触发执行
- 若页面将回调作为**箭头函数**传入，`this` 确实能捕获页面实例的闭包
- 但设计文档未约定：回调必须使用箭头函数捕获 `this`，也未定义 `PollingManager.start()` 方法签名中 `fn` 参数的类型签名
- 更根本的问题：若页面被销毁（`aboutToDisappear`）后 `PollingManager` 未及时 `stop()`（因异常或竞争），回调执行时 `this` 指向已销毁页面的 `@State`，写入已释放状态

**严重程度**：中 — 存在潜在的内存安全和竞争风险

**改进建议**：
- 设计应在 `PollingManager` 的核心抽象中定义回调函数签名：`type PollingCallback = () => Promise<void>`，并在文档中明确标注回调为箭头函数，捕获词法 `this`
- 补充 `PollingManager.stop(key)` 的 Must-Invoke 契约：页面 `aboutToDisappear` 中必须调用 `stop()` 对应 key。若因异常导致 `stop()` 未执行，`setInterval` 将继续执行已销毁页面的回调
- 在 `PollingManager` 内部增加防御逻辑：每 tick 检查所属页面是否仍活跃（通过弱引用或显式 deregister）

---

## 四、质询总结

| 编号 | 类型 | 针对报告项 | 判定 |
|------|------|-----------|------|
| CH1 | 遗漏（高） | 全文 | `aboutToAppear` 同步约束导致所有页面首次加载存在未定义的空白状态 |
| CH2 | 遗漏（高） | 全文 | 设备切换的级联数据刷新路径缺失 |
| CH3 | 证据不充分（中） | H1 方案 A | 方案 A 忽略 ArkUI Image 组件不支持自定义请求头的约束，认证不可行 |
| CH4 | 逻辑不完整（中） | M1 建议 | 回调函数 `this` 上下文依赖未约定，存在已销毁页面状态写入风险 |

审查报告在 `ImageViewer`（H1+H4）、`ChartView`（H2）、`multipart/form-data`（H3）三个框架能力缺口上的判断准确、证据充分，应予以肯定。但以上 4 项问题导致整体质询结论为 **CHALLENGED**，建议设计文档修订后重新审查。

---

```
CHALLENGED:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\b_v1_challenge_v1.md
```
