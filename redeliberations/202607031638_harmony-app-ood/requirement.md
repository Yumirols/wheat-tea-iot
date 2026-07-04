# 鸿蒙移动应用（HarmonyOS App）OOD 设计需求

## 1. 项目背景

农眼卫士 FarmEye Guard v1.0 是物联网环境监测与边缘端 AI 图像识别系统。鸿蒙移动应用作为"端-云-台"三层架构中的**表现层**，面向农户提供移动端监控与远程控制能力。

## 2. 职责范围

鸿蒙 App 的核心职责：

1. **环境参数实时展示卡片**：温湿度、光照、CO2、土壤 NPK、信号强度等传感器数据的实时数值显示
2. **病虫害预警消息推送**：接收重度检测通知（v1.0 采用 HTTP 轮询 10s 间隔，后续可升级为 WebSocket）
3. **历史数据趋势图表**：折线图/柱状图展示传感器历史数据
4. **远程设备控制**：手动开启/关闭喷淋、灌溉、蜂鸣器、LED
5. **病虫害记录浏览**：按时间、类别、严重度筛选查看
6. **防治建议查看**：展示 AI 决策引擎生成的病虫害防治建议

## 3. 技术栈约束

- **语言**：ArkTS（TypeScript 子集）
- **UI 框架**：ArkUI（声明式 UI）
- **网络请求**：`@ohos.net.http`
- **页面导航**：`@kit.ArkUI` 的 `router`
- **状态管理**：`@State`、`@Link`、`@Prop` 装饰器
- **UI 范式**：`@Entry` + `@Component` 装饰器 + `build()` 方法
- **数据模型**：使用 ArkTS `interface` 定义
- **日志**：`hilog`（来自 `@kit.PerformanceAnalysisKit`）
- **提示**：`promptAction.showToast()`（来自 `@ohos.promptAction`）
- **SDK 版本**：HarmonyOS SDK 6.0.1 (API 21)，Stage 模式
- **构建工具**：Hvigor + `oh-package.json5` 管理依赖
- **应用架构模式**：Stage 模式（`"apiType": "stageMode"`）

## 4. 后端 API 接口（客户端需要消费的接口）

所有接口基础路径：`/api/v1`，认证方式：HTTP Header `X-API-Key`。

### 4.1 设备管理
- `GET /device/list` — 查询设备列表（含在线状态）

### 4.2 环境监测数据
- `GET /sensor/latest?device_id=xxx` — 最新传感器快照
- `GET /sensor/history?device_id=xxx&start=&end=&page=&page_size=` — 历史传感器数据
- `GET /sensor/daily?device_id=xxx&start=&end=&page=&page_size=` — 日聚合数据

### 4.3 病虫害记录
- `GET /disease/list?device_id=&crop_type=&disease_type=&severity=&start=&end=&page=&page_size=` — 分页查询病虫害记录
- `GET /disease/stats?start=&end=` — 多维度统计数据
- `GET /disease/heatmap?device_id=&start=&end=` — 热力图数据

### 4.4 设备控制
- `POST /command/send` — 手动下发控制指令（body: device_id, command, source, operator）
- `GET /command/logs?device_id=&source=&start=&end=&page=&page_size=` — 控制日志

### 4.5 防治建议
- `GET /advisory?device_id=&start=&end=&window_minutes=` — 获取综合防治建议

### 4.6 图像
- `POST /image/upload` — 上传病虫害图像（multipart/form-data）
- `GET /image/{image_id}` — 获取图片

### 4.7 支持的命令
- `led ON/OFF`、`beep ON/OFF`、`spray ON/OFF`、`irrig ON/OFF`

## 5. 现有项目结构骨架（已有文件，需在此基础上设计实现）

```
harmony-app/
├── entry/
│   └── src/
│       └── main/
│           ├── module.json5
│           └── ets/
│               ├── entryability/
│               │   └── EntryAbility.ets
│               ├── pages/
│               │   ├── IndexPage.ets        # 首页（需进一步设计）
│               │   ├── DashboardPage.ets    # 仪表盘
│               │   ├── DiseaseRecordsPage.ets
│               │   ├── ControlPage.ets
│               │   └── AdvisoryPage.ets
│               ├── common/
│               │   ├── api.ets              # HTTP 请求封装
│               │   └── models.ets           # 数据模型定义
│               └── components/
│                   ├── SensorCard.ets
│                   └── ChartView.ets
```

## 6. 参考项目约定（来自 reference/zhihui）

参考项目 `reference/zhihui` 展示了鸿蒙应用的实际开发模式：

1. **页面结构**：`@Entry` + `@Component` 装饰 struct，`build()` 返回 UI
2. **HTTP 请求**：`http.createHttp()` → `.request()` → 解析 JSON 响应
3. **认证**：请求头 `X-Auth-Token`（本项目改为 `X-API-Key`）
4. **导航**：`router.replaceUrl({ url: 'pages/xxx' })` 或 `router.pushUrl()`
5. **状态管理**：`@State` 本地状态，`@Link` 父子双向绑定，`$variable` 语法
6. **轮询**：`setInterval(async () => {...}, 10000)` 每 10s 刷新
7. **错误处理**：`catch((err: BusinessError) => {...})` + toast 提示
8. **条件渲染**：`if (condition) { ... } else { ... }`
9. **循环渲染**：`ForEach(arr, (item) => {...})`
10. **路由注册**：所有页面路径在 `resources/base/profile/main_pages.json` 中注册
11. **权限**：在 `module.json5` 中声明 `ohos.permission.INTERNET`

## 7. OOD 设计要求

- 划分**组件/模块**边界，明确每个组件的**职责**
- 定义组件间的**协作关系**和**依赖方向**
- 设计**核心抽象**（类型角色、职责、协作方式）
- 描述**关键行为契约**（核心交互场景）
- 定义**错误处理策略**
- 遵循**单一职责原则**和**接口隔离原则**
- 确保在 ArkTS 类型系统和 ArkUI 框架下可行
