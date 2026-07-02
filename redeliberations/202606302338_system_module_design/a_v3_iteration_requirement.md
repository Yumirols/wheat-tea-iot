# 组件A 第3轮迭代修订需求

**迭代轮次**: v3（M=3）
**基于产物**: `a_v2_copy_from_v1.md`（v4 修订版系统模块设计，1871 行）
**需求来源**: 第2轮诊断报告（b_v2_review_v1.md）+ 第2轮质询报告（b_v2_challenge_v1.md）
**运行模式**: technical

---

## 一、修订总体说明

本轮为第3轮迭代，需修复第2轮诊断和质询报告发现的共计 **6 项问题**（中4项 / 低2项）。修订范围涉及 DDL 变更、API 响应字段补全、新增查询端点、健康检查状态码调整、以及 command_id 时序说明。所有修改均限于设计文档本身，不涉及跨文档协同。预计改动量极小（< 10 处）。

**设计视角约束**：本轮只关注设计文档的正确性和完整性，不检查项目目录下是否有对应的实现文件。

**已确认无需处理的事项**：`system_architecture_relationship.md` 引用已在 v2 中全部移除，本轮无需额外处理（若修订过程中产生新的外部文件引用，请确保该文件在仓库中存在或改为自包含描述）。

---

## 二、强制修复项（4项 — 中等）

### N-01（中）：sensor_snapshot / disease_records DDL 索引类型错误

**来源**: b_v2_review_v1.md §五 N-01
**质询确认**: b_v2_challenge_v1.md §一 — LOCATED，判定成立

**问题**：
- `sensor_snapshot` 表（§2.5 表1）和 `disease_records` 表（§2.5 表2）的 `(device_id, timestamp)` 索引为普通 `CREATE INDEX`，但 §4.2.1 和 §4.2.2 的处理逻辑要求使用 `INSERT ... ON CONFLICT (device_id, timestamp) DO NOTHING` 实现幂等性保障
- PostgreSQL/KingbaseES 的 `ON CONFLICT` 要求冲突目标是 UNIQUE 约束或 UNIQUE 索引，普通索引无法满足
- 按当前 DDL 建表后，Webhook 接收端点将无法写入数据（数据库直接报错）

**修复要求**：
1. 将 `sensor_snapshot` 表的 `CREATE INDEX idx_sensor_device_time` 改为 `CREATE UNIQUE INDEX idx_sensor_device_time ON sensor_snapshot (device_id, timestamp)`
2. 将 `disease_records` 表的 `CREATE INDEX idx_disease_device_time` 改为 `CREATE UNIQUE INDEX idx_disease_device_time ON disease_records (device_id, timestamp)`
3. （质询补充建议）在 §4.2 幂等性说明或对应处理逻辑中，明确 `timestamp` 字段写入时优先使用 IoTDA 推送的 `event_time`（毫秒级精度），以保证去重键的唯一性精度，避免设备端秒级时间戳导致的同秒冲突

---

### N-02（中）：API 响应字段不一致 — devices 表缺 ip_addr，/sensor/history 缺 ip_addr/mac_addr

**来源**: b_v2_review_v1.md §五 N-02
**质询确认**: b_v2_challenge_v1.md §二 — LOCATED，判定成立（质询建议将子问题 B 拆分为独立编号，但作为组织偏好不强制）

**问题**：
- 子问题 A：§4.3.3 `/device/list` 响应包含 `ip_addr` 字段，但 §2.5 表4 `devices` DDL 中**无 `ip_addr` 字段**。`ip_addr` 实际存储在 `sensor_snapshot` 表中
- 子问题 B：§4.3.2 `/sensor/history` 响应示例**缺少 `ip_addr` 和 `mac_addr`** 字段，而 §4.3.1 `/sensor/latest` 响应已包含这两个字段（且 `sensor_snapshot` DDL 有对应列），两接口响应不一致

**修复要求**：
1. 在 `devices` DDL（§2.5 表4）中增加 `ip_addr VARCHAR(16)` 字段；同时在 §4.2.1 传感器接收端点处理逻辑中增加"同步更新 devices 表的 ip_addr"步骤
2. 补全 §4.3.2 `/sensor/history` 响应示例中的 `ip_addr` 和 `mac_addr` 字段，使其与 `/sensor/latest` 响应格式一致

---

### O-01（中）：disease_records API 响应缺少联动分析字段

**来源**: b_v2_challenge_v1.md §五 O-01

**问题**：
- §2.5 表2 `disease_records` DDL 明确定义了 `linkage_risk_level`（VARCHAR(16)）和 `linkage_detail`（VARCHAR(512)）字段
- 决策引擎在 AI 识别结果处理流程中会写入这两个字段（§2.4 联动监测逻辑步骤3），且文档声明"联动分析结果同时写入 disease_records（持久化留存，支持历史追溯）"（§2.4 行356）
- 但 §4.4.1 病虫害记录列表 API 响应示例中**不包含**这两个字段，客户端无法通过 API 查询联动分析历史记录，导致"历史追溯"设计意图不可实现

**修复要求**：
1. 在 §4.4.1 的 API 响应 JSON 示例中补充 `linkage_risk_level` 和 `linkage_detail` 两个字段，并在 records 数组的元素中展示

---

### O-02（中）：sensor_daily_aggregation 日聚合表缺少查询 API

**来源**: b_v2_challenge_v1.md §五 O-02

**问题**：
- §2.5 表5 定义了 `sensor_daily_aggregation` 日聚合表的完整 DDL
- 数据保留策略（§2.5）规定"30 天前数据按天聚合至 sensor_daily_aggregation 后删除原始明细"
- 但 §4.8 接口清单的 16 个端点中**没有任何端点用于查询日聚合数据**，"聚合-保留-查询"链路在查询端断开

**修复要求**：
1. 在 §4.3（传感器数据查询接口）中新增端点 `GET /api/v1/sensor/daily`，参数至少包含 `device_id`（必填）、`start`（日期）、`end`（日期），返回指定时间范围内的日聚合数据（含日均值/最大/最小值 + record_count）
2. 在 §4.8 接口清单中增加该端点条目
3. （建议）考虑分页支持（虽日聚合数据量通常较小）

---

## 三、建议修复项（2项 — 低）

### O-03（低）：健康检查 degraded 状态返回 HTTP 200 与 Docker healthcheck 探活不匹配

**来源**: b_v2_challenge_v1.md §五 O-03

**问题**：
- §4.10.1 健康判定逻辑规定 `degraded` 时返回 HTTP 200
- §5.2 Docker healthcheck 使用 `curl -f`（仅状态码 >= 400 返回非零退出码）探测，导致 `degraded` 状态被静默掩盖

**修复要求**：
1. 将 `degraded` 状态的 HTTP 状态码改为 503，或在 Docker healthcheck 中改用 `curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"'` 形式的 JSON 解析脚本
   - 若修改 HTTP 状态码：同步更新 §4.10.1 中的状态码说明和 §5.2 的 docker-compose healthcheck 配置
   - 若修改 healthcheck 命令：更新 §5.2 api 服务 healthcheck 的 `test` 配置，使其感知 JSON 响应体中的 `status` 字段

---

### O-04（低）：control_logs.command_id 为 NULL 的时序场景未定义

**来源**: b_v2_challenge_v1.md §五 O-04

**问题**：
- §2.5 表3 `control_logs` 的 `command_id` 字段定义为 `VARCHAR(64)`（可为 NULL），唯一索引使用部分索引 `WHERE command_id IS NOT NULL`
- 命令下发流程中 `command_id` 的生成和写入时序未明确：若 `command_id` 在 IoTDA 响应后才回填，在发送到响应之间的窗口期内 `command_id` 为 NULL，此时客户端重试产生的重复插入无法被部分索引阻止
- §4.5.1 下发命令接口的响应中已包含 `command_id` 字段（由 API 侧预先生成），但 `control_logs` 写入时是否同步填入该 `command_id` 未在流程描述中明确

**修复要求**：
1. 在 §4.5.1 命令下发接口的处理逻辑说明（或 §4.2.3 命令应答处理说明）中，明确 `command_id` 的生成时机：API 侧在收到命令请求后预先生成 `command_id`，在 `INSERT INTO control_logs` 时即写入该值（而非等待 IoTDA 响应回填）
2. 澄清 `command_id` 为 NULL 的合法场景（如：仅在模块/系统内部自动发起的无追踪需求的控制动作下可为 NULL），或评估是否应改为 NOT NULL 约束以彻底消除歧义

---

## 四、首轮残留低优先级问题（本轮不强制修复，仅备注）

以下 3 项为首轮遗留且在第 2 轮被确认为合理保留的低优先级问题，本轮仍不强制修复：

| 编号 | 问题简述 | 严重度 | 说明 |
|------|---------|--------|------|
| R-01 | `server/images/` 目录未在 §5.1 工程结构中体现 | 低 | 可顺带补充 `images/.gitkeep` 条目 |
| R-02 | 缺少设备注册/管理 API 端点 | 低 | 单设备课程项目下 CRUD 式设备管理属过度设计 |
| R-03 | `disease_records` 缺少非主键查询索引 | 低 | 课程项目数据规模下性能影响可忽略 |

---

## 五、修订注意事项

1. **保持设计文档整体自洽性**：DDL 变更后，同步检查与之相关的所有 API 响应示例和处理逻辑描述是否一致
2. **修订说明更新**：在文档末尾"修订说明"节中新增 v5 条目，列出本轮 6 项修复的具体修改措施
3. **文档版本号**：将文档头部版本表新增 v5 条目
4. **不引入新的外部引用**：所有描述保持自包含，若引用外部文件（`DATA_INVENTORY.md`、`system_specification.md`），确保引用的章节号与实际文件中的章节号一致

---

*需求生成时间：2026-07-01*
*生成者：输入解析 agent（再审议框架 — 第3轮）*
*基于诊断报告：b_v2_review_v1.md*
*基于质询报告：b_v2_challenge_v1.md*
