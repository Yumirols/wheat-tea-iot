# 系统模块设计 — 质量质询报告（第2轮）

**质询对象**: `b_v2_review_v1.md`（第2轮质量审查诊断报告）
**被审查的原始物**: `a_v2_copy_from_v1.md`（v4 修订版系统模块设计）
**质询日期**: 2026-07-01
**质询轮次**: 第2轮
**质询范围**: N-01、N-02 新发现问题的质询 + S-01~S-04 验证准确性检查 + 严重度合理性判断 + 遗漏补充

---

## 一、对 N-01（幂等性 ON CONFLICT 策略与 DDL 不匹配）的质询

### 1.1 证据充分性评估

**结论：证据充分，判定成立。**

本座对设计文档进行了独立的逐项核实：

- §2.5 表1 `sensor_snapshot` DDL（设计文档行 415）：确为 `CREATE INDEX idx_sensor_device_time ON sensor_snapshot (device_id, timestamp)` ——普通索引，非 UNIQUE。
- §2.5 表2 `disease_records` DDL（设计文档行 441）：确为 `CREATE INDEX idx_disease_device_time ON disease_records (device_id, timestamp)` ——普通索引，非 UNIQUE。
- §4.2.1 处理逻辑（设计文档行 805）：明确要求 `INSERT ... ON CONFLICT (device_id, timestamp) DO NOTHING`。
- §4.2.2 处理逻辑（设计文档行 855）：同样要求 `ON CONFLICT (device_id, timestamp) DO NOTHING`。
- 数据库行为：PostgreSQL/KingbaseES 的 `ON CONFLICT` 语法要求冲突目标必须是 UNIQUE 约束或 UNIQUE 索引；普通索引无法作为冲突目标，执行时会报错 `there is no unique or exclusion constraint matching the ON CONFLICT specification`。

审查报告的判定与事实一致，证据链完整。

### 1.2 逻辑自洽性评估

**结论：逻辑自洽，但存在一处可商榷的推理论述。**

审查报告在修改建议（c）中写道："若同一秒内同一设备可能产生多条上报（10s 上报周期下概率很低，但 AI 识别事件触发时可能恰好与定时上报同秒），UNIQUE 约束会导致第二条被静默丢弃。"

这一推论的表述存在轻微瑕疵：AI 识别事件写入 `disease_records` 表，传感器定时上报写入 `sensor_snapshot` 表，两者分属不同的表，不会因同一表的 UNIQUE 约束而产生冲突。真正需要对"同秒冲突"保持警惕的场景是：IoTDA 的重试推送与原始推送恰好落入同一秒内——而这也恰恰是 `ON CONFLICT DO NOTHING` 旨在消解的场景（重复数据应被丢弃），因此 UNIQUE 约束在此场景下的"丢弃"行为是**符合设计意图的正确行为**，而非副作用。

不过，存在一个更细微但真实的冲突场景：若设备的系统时钟出现跳变或 NTP 校时导致连续两次上报落在相同秒数（10s 周期的极端边缘情况），UNIQUE 约束会将第二条真实但不同的快照也静默丢弃。这确实是 UNIQUE 方案的固有风险，审查报告的建议（c）中关于提升 timestamp 精度至毫秒级或使用 `event_time` 的建议是合理且审慎的。

**综上所述**：审查报告的推论在总体上成立，表述瑕疵不影响 N-01 的核心判定。

### 1.3 修改建议的可操作性评估

**结论：建议明确、可执行，但缺少一项细节。**

审查报告提出了三级修改建议（a/b/c），均可直接实施。但有一个细节未被指出：在 §4.2 的幂等性说明中（设计文档行 754），设计文档已提及"结合 IoTDA 消息中的 `event_time`（毫秒级）生成唯一键"，但在 §4.2.1 和 §4.2.2 的具体处理逻辑中，写入的 `timestamp` 字段的来源并未明确是设备端时间还是 IoTDA 的 `event_time`。如果修复时仅将索引改为 UNIQUE 而不统一 timestamp 的来源语义，可能导致去重键与实际业务语义不一致。

**建议补充**：审查报告可增加一条说明——在修改 UNIQUE 索引的同时，应明确 `sensor_snapshot.timestamp` 和 `disease_records.timestamp` 在写入时使用 IoTDA 推送的 `event_time`（毫秒级），而非设备 payload 中可能携带的秒级时间，以保证去重键的唯一性精度。

### 1.4 N-01 质询结论

**LOCATED**：N-01 证据充分、逻辑基本自洽、建议可行。仅有一处表述瑕疵（跨表冲突推论）和一处遗漏（timestamp 来源统一性），不构成驳回理由。

---

## 二、对 N-02（devices 表缺少 ip_addr 字段）的质询

### 2.1 证据充分性评估

**结论：证据充分，判定成立。**

逐项核实：

- §2.5 表4 `devices` DDL（设计文档行 469-479）：字段列表为 `device_id`、`device_name`、`mac_addr`、`registered_at`、`last_seen`、`online`、`created_at` ——**无 `ip_addr` 字段**。
- §4.3.3 设备列表接口响应（设计文档行 1027）：包含 `"ip_addr": "192.168.1.100"`。
- §4.3.1 `sensor/latest` 响应（设计文档行 951）：包含 `ip_addr` 和 `mac_addr`。
- §4.3.2 `sensor/history` 响应（设计文档行 988-1002）：**不包含** `ip_addr` 和 `mac_addr` 字段。
- §2.5 表1 `sensor_snapshot` DDL（设计文档行 397、409）：包含 `mac_addr` 和 `ip_addr` 字段。

审查报告同时指出了 `devices` 表字段缺失与 `/sensor/history` 响应不一致两个子问题，均经独立核实确认。

### 2.2 逻辑自洽性评估

**结论：逻辑自洽，但子问题归并方式可商榷。**

审查报告将两个子问题归并入同一个编号 N-02 中。从问题根源来看：

- 子问题 A（`devices` 表缺少 `ip_addr` 字段）的根源在于 DDL 设计与 API 响应规范之间的字段未对齐。
- 子问题 B（`/sensor/history` 缺少 `ip_addr` 和 `mac_addr`）的根源在于两个传感器查询接口的响应格式不一致（`/sensor/latest` 包含而 `/sensor/history` 不包含），其 DDL 侧（`sensor_snapshot` 表）是有这些字段的。

两者的修复路径不同：子问题 A 需要修改 `devices` DDL 或明确 JOIN 来源；子问题 B 仅需补全响应示例中的字段。归并为一个问题编号可能会导致在修复跟踪时混淆。**建议将子问题 B 拆分为独立的 N-03**，以便分别追踪修复状态。

### 2.3 修改建议的可操作性评估

**结论：建议完整、可执行。**

审查报告给出的三级建议（a/b/c）覆盖了各种修复路径，且各建议之间逻辑互斥（选其一），实现者可根据项目偏好选择。

### 2.4 N-02 质询结论

**LOCATED**：N-02 证据充分、逻辑自洽、建议可行。建议将子问题 B（`/sensor/history` 字段不一致）拆分为独立编号以便跟踪，但此属编号组织偏好，不构成驳回理由。

---

## 三、S-01~S-04 验证准确性检查

本座对审查报告第四节的四项验证逐条进行了独立核实：

### 3.1 S-01：设备端 service_id MQTT 携带方式

- **审查报告验证结论**：已修复
- **本座独立核实**：
  - 设计文档 §2.1 确实新增了"数据上报策略（service_id 约定）"小节，包含 `farmeye_env` 和 `farmeye_ai` 两个 service_id 的完整定义 ✓
  - §3.1 交互总览矩阵中 `service_id` 区分已体现 ✓
  - §3.1 中引用了 `DATA_INVENTORY.md` §3.1–§3.2 的 payload 模板 ✓
- **质询结论：验证准确**。审查报告的判断与文档实际变更一致。

### 3.2 S-02：设备在线判定依赖 Redis 未在部署方案体现

- **审查报告验证结论**：已修复
- **本座独立核实**：
  - §2.4 明确说明采用"进程内 dict + 单 worker 部署 + devices 表持久化"方案 ✓
  - 多 worker 场景的升级路径（引入 Redis）已分析说明 ✓
  - §2.5 `devices` 表包含 `online` 和 `last_seen` 字段 ✓
  - §4.3.3 设备列表接口数据来源说明中包含了 dict 优先、数据库回退的逻辑 ✓
- **质询结论：验证准确**。审查报告对修复范围和充分性的判定正确。

### 3.3 S-03：API 服务 docker-compose 缺少 healthcheck

- **审查报告验证结论**：已修复
- **本座独立核实**：
  - §5.2 docker-compose.yml 中 api 服务包含完整的 healthcheck 配置（curl、interval 15s、timeout 5s、retries 3、start_period 30s） ✓
  - `depends_on` 已改用 `condition: service_healthy` ✓
  - `restart: unless-stopped` 已配置 ✓
- **质询结论：验证准确**。

### 3.4 S-04：control_logs 查询接口缺少 source/时间范围筛选

- **审查报告验证结论**：已修复
- **本座独立核实**：
  - §4.5.2 查询参数表已增加 `source`（`auto`/`manual_app`/`manual_pc`）、`start`、`end` 参数 ✓
  - 参数表完整定义了类型、必填性和说明 ✓
- **质询结论：验证准确**。

### 3.5 S-01~S-04 验证总评

审查报告对四项补充问题的验证**全部准确**，未发现"声明已修复但实际未修改"或"修改不充分"的情况。验证依据引用精确到章节和行号级别，证据链完整。

---

## 四、严重度分级合理性判断

### 4.1 N-01（中 → 可议升为高）

| 维度 | 分析 |
|------|------|
| 运行时影响 | **阻塞性**：按当前 DDL 建表后，每次 INSERT 都会触发数据库报错，数据写入完全失败 |
| 影响范围 | 波及两个核心数据表（sensor_snapshot 和 disease_records），覆盖全部 IoTDA Webhook 写入路径 |
| 修复难度 | **极低**：将 `CREATE INDEX` 改为 `CREATE UNIQUE INDEX` 即可 |
| 发现时机 | 设计评审阶段，未进入实现阶段 |

**质询意见**：N-01 的运行时影响是明确的阻塞性错误（数据库拒绝执行），从影响面看可归入"高"严重度。但考虑到修复难度极低（单行修改）且在设计评审阶段即被发现，审查报告将其定级为"中"是**可接受的工程判断**，本座不要求调整。若项目采用更严格的分级标准（以"运行时是否导致功能不可用"为唯一判据），则应升为"高"。

### 4.2 N-02（中 → 维持）

| 维度 | 分析 |
|------|------|
| 运行时影响 | API 实现时开发者无法从 `devices` 表直接获取 `ip_addr`，需要额外 JOIN 或字段补充；不会导致运行时报错 |
| 影响范围 | 设备列表接口和传感器历史接口 |
| 修复难度 | 低（增加一个 VARCHAR 字段或明确 JOIN 逻辑） |

**质询意见**：定级"中"合理，维持。

### 4.3 R-01 ~ R-03（低 → 维持）

三项残留问题的"低"定级均由上一轮质询报告论证且被本轮审查报告正确引用，分级合理，维持。

---

## 五、审查报告遗漏的重要问题（补充提出）

在对设计文档进行独立复查的过程中，本座发现以下审查报告未覆盖但具有设计影响的问题：

### O-01（中）：`disease_records` API 响应缺少 `linkage_risk_level` 和 `linkage_detail` 字段

- **位置**：§2.5 表2 `disease_records` DDL（设计文档行 432-433）；§4.4.1 病虫害记录列表响应（设计文档行 1070-1081）
- **问题描述**：
  `disease_records` 表的 DDL 中已明确定义了 `linkage_risk_level`（VARCHAR(16)）和 `linkage_detail`（VARCHAR(512)）字段，决策引擎在 AI 识别结果处理流程中会写入这两个字段（设计文档行 350-352），且文档明确声明"联动分析结果同时写入 disease_records（持久化留存，支持历史追溯）"（设计文档行 356）。然而 §4.4.1 的病虫害记录列表 API 响应示例中**不包含**这两个字段。这意味着客户端无法通过 API 查询到联动分析的历史记录，"支持历史追溯"的设计意图无法实现。
- **与 N-02 的关系**：此问题与 N-02 发现的 `/sensor/history` 字段不一致属于同类问题（DDL 有字段但 API 响应遗漏），但涉及不同的表和接口，应独立追踪。
- **建议**：在 §4.4.1 的 API 响应示例（以及对应的查询接口实现）中补充 `linkage_risk_level` 和 `linkage_detail` 字段；若设计者认为这两个字段属于内部字段不应对外暴露，则应在文档中明确说明并移除"支持历史追溯"的表述。

### O-02（中）：`sensor_daily_aggregation` 聚合表缺少查询 API

- **位置**：§2.5 表5 `sensor_daily_aggregation` DDL；§4.8 接口清单汇总；§2.5 数据保留策略
- **问题描述**：
  设计文档定义了 `sensor_daily_aggregation` 日聚合表（§2.5 表5），且数据保留策略明确规定"30 天前数据按天聚合至 sensor_daily_aggregation 后删除原始明细"（设计文档行 522）。然而，§4.8 接口清单汇总的 16 个端点中**没有任何一个端点用于查询日聚合数据**。这意味着：
  - 超过 30 天的历史数据虽然经过聚合保留了日统计信息，但客户端无法通过 API 获取
  - 上位机的历史趋势图表（如月级别温度曲线）和鸿蒙 App 的历史数据展示均无法使用聚合数据
  - 数据的"聚合-保留-查询"链路在查询端断开，聚合表的存在价值被严重削弱
- **建议**：在 §4.3（传感器数据查询接口）或独立小节中新增 `GET /api/v1/sensor/daily?device_id=...&start=...&end=...` 端点，返回指定时间范围内的日聚合数据（日均值/最大/最小），并同步更新 §4.8 接口清单。

### O-03（低）：健康检查接口 HTTP 200 响应可能掩盖 `degraded` 状态

- **位置**：§4.10.1 服务健康检查接口
- **问题描述**：
  设计文档 §4.10.1 的健康判定逻辑规定：`healthy`/`degraded` 时返回 HTTP 200，`unhealthy` 时返回 503。§5.2 的 Docker healthcheck 配置使用 `curl -f`（`--fail`）探测 `/api/v1/health`，而 `curl -f` 仅在 HTTP 状态码 >= 400 时返回非零退出码。这意味着当数据库连接失败、服务进入 `degraded` 状态时，API 仍返回 HTTP 200，Docker healthcheck 不会感知到降级，容器不会被标记为 unhealthy 或触发 restart。
- **影响**：在数据库短暂不可用期间，`degraded` 状态会被静默掩盖。考虑到 Docker Compose 中 `depends_on: condition: service_healthy` 已配置，这种掩盖不会导致级联问题（数据库不可用时 db 容器的 healthcheck 会先失败），但 API 自身的状态报告准确性存在缺陷。
- **建议**：考虑将 `degraded` 的 HTTP 状态码改为 503（与 `unhealthy` 一致），或在 Docker healthcheck 中改用解析 JSON 响应体 `status` 字段的脚本（而非仅依赖 HTTP 状态码）。课程项目场景下影响有限，定为低严重度。

### O-04（低）：`control_logs` 的 `command_id` 为 NULL 的场景未定义

- **位置**：§2.5 表3 `control_logs` DDL（设计文档行 462）；§4.5.1 命令下发接口；§4.2.3 命令应答处理
- **问题描述**：
  `control_logs` 表的 `command_id` 字段被定义为可 NULL（`VARCHAR(64)` 无 NOT NULL 约束），且唯一索引使用了部分索引 `CREATE UNIQUE INDEX ... WHERE command_id IS NOT NULL`。这种设计允许存在 `command_id IS NULL` 的多条记录。然而在业务流程中：§4.5.1 手动控制流程中，命令下发后 `control_logs` 插入时是否生成 `command_id` 未明确；若 `command_id` 仅在 IoTDA 返回后才回填，则在命令发送后到 IoTDA 响应前的窗口期内 `command_id` 可能为 NULL。此时如果发生重复插入（如客户端重试），部分索引无法阻止。这是一个设计细节的边缘情况，需要明确 `command_id` 的生成和写入时序。
- **建议**：明确控制日志写入流程中 `command_id` 的赋值时机（建议在 API 侧预先生成 `command_id` 作为请求追踪 ID，插入 control_logs 时即写入，而非等待 IoTDA 响应回填），或评估是否应改为 NOT NULL 约束。

---

## 六、整体评价

### 6.1 审查报告质量总评

本轮审查报告（b_v2_review_v1.md）的总体质量**较好**，主要表现在：

- 首轮问题逐项验证认真，每项均引用了设计文档的具体章节号和行级证据
- S-01~S-04 全部 4 项补充问题的验证准确无误
- 新发现的两项设计缺陷（N-01、N-02）证据链完整，判定正确
- 修订说明准确性检查（§7.2）细致，覆盖了"声明修复但未实际修改"的虚假声明风险

### 6.2 主要不足

- **覆盖广度不足**：审查报告遗漏了至少 2 项中等严重度的设计缺陷（O-01 聚合表无查询 API、O-02 disease_records API 响应字段缺失），以及 2 项低严重度的设计瑕疵（O-03 degraded 状态掩盖、O-04 command_id NULL 场景）。O-01 和 O-02 直接影响功能的完整性，属于审查维度中的重要遗漏。
- **N-01 的修复建议**：未涵盖 timestamp 字段来源统一性问题（使用设备端时间还是 IoTDA event_time），可能导致修复不彻底。
- **N-02 的子问题归并**：将两个修复路径不同的子问题合并为一个编号，不利于后续修复跟踪。

### 6.3 最终裁决

根据质量质询 Agent 的通过/驳回标准，本轮审查报告存在 **证据充分性瑕疵**（覆盖不完备——遗漏了至少两项具中等影响的设计缺陷），裁决为：

CHALLENGED:E:\dev\wheat-tea-iot\redeliberations\202606302338_system_module_design\b_v2_challenge_v1.md
