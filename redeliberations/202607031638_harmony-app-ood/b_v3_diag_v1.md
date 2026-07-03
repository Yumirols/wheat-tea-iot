# 农眼卫士 FarmEye Guard v1.0 — OOD 设计方案可落地性审查报告（v3 第1轮）

## 审查概况

| 项目 | 内容 |
|------|------|
| 审查对象 | `a_v3_design_v2.md` — 鸿蒙移动应用 OOD 设计方案（v6，第3轮迭代修订版） |
| 对应需求 | `requirement.md` + `a_v3_iteration_requirement.md` |
| 审查视角 | OOD 设计可落地性：前两轮关键问题修复验证 + 新引入质量问题 |
| 审查方法 | 逐项对照迭代需求中的 6 项新发现问题（N1-N6）及 4 项持续存在项（M1/S1/S3/S4/S6）的修复检查 |
| 前置审查结论 | `b_v2_diag_v2.md` 结论：LOCATED（通过），但存在 2 项中严重度 + 4 项低严重度缺口 + 6 项持续存在项 |

---

## 整体评价

v3 设计（v6 修订版）对 `a_v3_iteration_requirement.md` 中的 **6 项新发现缺口（N1-N6）实现了全覆盖修复**，修复方案准确、彻底，无遗漏。M1 条件修复项已补充显式类型定义转为完整修复。S1/S3/S4/S6 四项持续存在项均已在核心抽象中补充完整。v6 追加修订的 2 项问题（connectivityStatus 类型缺口、image_path 双路径方案）也已正确闭合。

**本轮审查未发现新增的可落地性缺口或质量回退。** 设计文档的可落地性成熟度达到本轮迭代要求的验收标准。

---

## 迭代需求问题修复验证

### 中严重度（2 项）

| 编号 | 问题 | 要求措施 | 修复状态 | 验证说明 |
|------|------|---------|---------|---------|
| **N1** | `ControlButton` 乐观 UI 状态管理未闭合（`@Prop` 只读） | §16 改用 `@Link` 接收 `isOn`，补充 `@Link` 决策说明，移除 `aboutToUpdate` 引用，同步更新场景 B | ✅ **完整修复** | §16 已改用 `@Link isOn: boolean`，乐观 UI 通过 `this.isOn = targetState` 直接写入父 `@State`；§16 末尾"`@Link` 决策说明"明确标注 `@Prop` 为只读不宜使用、`@Link` 语义匹配、`aboutToUpdate` 不存在于 API 21；场景 B 乐观 UI 翻转描述已同步为 `this.isOn = targetState（@Link 直接写入父 @State）` |
| **N2** | 各页面 `connectivityStatus` 完整状态转换闭环未定义 | 采用纯页面级状态转换矩阵，在 `loadData()` 统一 catch 中维护，补充完整状态转换矩阵表，初始值改为 `'online'` | ✅ **完整修复** | 错误处理策略中新增完整状态转换矩阵（§549-557），覆盖 `'online→loading→online/offline→online'` 六条完整转换路径；§12 初始值 `'online'`、`aboutToAppear` 设为 `'loading'`；`loadData()` 统一 catch 三条维护规则（成功→online、重试耗尽→offline、业务错误→保持）；决策 14 记录纯页面级方案选择，声明放弃模块级 `globalConnectivity` |

### 低严重度（4 项）

| 编号 | 问题 | 要求措施 | 修复状态 | 验证说明 |
|------|------|---------|---------|---------|
| **N3** | `AlarmBanner` 缺少核心抽象定义 | 新增独立章节，定义 `@Prop message`、`@Prop severity`、展示交互行为 | ✅ **完整修复** | 新增核心抽象 §17 `AlarmBanner`，定义了 `@Prop message: string`、`@Prop severity: 'mild' \| 'moderate' \| 'severe'`、点击跳转 `router.pushUrl` 至 `AdvisoryPage`、关闭按钮隐藏展示、空消息不渲染等完整交互行为 |
| **N4** | `PollingManager` 串行模式定时漂移行为未标注 | 补充串行定时策略说明，标注有效轮询频率公式和弱网场景设计意图 | ✅ **完整修复** | §9 补充完整说明：每个 tick 完成后 `setTimeout(fn, interval)` 调度下一个；明确标注有效频率公式 `1/(tickDuration + interval) ≤ 1/interval`；声明"在 IoT 弱网场景下避免请求堆积比维持名义频率更重要"作为设计特性 |
| **N5** | 页面 `@State alarmMessage/alarmSeverity` 缺失声明 | §12 `@State` 列表中补充声明 | ✅ **完整修复** | §12（§265）`@State` 列表中已包含 `@State private alarmMessage: string` 和 `@State private alarmSeverity: 'mild' \| 'moderate' \| 'severe'` |
| **N6** | `catch((err: Error)` 不符 ArkTS 约定 | 统一替换为 `catch((err: BusinessError)` | ✅ **完整修复** | §12 `aboutToAppear` 代码片段（§272）已使用 `catch((err: BusinessError)`；场景 A（§433）同步已统一 |

### 条件修复项（1 项）

| 编号 | 问题 | 要求措施 | 修复状态 | 验证说明 |
|------|------|---------|---------|---------|
| **M1** | `PollingCallback` 显式类型定义缺失 | 在 `common/models.ets` 或 `PollingManager.ets` 添加 `export type PollingCallback = () => Promise<void>`，`start()` 中 `fn` 标注为 `PollingCallback` 类型 | ✅ **转完整修复** | §9（§226）`start(key, fn, interval)` 中明确 `fn` 参数类型为 `PollingCallback`；§21（§411）数据模型表中列出 `PollingCallback` 类型定义为 `type PollingCallback = () => Promise<void>`；模块文件列表 §58 `common/models.ets` 注释标注"含 PollingCallback 显式类型" |

### 持续存在项（4 项）

| 编号 | 问题 | 要求措施 | 修复状态 | 验证说明 |
|------|------|---------|---------|---------|
| **S1** | `CacheManager` 缓存键空间共享冲突 | 约定各 Service 使用统一前缀命名空间 | ✅ **已修复** | §11（§258）补充缓存键命名约定：`sensor_latest_`、`device_list_`、`advisory_` 等前缀隔离 |
| **S3** | `DiseaseRecord` 模型缺少 `linkage_detail` 字段 | 补充 `linkage_detail?: string` 可选字段 | ✅ **已修复** | §21（§398）`DiseaseRecord` 字段列表中已包含 `linkage_detail?` |
| **S4** | `SensorService.getLatest()` 未注明 `deviceId` 可选行为 | 注明 `deviceId` 为空时的行为约定 | ✅ **已修复** | §3（§150）明确：`deviceId` 为空时视为"查询全部"，Service 不拼接 `device_id` 查询参数 |
| **S6** | `CommandService` 硬引用 `DeviceService.refreshDevices()` | 记录耦合说明，标注后续事件解耦方向 | ✅ **已修复** | §5（§180）新增"已知耦合说明"明确 v1.0 阶段可接受；新增决策 15 记录耦合理由和后续基于事件解耦的方向 |

---

## v6 追加修订验证

| 修订项 | 修改措施 | 验证说明 |
|-------|---------|---------|
| **问题 1**（一般 — connectivityStatus 类型不匹配） | §12 类型声明修正为 `'loading' \| 'online' \| 'offline'` | §12（§265）已修正；`ConnectivityIndicator` §20 类型无需修改（原已正确） |
| **问题 2**（一般 — image_path 直接访问假设未充分验证） | §19 改为"主路径+降级路径"双路径方案；决策 9 补充双路径理由 | §19（§368-375）明确定义主路径（`baseURL + image_path` 供 `Image` 直接加载）和降级路径（`onError` → `image_id` → `ArrayBuffer` → `PixelMap` 解码链）；决策 9（§690）补充 `image_path` 为公开 URL 的文档依据和 `image_id` 提取策略 |

---

## 新发现问题

**本轮审查未发现新增的可落地性缺口。** 所有迭代需求要求修复的问题已在 v3 设计（v6 修订版）中得到完整、准确的修复。修复方案均在 ArkTS/ArkUI 框架约束内，依赖方向合规，无新增质量回退。

---

## 可落地性综合评价

| 维度 | 评级 | 说明 |
|------|------|------|
| 第2轮问题修复完整性 | ✅ **全覆盖修复** | 6 项新发现问题（N1-N6）全部完整修复；M1 条件修复已转完整修复 |
| 持续存在项修复 | ✅ **全部闭合** | S1/S3/S4/S6 四项持续存在项均已补充至核心抽象 |
| 修复方案正确性 | ✅ **正确** | 所有修复均在 ArkTS/ArkUI 框架约束内，无语法或语义越界 |
| 新增设计完整性 | ✅ **完整** | v6 追加 2 项修订（connectivityStatus 类型 + image_path 双路径）正确闭合 |
| 组件状态管理闭合度 | ✅ **完整** | `ControlButton @Link` + `connectivityStatus` 转换矩阵均已形成完整闭环 |
| 编码阶段可操作性 | ✅ **可落地** | 设计文档可直接作为编码实现依据，无阻塞性缺口 |

**结论**：v3 设计（v6 修订版）已达到可落地性验收标准。所有 11 项迭代需求问题（N1-N6、M1、S1/S3/S4/S6）均已修复，零遗漏。v6 修订的 2 项追加问题已正确闭合。本设计文档可直接进入编码阶段，无需额外的设计修订迭代。

---

## 修订说明（本版新增）

本报告为第3轮审查的第1版诊断报告，基于 `a_v3_design_v2.md` 的完整内容进行独立可落地性审查。

```
DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607031638_harmony-app-ood\b_v3_diag_v1.md
```
