# 系统模块设计 — 质量审查诊断报告（第3轮）

**审查对象**: `a_v3_copy_from_v2.md`（v5 修订版系统模块设计）
**参考文件**:
- `docs/system_specification.md`（系统规格说明书）
- `docs/DATA_INVENTORY.md`（数据清单）
- `b_v2_review_v1.md`（第2轮审查报告，含 N-01/N-02 新发现 + R-01~R-03 残留）
- `b_v2_challenge_v1.md`（第2轮质询报告，含 O-01~O-04 补充问题）
**审查日期**: 2026-07-01
**审查轮次**: 第3轮（v5 修订后审查）
**审查范围**: 重点验证 v5 修订中 6 项修复（N-01, N-02, O-01, O-02, O-03, O-04）是否彻底，兼查是否引入新缺陷

---

## 一、总体评价

v5 修订版针对第2轮审查报告（N-01, N-02）和质询报告（O-01~O-04）中共 6 项设计缺陷进行了集中修复。修订说明（v5）列出的修改措施与文档正文实际变更**完全吻合**，6 项修复**全部实事求是地落实在文档正文中**，未发现"声明修复但未实际修改"的虚假声明。

**总体质量判断**：本轮 6 项修复**全部彻底完成**，文档在该组问题上的自洽性达到满意水平。未发现 v5 修订引入的新设计缺陷。

---

## 二、逐项验证：6 项修复

### N-01（中）：sensor_snapshot 和 disease_records 的 UNIQUE INDEX

**问题回顾**（来源 b_v2_review_v1.md）：DDL 中为普通 `CREATE INDEX`，无法支持 `ON CONFLICT` 幂等性策略（PostgreSQL/KingbaseES 要求 UNIQUE 约束或 UNIQUE 索引作为冲突目标）。

**修复验证**：**已彻底修复**。

| 验证点 | 位置（文档行号） | 原状态 | 当前状态 | 判定 |
|--------|-----------------|--------|---------|------|
| `sensor_snapshot` 索引类型 | §2.5 表1，行 416 | `CREATE INDEX` | `CREATE UNIQUE INDEX idx_sensor_device_time ON sensor_snapshot (device_id, timestamp)` | 通过 |
| `disease_records` 索引类型 | §2.5 表2，行 442 | `CREATE INDEX` | `CREATE UNIQUE INDEX idx_disease_device_time ON disease_records (device_id, timestamp, disease_type)` | 通过 |
| 幂等性说明 timestamp 精度 | §4.2 幂等性说明，行 755-760 | 未提及 event_time 精度 | 增加 `event_time` 毫秒精度要求（`2026-06-30T10:15:30.123Z`），明确优先使用 IoTDA 推送的 `event_time` 而非设备端秒级时间戳 | 通过 |
| §4.2.1 ON CONFLICT 冲突目标 | §4.2.1 行 808 | `(device_id, timestamp)` | 保持 `(device_id, timestamp)`，与 UNIQUE INDEX 列集一致 | 通过 |
| §4.2.2 ON CONFLICT 冲突目标 | §4.2.2 行 858 | `(device_id, timestamp)` | 更新为 `(device_id, timestamp, disease_type)`，与 UNIQUE INDEX 列集一致 | 通过 |

**补充审查**：
- `disease_records` 的 UNIQUE INDEX 增加了 `disease_type` 作为第三列，支持同一设备同一秒内不同病虫害类型的多条检测记录不被误去重。这是一个比审查建议（b）更细致的处理——审查报告仅建议将 INDEX 改为 UNIQUE，v5 修订在此基础上额外考虑了同秒多病害场景。质询报告 §1.3 中关于"AI 识别与传感器数据分属不同表故不存在跨表冲突"的澄清，对此处设计无影响（此处的多病害同秒场景被正确识别和处理的）。
- 质询报告 §1.4 建议"统一 timestamp 来源为 IoTDA event_time"已通过 §4.2 幂等性说明中的 `event_time` 精度要求得到处理，虽然在各 Webhook 处理逻辑的具体步骤中未逐条重复声明"使用 event_time"，但在幂等性统一说明中已明确该规则适用于全部 Webhook 写入路径。**视为合格**。

**修复结论：修复彻底，覆盖了审查报告和质询报告的全部关切。**

---

### N-02（中）：devices 表 ip_addr 字段、sensor/history 响应 ip_addr/mac_addr

**问题回顾**（来源 b_v2_review_v1.md）：(a) `devices` 表 DDL 缺 `ip_addr`，但 `/device/list` 响应含该字段；(b) `/sensor/history` 响应缺 `ip_addr` 和 `mac_addr`，与 `/sensor/latest` 响应格式不一致。

**修复验证**：**已彻底修复**。

| 验证点 | 位置（文档行号） | 原状态 | 当前状态 | 判定 |
|--------|-----------------|--------|---------|------|
| `devices` DDL `ip_addr` 字段 | §2.5 表4，行 475 | 缺失 | `ip_addr VARCHAR(16)` 已添加 | 通过 |
| §4.2.1 处理逻辑同步更新 ip_addr | §4.2.1 步骤4，行 810 | 仅提 last_seen/online | 增加 "更新 devices 表的 last_seen、online、**ip_addr** 字段" | 通过 |
| `/sensor/history` 响应 `ip_addr` | §4.3.2 行 1004 | 缺失 | `"ip_addr": "192.168.1.100"` 已添加 | 通过 |
| `/sensor/history` 响应 `mac_addr` | §4.3.2 行 1005 | 缺失 | `"mac_addr": "A1:B2:C3:D4:E5:F6"` 已添加 | 通过 |
| `/sensor/latest` 响应含 ip_addr/mac_addr | §4.3.1 行 954-955 | 已有 | 保持，与 history 格式统一 | 通过 |
| `/device/list` 响应含 ip_addr | §4.3.4（原 4.3.3）行 1083 | 已有 | 保持，与 DDL 字段对齐 | 通过 |

**附加说明**：质询报告 §2.2 建议将两个子问题（缺少 ip_addr DDL 字段 vs. history 响应字段不一致）拆分为独立编号以便跟踪。v5 修订将它们作为一个编号 N-02 统一修复，修复路径正确且完整，拆分与否不影响修复质量。

**修复结论：修复彻底，devices 表 DDL、传感器数据接收端点处理逻辑、sensor/history 响应三者之间的字段一致性已打通。**

---

### O-01（中）：disease_records API 响应缺少 linkage_risk_level 和 linkage_detail

**问题回顾**（来源 b_v2_challenge_v1.md）：`disease_records` DDL 中已定义联动分析字段，决策引擎会写入这些字段，但 §4.4.1 API 响应示例中不包含这两个字段，导致"支持历史追溯"的设计意图无法通过 API 实现。

**修复验证**：**已彻底修复**。

| 验证点 | 位置（文档行号） | 当前状态 | 判定 |
|--------|-----------------|---------|------|
| `disease_records` DDL 联动字段 | §2.5 表2，行 433-434 | `linkage_risk_level VARCHAR(16)` + `linkage_detail VARCHAR(512)`（已有，非本轮新增） | 通过 |
| 决策引擎写入联动字段 | §2.4 联动监测逻辑步骤3，行 350-355 | 明确持久化写入 | 通过 |
| §3.2 流 B 序列图联动写入 | §3.2 流 B，行 645-647 | 标注"写入 linkage_risk_level, linkage_detail" | 通过 |
| §4.4.1 API 响应 `linkage_risk_level` | §4.4.1 行 1135 | `"linkage_risk_level": "medium"` 已添加 | 通过 |
| §4.4.1 API 响应 `linkage_detail` | §4.4.1 行 1136 | `"linkage_detail": "humidity 60.2% favors rust spread; temperature 25.5℃ within rust favorable range 15-25℃"` 已添加 | 通过 |

**补充审查**：
- 联动字段在多个位置的语义一致：决策引擎输出 `linkage_risk_level`（low/medium/high）+ `linkage_detail`（文本描述），DDL 存储同样字段，API 返回同样字段。三处语义对齐。
- `env_disease_linkage`（防治建议 API 响应，§4.6.1 行 1408-1415）中的 `risk_level` 和 `matched_conditions` 与 `disease_records` 表中的 `linkage_risk_level` 和 `linkage_detail` 存在命名差异，但这属于**有意为之的语义区分**——前者面向实时查询（含建议文本），后者面向持久化记录（含原始匹配详情），并非一致性缺陷。

**修复结论：修复彻底。"DDL 有字段 → 决策引擎写入 → API 返回"的全链路已贯通，"支持历史追溯"的设计意图可落地。**

---

### O-02（中）：sensor_daily_aggregation 聚合表缺少查询 API

**问题回顾**（来源 b_v2_challenge_v1.md）：定义了 `sensor_daily_aggregation` 日聚合表和数据保留策略（30 天前数据聚合后删除明细），但无任何 API 端点查询聚合数据，"聚合-保留-查询"链路在查询端断开。

**修复验证**：**已彻底修复**。

| 验证点 | 位置（文档行号） | 当前状态 | 判定 |
|--------|-----------------|---------|------|
| 新增 §4.3.3 日聚合查询端点 | §4.3.3 行 1016 | `GET /api/v1/sensor/daily` | 通过 |
| 查询参数定义 | §4.3.3 行 1021-1029 | `device_id`（必填）、`start`/`end`（日期，可选）、`page`/`page_size`（可选） | 通过 |
| 响应结构 | §4.3.3 行 1031-1061 | 包含 avg/max/min 温度/湿度/光照/CO2 + `record_count`，分页响应结构与其它接口统一 | 通过 |
| 接口清单更新 | §4.8 行 1511 | 新增第 6 项 `GET /api/v1/sensor/daily` | 通过 |
| 后续条目重编号 | §4.8 行 1504-1523 | 原第 6 项（device/list）→ 第 7 项，后续顺延至 17 项 | 通过 |
| 相关小节重编号 | §4.3.4（原 4.3.3） | 设备列表接口从 4.3.3 → 4.3.4 | 通过 |

**补充审查**：
- 响应字段与 DDL 列对齐：`avg_temperature`/`max_temperature`/`min_temperature` 等均对应 `sensor_daily_aggregation` 表列（§2.5 表5，行 496-509）。
- `record_count` 字段在 DDL 和 API 响应中均存在，语义一致（当天原始快照条数）。
- 参数设计合理：`device_id` 必填（日聚合以设备为维度），`start`/`end` 可选（默认可返回全部聚合数据），分页参数与其它查询接口统一。

**修复结论：修复彻底。日聚合数据的"聚合-保留-查询"全链路已闭合，"保留 30 天明细 + 聚合后查询历史趋势"的数据生命周期设计完整。**

---

### O-03（低）：健康检查 degraded 状态返回 HTTP 503

**问题回顾**（来源 b_v2_challenge_v1.md）：`degraded` 状态返回 HTTP 200，而 Docker healthcheck 使用 `curl -f` 仅对 >=400 的状态码报错，导致数据库连接失败时的降级状态被静默掩盖。

**修复验证**：**已彻底修复**。

| 验证点 | 位置（文档行号） | 原状态 | 当前状态 | 判定 |
|--------|-----------------|--------|---------|------|
| HTTP 状态码逻辑 | §4.10.1 行 1590 | `degraded` 返回 200 | `healthy`→200，`degraded`→**503**，`unhealthy`→503 | 通过 |
| Docker healthcheck 命令 | §5.2 行 1781 | `curl -f /api/v1/health` | `curl -s http://localhost:8000/api/v1/health \| grep -q '"status":"healthy"' \|\| exit 1` | 通过 |

**补充审查**：
- Docker healthcheck 改用 `grep` 解析 JSON 响应体 `status` 字段而非依赖 HTTP 状态码，同时兼容以下场景：(a) API 返回 503 degraded 时 grepping 到非 "healthy" 的 status 值 → exit 1（正确标记 unhealthy）；(b) API 返回 200 healthy 时 → exit 0（正确标记 healthy）。
- 两个 `degraded` 和 `unhealthy` 均返回 503 是合理设计——两者的区分体现在 JSON 响应体 `status` 字段（`degraded` vs `unhealthy`），而 HTTP 状态码层面均为 503 表示服务不可用。这比仅用 HTTP 状态码区分两种异常更精确。

**修复结论：修复彻底。Docker healthcheck 现在能正确感知 degraded 降级状态。**

---

### O-04（低）：control_logs.command_id 为 NULL 的场景说明

**问题回顾**（来源 b_v2_challenge_v1.md）：`control_logs.command_id` 为可 NULL 字段，但在命令写入流程中 `command_id` 的赋值时机未明确——若 `command_id` 在 IoTDA 响应后才回填，则发送到响应之间的窗口期内 `command_id` 为 NULL，重复插入时部分索引无法阻止。

**修复验证**：**已彻底修复**。

| 验证点 | 位置（文档行号） | 当前状态 | 判定 |
|--------|-----------------|---------|------|
| `command_id` 预先生成机制 | §4.5.1 处理逻辑步骤3，行 1250 | API 侧基于时间戳和随机串生成唯一 `command_id`（格式 `cmd_YYYYMMDD_HHmmss_XXX`），在 INSERT 时即写入，非等待 IoTDA 回填 | 通过 |
| 场景一说明（自动触发命令） | §4.5.1 行 1257 | 明确：命令 INSERT 时 `command_id` 已写入（非 NULL），不存在"发送到响应间窗口期内 command_id 为 NULL"的情况 | 通过 |
| 场景二说明（历史遗留记录） | §4.5.1 行 1258 | v0.x/早期原型阶段的控制日志无 `command_id`，v1.0 正式版后均有 | 通过 |
| 设计决策说明 | §4.5.1 行 1260 | 保留可为 NULL：兼容历史数据 + 纯本地控制动作（定时蜂鸣器自检等无需 IoTDA 下发） | 通过 |
| 部分索引保障 | §2.5 表3，行 463 | `CREATE UNIQUE INDEX ... WHERE command_id IS NOT NULL` 确保有 IoTDA 追踪需求的记录不重复 | 通过 |

**补充审查**：
- 场景一说明中"系统内部自动触发的控制命令在 INSERT 时已写入预先生成的 command_id，故不存在窗口期 command_id 为 NULL"的推理成立——因为生成时机从"IoTDA 返回后回填"改为"API 侧预先生成即写入"，窗口期被消除了。
- 纯本地控制动作（如定时蜂鸣器自检）作为 command_id 为 NULL 的合法场景是合理的——这些动作不经过 IoTDA，自然没有 IoTDA 侧的 command_id。部分索引 `WHERE command_id IS NOT NULL` 仅约束有 IoTDA 追踪需求的记录，设计合理。
- 历史数据兼容性作为保留 NULL 的次要理由也成立。

**修复结论：修复彻底。command_id 的赋值时机从"延迟回填"改为"预先生成即写"，消除了插入-响应间的窗口期风险；NULL 场景的说明充分合理。**

---

## 三、修订说明准确性检查

v5 修订说明（文档行 1948-1960）列出的 6 项修改措施，逐一与文档正文实际变更核对：

| 编号 | 修订说明摘要 | 正文对应位置 | 修改匹配度 | 判定 |
|------|------------|-------------|-----------|------|
| N-01 | 索引改为 UNIQUE；timestamp 精度要求；ON CONFLICT 更新 disease_type | §2.5 表1/表2，§4.2 幂等性，§4.2.2 | 完全匹配 | 通过 |
| N-02 | devices DDL 加 ip_addr；§4.2.1 同步更新 ip_addr；§4.3.2 响应加 ip_addr/mac_addr | §2.5 表4，§4.2.1，§4.3.2 | 完全匹配 | 通过 |
| O-01 | disease_records API 响应加 linkage_risk_level/linkage_detail | §4.4.1 | 完全匹配 | 通过 |
| O-02 | 新增 §4.3.3 sensor/daily 端点；重编号 | §4.3.3，§4.3.4，§4.8 | 完全匹配 | 通过 |
| O-03 | degraded HTTP 503；healthcheck 改 grep | §4.10.1，§5.2 | 完全匹配 | 通过 |
| O-04 | 预先生成 command_id；NULL 场景说明 | §4.5.1 | 完全匹配 | 通过 |

**结论：修订说明零虚假声明。**

---

## 四、新缺陷检查

对 v5 修订涉及区域进行逐项巡查，未发现因本轮修改引入的新设计缺陷。以下为巡查摘要：

| 巡查区域 | 变更内容 | 风险点 | 结论 |
|---------|---------|-------|------|
| §2.5 DDL | 两处 CREATE INDEX → CREATE UNIQUE INDEX | 是否遗漏其他表？control_logs 已有 UNIQUE INDEX（行 463），devices 无需此类索引 | 无风险 |
| §4.2 幂等性 | 增加 event_time 精度要求 | §4.2.1/§4.2.2 处理逻辑中未逐步骤重复声明"使用 event_time" | 可接受——统一说明已明确适用范围 |
| §4.3.3 日聚合 API | 新增端点 + 参数 + 响应 | 参数设计、响应字段、分页结构与其它查询端点一致 | 无风险 |
| §4.3 小节重编号 | 4.3.3（日聚合）→ 4.3.4（设备列表） | 重编号后文档内交叉引用是否断裂？ | 已检查——§4.3.4 设备列表接口的行 1064-1090 自包含完整，无对旧编号的引用 |
| §4.8 接口清单 | 新增第 6 项，后续 6→7，7→8... | 重编号覆盖率 | 已检查——全部 17 项编号连续（1-17），无跳号或重复 |
| §4.10.1 健康检查 | HTTP 状态码变更 | `degraded` 和 `unhealthy` 均返回 503，JSON body 区分——Docker healthcheck 已适配 grep 解析 | 无风险 |
| §4.5.1 命令下发 | 增加处理逻辑步骤和 NULL 场景说明 | 命令列表（led ON/OFF 等，行 1284-1293）是否需要同步说明哪些命令对应 IoTDA 下发/本地执行？ | 轻微——但 `command_id` NULL 场景中已说明"纯本地控制动作无需 IoTDA"，命令列表中哪些是"本地控制"可在实现阶段细化 |

**未发现阻塞性新缺陷。**

---

## 五、修改建议汇总

### 5.1 当前阶段无需强制修复（已充分）

本轮 6 项修复均已彻底完成，无遗留强制修复项。

### 5.2 可选优化建议（建议级，不阻塞后续流程）

| 编号 | 问题 | 说明 |
|------|------|------|
| S-05（建议） | 命令列表中区分"IoTDA 下发"与"纯本地控制"命令 | §4.5.1 命令列表（8 条 LED/beep/spray/irrig 命令）与 §4.5.1 的 NULL 场景说明中"纯本地控制动作（如定时任务触发的蜂鸣器自检）"的对应关系未明确——当前 8 条命令是否全经由 IoTDA 下发？若 beep 自检为本地，与 `POST /api/v1/command` 接口的关系是什么？建议在命令列表或控制流程中标注各命令的下发路径（IoTDA vs 本地），避免实现阶段混淆。严重度：**低**——不阻塞设计评审，可在 API 路由实现时细化。 |
| S-06（建议） | `sensor_daily_aggregation` 表 DDL 中 UNIQUE 约束与索引冗余 | §2.5 表5 同时定义了 `UNIQUE (device_id, agg_date)`（行 512）和 `CREATE INDEX idx_agg_device_date ON sensor_daily_aggregation (device_id, agg_date)`（行 515）。在 PostgreSQL/KingbaseES 中，UNIQUE 约束会自动创建唯一索引，同列集的普通索引是冗余的（会多占用一份索引维护开销）。建议移除单独の `CREATE INDEX` 语句，仅保留 UNIQUE 约束。严重度：**低**——不影响功能正确性，仅轻微影响写入性能。 |

---

## 六、修复覆盖率统计

| 来源 | 问题总数 | 已修复 | 合理保留 | 新发现 |
|------|---------|--------|---------|--------|
| 第2轮审查 (N-01, N-02) | 2（中2） | 2 | 0 | — |
| 第2轮质询 (O-01~O-04) | 4（中2/低2） | 4 | 0 | — |
| 本轮 v5 修复合计 | **6** | **6** | **0** | **0**（2 项可选建议） |

**修复率：100%（6/6）。**

---

## 七、关于跨文档协同项的说明

v4 修订说明中的跨文档协同修订清单（4 项：system_specification.md §2.3 数据存储位置、system_specification.md §3 增加 HC-SR04、DATA_INVENTORY.md §2.3 光照阈值、DATA_INVENTORY.md §3.4 TLS 端口）**不属于本轮审查范围**，且用户已明确"不检查 system_architecture_relationship.md 相关的引用"。这些跨文档协同项在设计文档侧已标注（§6.1, §6.5），属于规格说明书和数据清单的修订责任，不构成本模块设计文档自身的质量缺陷。

---

DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202606302338_system_module_design\b_v3_review_v1.md
