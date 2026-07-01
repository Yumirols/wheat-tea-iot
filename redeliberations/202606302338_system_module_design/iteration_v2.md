# 再审议判定报告（v2）

## 判定结果

RETRY

## 判定理由

### 一、审查结论概述

组件B第2轮诊断报告（b_v2_review_v1.md）对修订版设计（a_v2_copy_from_v1.md）进行了全面审查，质询报告（b_v2_challenge_v1.md）对诊断报告进行了独立质询验证。两份报告综合认定：

- **首轮严重/高优先级问题（C-01~C-03, H-01~H-06）**：全部已确认修复，修复质量良好。
- **质询补充问题（S-01~S-04）**：四项验证全部准确，修复到位。
- **诊断报告新发现问题**：2项中等（N-01, N-02）。
- **质询报告补充发现**：2项中等（O-01, O-02）、2项低等（O-03, O-04）。
- **低优先级残留**：3项（R-01~R-03），经质询降级论证后合理保留。

### 二、中等问题的具体分析

| 编号 | 问题摘要 | 严重度 | 修复难度 |
|------|---------|--------|---------|
| N-01 | `sensor_snapshot`和`disease_records`的`(device_id, timestamp)`索引为普通索引，无法支持`INSERT ... ON CONFLICT DO NOTHING`幂等策略，数据库将报错 | 中（质询报告指出可议升为高，因属运行时阻塞性错误） | 极低（`CREATE INDEX` 改为 `CREATE UNIQUE INDEX`） |
| N-02 | `devices`表DDL缺失`ip_addr`字段，但`/device/list` API响应包含该字段；`/sensor/history`响应遗漏`ip_addr`和`mac_addr`字段 | 中 | 低（增加字段或明确JOIN来源；补全响应字段） |
| O-01 | `disease_records` DDL定义了`linkage_risk_level`和`linkage_detail`字段，但病虫害记录API响应示例中未包含，导致"历史追溯"设计意图无法通过API实现 | 中 | 低（补全响应示例中的两个字段） |
| O-02 | `sensor_daily_aggregation`日聚合表有DDL和数据保留策略，但接口清单中**无任何端点**查询日聚合数据，聚合-保留-查询链路在查询端断开 | 中 | 中（需新增一个API端点并更新接口清单） |

### 三、判定依据分析

#### 1. 现有问题的严重程度是否阻塞设计推进

**N-01具有明确的阻塞性**：按当前DDL建表后，IoTDA Webhook写入路径将因数据库拒绝`ON CONFLICT`语法而完全失败，影响`sensor_snapshot`和`disease_records`两个核心数据表。从"运行时是否导致功能不可用"的视角看，该问题实际已达到"高"严重度（质询报告亦持相同意见）。诊断报告将其定为"中"是基于"修复难度极低且在设计阶段即被发现"的工程判断，可接受但不改变其阻塞性质。

**N-02、O-01、O-02不具有运行时阻塞性**，但均影响API实现的完整性和一致性：字段缺失会导致实现阶段的理解歧义（N-02），API设计意图无法闭环（O-01），数据保留策略的查询端缺失（O-02）。

综合来看，虽然这4个问题的修复难度都很低，但N-01的阻塞性特征明确，不宜在未修复的情况下将设计文档交付实现阶段。

#### 2. 是否可以通过较小的修订解决剩余问题

**可以**。N-01仅需将两处`CREATE INDEX`改为`CREATE UNIQUE INDEX`（同时建议统一timestamp来源为IoTDA的`event_time`）。N-02、O-01均为API响应字段补全，O-02需新增一个日聚合查询端点。预计修订工作量为**极小**（< 10处文档修改），不会引发大量连带改动。

#### 3. 整体设计是否已经满足系统规格说明书的要求

**大体满足，但尚有几处缺口需补齐**。首轮所有严重和高优先级问题已确认修复，设计文档的自洽性从首轮的约70%提升至约85%。数据存储位置分歧已显式仲裁，API接口覆盖了核心业务场景。剩余问题主要集中在字段对齐和查询端点完整性层面，属于"接近完成但需最后一轮打磨"的状态。

### 四、判定结论

根据再审议框架判定标准（judge.md）：

- PASS条件：审查报告不含严重或一般（中等）等级的问题。
- RETRY条件：审查报告包含严重或一般（中等）等级的问题。

本案中，诊断报告和质询报告**共包含4项中等严重度问题**（N-01, N-02, O-01, O-02），不符合PASS条件，应判定为RETRY。

**有利因素**：内部循环仅消耗1/12轮，修订工作量极低，预计下一轮修订后可达到PASS标准。所有剩余问题均为DDL/API字段级别的小范围修补，不涉及架构级变更。

## 需要解决的问题

- **问题描述**：`sensor_snapshot`和`disease_records`的`(device_id, timestamp)`索引为普通索引而非UNIQUE索引，导致`INSERT ... ON CONFLICT DO NOTHING`在数据库层面执行失败
- **所在位置**：§2.5 表1（sensor_snapshot DDL）、表2（disease_records DDL）；§4.2.1、§4.2.2 处理逻辑
- **严重程度**：中（实际阻塞性可达"高"）
- **改进建议**：将`CREATE INDEX`改为`CREATE UNIQUE INDEX`；同时明确timestamp字段写入时使用IoTDA推送的`event_time`（毫秒级）以保证去重键精度

- **问题描述**：`devices` DDL缺少`ip_addr`字段但API响应包含该字段；`/sensor/history`响应遗漏`ip_addr`和`mac_addr`字段（与`/sensor/latest`不一致）
- **所在位置**：§2.5 表4（devices DDL）；§4.3.3 `/device/list`响应；§4.3.2 `/sensor/history`响应
- **严重程度**：中
- **改进建议**：在devices表增加`ip_addr`字段，或在接口说明中明确ip_addr来自由sensor_snapshot JOIN；补全`/sensor/history`响应中的`ip_addr`和`mac_addr`字段

- **问题描述**：`disease_records` DDL定义了`linkage_risk_level`和`linkage_detail`字段，但病虫害记录API响应示例中未包含，导致联动分析的历史追溯功能无法通过API实现
- **所在位置**：§2.5 表2（disease_records DDL）；§4.4.1 病虫害记录列表响应
- **严重程度**：中
- **改进建议**：在§4.4.1 API响应示例中补充`linkage_risk_level`和`linkage_detail`字段

- **问题描述**：`sensor_daily_aggregation`日聚合表定义了DDL和数据保留策略，但接口清单中无任何端点用于查询日聚合数据，导致超过30天的历史趋势数据无法通过API获取
- **所在位置**：§2.5 表5（sensor_daily_aggregation DDL）；§4.8 接口清单汇总
- **严重程度**：中
- **改进建议**：新增`GET /api/v1/sensor/daily?device_id=...&start=...&end=...`端点，返回日聚合数据，并同步更新§4.8接口清单
