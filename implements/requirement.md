# 农眼卫士 FarmEye Guard v1.0 — 鸿蒙移动应用实现任务

## 任务总目标

按照 `docs/4_hamony-architecture.md` 设计方案，在 `harmony-app/` 项目中实现鸿蒙移动应用 v1.0。

实施位置：`E:\dev\wheat-tea-iot\harmony-app`。

## 关键要求

1. 严格按照设计文档 `docs/4_hamony-architecture.md` 实施，包括模块划分、核心抽象、关键行为契约、错误处理、并发设计等。
2. 每轮实现完成后必须可以编译通过，没有 error。设计文档中可能存在错误，以实际编译错误为准进行修改。
3. API 接口严格遵循 `docs/3_client-api-reference.md`，包括路径、请求/响应结构、错误码。
4. 必须实现的内容（按模块划分）：
   - **common 层**：models.ets、api.ets、constants.ets、RetryPolicy.ets、CacheManager.ets、utils.ets
   - **services 层**：HttpClient.ets、SensorService.ets、DiseaseService.ets、CommandService.ets、AdvisoryService.ets、DeviceService.ets、ImageService.ets、PollingManager.ets
   - **components 层**：SensorCard.ets、ChartView.ets、LineChartRenderer.ets、BarChartRenderer.ets、DeviceSelector.ets、AlarmBanner.ets、ControlButton.ets、SeverityBadge.ets、PaginatedList.ets、ImageViewer.ets、ConnectivityIndicator.ets、LoadingState.ets
   - **pages 层**：Index.ets、DashboardPage.ets、DiseaseRecordsPage.ets、ControlPage.ets、AdvisoryPage.ets
   - **entryability 层**：EntryAbility.ets（注入 PollingManager 暂停/恢复）

## 实施策略

采用审议式实施管线（Planner-Designer-Coder-Verifier-Runner），每轮聚焦一个任务，逐轮迭代实现。每轮结束后暂停询问用户。

初始分支：impl/harmony-app-impl -> 每轮切换到 impl/temp-R{N}

## 参考文档

- docs/4_hamony-architecture.md — 鸿蒙 App OOD 设计方案
- docs/3_client-api-reference.md — 表现层客户端 REST API 接口文档

## 参考项目

参考ArkTS的语法、特性和部分实现
- reference\zhihui