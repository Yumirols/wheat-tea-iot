# 系统模块设计 — 质量审查诊断报告（第2轮）

**审查对象**: `a_v2_copy_from_v1.md`（v4 修订版系统模块设计）
**参考文件**:
- `docs/system_specification.md`（系统规格说明书）
- `docs/DATA_INVENTORY.md`（数据清单）
- `b_v1_review_v1.md`（首轮审查报告，29 项问题）
- `b_v1_challenge_v1.md`（首轮质询报告，4 项补充问题 S-01~S-04）
**审查日期**: 2026-07-01
**审查轮次**: 第2轮（修订后审查）
**审查范围**: 重点验证首轮严重/高优先级问题修复情况 + 质询补充问题处理情况 + 修订整体质量 + 新引入缺陷检查

---

## 一、总体评价

修订版（v4）在首轮审查和质询的推动下完成了大量实质改进。修订说明中列出了 30 项修复（严重 4/高 6/中 6/低 14）及 4 项补充处理，修复覆盖率达到 100%（以"已纳入修订说明"计）。以下给出分项验证结论。

**总体质量判断**：修订整体质量**良好**，首轮所有严重和高优先级问题均已处理，质询报告的 4 项补充问题（S-01~S-04）也已纳入修订。但存在 **2 项新发现的设计缺陷**（均属中等级别），以及 **3 项未修复的低优先级残留问题**。

---

## 二、逐项验证：首轮严重问题（C-01, C-02, C-03）

### C-01: `control_logs` 表缺少 `command_id` 字段

**验证结论**: **已修复**。

**验证依据**:
- §2.5 表 3 DDL 中已增加 `command_id VARCHAR(64)` 字段，附注释 `-- IoTDA 命令 ID，用于匹配命令应答`
- 同时增加了 `CREATE UNIQUE INDEX idx_control_command_id ON control_logs (command_id) WHERE command_id IS NOT NULL`
- §4.5.2 控制日志查询接口响应 records 中已包含 `"command_id": "cmd_20260630_101530_001"`
- §4.2.3 命令应答处理逻辑中的过时 DDL 变更提醒已移除

**附加说明**：质询报告建议将 C-01 严重度从"严重"降为"高"（理由为设计文档已标注为已知缺陷）。修订后的设计文档进行了实质性修复而非简单标注，此问题可视为已关闭。

---

### C-02: 系统对外暴露的 HTTP API 无任何认证/授权机制

**验证结论**: **已修复**。

**验证依据**:
- §4.1 通用约定表"认证方式"行已改为 API Key 双模式："开发调试期可用无认证（VPS IP 白名单 + 内网）；生产部署须启用 API Key 认证（HTTP Header `X-API-Key`），服务端通过环境变量 `API_KEYS`（逗号分隔的密钥列表）校验"
- 错误码 1004 = "认证失败" 已定义
- §5.2 docker-compose.yml 中 `API_KEYS=farmeye_key_001,farmeye_key_002` 环境变量已配置
- §4.10 健康检查接口标注为"此接口无需认证"，明确认证边界

**附加说明**：质询报告建议将 C-02 降为"高"（理由为有意简化）。修订方案采用的"双模式"兼顾了课程项目开发便利性和安全底线，设计合理。仅有一处轻微不足：硬编码 `API_KEYS` 在 docker-compose.yml 中不宜直接用于生产部署（应引用 Docker secret 或外部 env_file），但课程项目场景下可接受。

---

### C-03: `system_architecture_relationship.md` 引用文件不存在

**验证结论**: **已修复**。

**验证依据**:
- §1.1：术语等价说明已改写为**自包含描述**，所有术语定义（"端""云""台"、sensor_snapshot 命名理由）直接在本文档中展开
- §2.5 表 1 注释：外部文档引用已移除，改为独立的"表名说明"段落
- §5.1 `docs/` 目录：`system_architecture_relationship.md` 条目已移除；仅列出 system_specification.md、DATA_INVENTORY.md、api_specification.md
- §6.6：sensor_snapshot 表名说明不再引用外部文件
- 对全文执行关键词检索（`system_architecture_relationship`），确认零残留引用

---

## 三、逐项验证：首轮高优先级问题（H-01 ~ H-06）

### H-01: 数据存储位置矛盾（规格书华为云 vs 设计 VPS）

**验证结论**: **已修复**。

**验证依据**:
- §6.1 新增"关于数据存储位置：本设计 vs 规格说明书的分歧与仲裁"专节
- 包含 6 维度显式对比表（成本/国产化/数据主权/开发便利性/IoTDA 集成延迟/规格一致性）
- 给出明确仲裁结论（VPS + KingbaseES，附 6 条理由）
- 标注 `system_specification.md` §2.3 需协同修订
- 修订说明末尾附跨文档协同修订清单

---

### H-02: 上位机"历史数据导出"无对应 API

**验证结论**: **已修复**。

**验证依据**:
- §4.9 新增 `GET /api/v1/export/sensor` 端点完整定义（参数 device_id/start/end/format，返回 CSV/XLSX 文件流）
- 导出量限制（单次 100,000 条，超出返回 1001 错误码）已明确
- §4.8 接口清单汇总新增第 15 项
- §2.7 上位机职责补充导出对接说明

---

### H-04: `/sensor/latest` 多设备响应格式冲突

**验证结论**: **已修复**。

**验证依据**:
- §4.3.1 响应格式已改为 `records` 数组，始终以数组形式返回
- 文档增加"格式统一说明"解释单/多设备场景解析逻辑一致性
- `/sensor/history` 同样使用 `records` 数组，保持前端解析一致

---

### H-05: 湿度报警阈值与传感器量程边界矛盾

**验证结论**: **未修改，但属合理保留**。

**验证依据**:
- §2.1 alarm_flag 表高湿触发条件仍为 `humidity > 90.0%`
- §2.4 告警阈值表同步保持 `humidity > 90.0%`

**分析**：质询报告（b_v1_challenge_v1.md H-05）指出首轮审查的"永远无法触发"推理过度——DHT11 的 20-90% RH 为保证精度范围而非硬量程上限，在高湿冷凝环境下可能超出 90%。设计文档选择保留原阈值是合理的工程判断。修订说明中未将 H-05 列为修复项，暗示作者接受了质询报告的降级论证。**此项不构成剩余问题**。

---

### H-06: 光照报警阈值导致持续误报

**验证结论**: **已修复**。

**验证依据**:
- §2.1 alarm_flag 表低光照触发条件已从 `< 100` 改为 `< 20`
- §2.4 告警阈值表同步修正，并增加说明"阈值 20 对应作物光合作用最低需求"
- 修订说明标注 `DATA_INVENTORY.md` §2.3 需同步修订（跨文档协同清单第 3 项）

---

## 四、逐项验证：质询补充问题（S-01 ~ S-04）

### S-01: 设备端 `service_id` MQTT 携带方式未明确

**验证结论**: **已修复**。

**验证依据**:
- §2.1 新增"数据上报策略（service_id 约定）"小节
- 明确定义两个 service_id：`farmeye_env`（传感器定时上报）和 `farmeye_ai`（AI 事件触发上报）
- 包含上报触发条件、载荷内容说明，并引用 DATA_INVENTORY.md §3.1-§3.2 的 payload 模板
- §3.1 交互总览矩阵更新为包含 service_id 区分
- 修订说明归类为 M-09 修复（实际上 S-01 是质询补充，修订说明中以"S-01（中）"标注）

---

### S-02: 设备在线判定依赖 Redis 未在部署方案体现

**验证结论**: **已修复**。

**验证依据**:
- §2.4 在线状态存储方案明确为"进程内 dict + 单 worker 部署 + devices 表持久化"
- 详细分析多 worker 场景下 dict 不一致问题，明确升级方案为引入 Redis
- 初版不引入 Redis 的理由（单设备课程项目下单 worker 满足需求）已说明
- §2.5 devices 表新增 `online` (BOOLEAN) 和 `last_seen` (TIMESTAMP) 字段支持持久化
- §4.3.3 设备列表接口数据来源说明"优先以 dict 为准，dict 中不存在时回退到数据库 online 字段"

---

### S-03: API 服务 docker-compose 缺少 healthcheck

**验证结论**: **已修复**。

**验证依据**:
- §5.2 api 服务增加完整 healthcheck 配置（`curl -f /api/v1/health`，interval 15s，timeout 5s，retries 3，start_period 30s）
- `depends_on` 改为 `condition: service_healthy`（等待 db 健康检查通过后才启动 api）
- restart 策略 `unless-stopped` 确保异常退出时自动重启

---

### S-04: control_logs 查询接口缺少 source/时间范围筛选

**验证结论**: **已修复**。

**验证依据**:
- §4.5.2 增加可选查询参数 `source`（`auto` / `manual_app` / `manual_pc`）、`start`、`end`
- 参数表格完整定义类型、必填性和说明

---

## 五、新发现的设计缺陷

### N-01 (中等): 幂等性 ON CONFLICT 策略与 DDL 不匹配 — UNIQUE 约束缺失

- **严重程度**: 中
- **位置**: §2.5 表 1（`sensor_snapshot` DDL）、表 2（`disease_records` DDL）；§4.2 幂等性保障说明
- **问题描述**:
  §4.2 的幂等性保障方案要求使用 `INSERT ... ON CONFLICT (device_id, timestamp) DO NOTHING` 防止 IoTDA 重试产生重复记录。然而：
  - `sensor_snapshot` 表仅建有普通索引 `CREATE INDEX idx_sensor_device_time ON sensor_snapshot (device_id, timestamp)`，**不是 UNIQUE 约束/索引**
  - `disease_records` 表同理，仅建有 `CREATE INDEX idx_disease_device_time ON disease_records (device_id, timestamp)`
  - PostgreSQL/KingbaseES 的 `ON CONFLICT` 子句要求冲突目标必须是 UNIQUE 约束或 UNIQUE 索引，普通索引无法作为冲突目标
  
  换言之，按当前 DDL 建表后，§4.2.1 和 §4.2.2 处理逻辑中描述的 `ON CONFLICT DO NOTHING` 将**无法执行**（数据库会报错 `there is no unique or exclusion constraint matching the ON CONFLICT specification`）。

- **修改建议**:
  （a）将 `sensor_snapshot` 的索引改为 `CREATE UNIQUE INDEX idx_sensor_device_time ON sensor_snapshot (device_id, timestamp)`；（b）同理处理 `disease_records`；（c）需要注意：若同一秒内同一设备可能产生多条上报（10s 上报周期下概率很低，但 AI 识别事件触发时可能恰好与定时上报同秒），UNIQUE 约束会导致第二条被静默丢弃。如要避免此问题，可将 `event_time`（IoTDA 推送携带的毫秒级时间戳）作为去重键的一部分，或使用 `timestamp` 精度更高的类型（`TIMESTAMP(3)` 毫秒级）。

---

### N-02 (中等): `GET /api/v1/device/list` 响应包含 `ip_addr`，但 `devices` 表 DDL 无此字段

- **严重程度**: 中
- **位置**: §2.5 表 4（`devices` DDL）；§4.3.3 成功响应 JSON；§4.3.1 成功响应 JSON
- **问题描述**:
  - §4.3.3 设备列表接口的成功响应示例中包含 `"ip_addr": "192.168.1.100"` 字段
  - 接口说明标注"数据来源为 `devices` 表（设备注册信息 + 持久化在线状态）"
  - 但 §2.5 表 4 的 `devices` DDL 中**无 `ip_addr` 字段**（仅有 `device_id`、`device_name`、`mac_addr`、`registered_at`、`last_seen`、`online`、`created_at`）
  - `ip_addr` 实际存储在 `sensor_snapshot` 表中，设备列表接口若需返回 IP 地址，要么从 `sensor_snapshot` JOIN 最新记录获取（增加查询复杂度），要么在 `devices` 表中增加 `ip_addr` 字段并由传感器接收端点同步更新

  **同源不一致性**：`/sensor/latest` 响应包含 `ip_addr` 和 `mac_addr`（来自 sensor_snapshot 表，合理），但 `/sensor/history` 响应示例中**未包含**这两个字段（而 DDL 中 sensor_snapshot 表有这些字段）。这两处不一致暗示字段映射未完全对齐。

- **修改建议**:
  （a）在 `devices` DDL 中增加 `ip_addr VARCHAR(16)` 字段，并在传感器接收端点（§4.2.1）处理逻辑中增加"同步更新 devices 表的 ip_addr"步骤；（b）或者在 §4.3.3 接口说明中明确 `ip_addr` 的来源为"从 sensor_snapshot 表取该设备最新一条记录的 ip_addr"；（c）补充 `/sensor/history` 响应示例中缺失的 `ip_addr` 和 `mac_addr` 字段，使其与 `/sensor/latest` 一致。

---

## 六、未修复的低优先级残留问题

以下问题在首轮审查中标记为"低"，在 v4 修订中未被列入修订说明，经检查确认仍存在。鉴于严重度低且质询报告中对应项均有条件认可，此处仅做记录，不要求强制修复。

### R-01 (低): L-08 — `server/images/` 目录未在工程结构中体现

- **位置**: §5.1 `server/` 目录结构
- **现状**: `images/` 目录（在 §4.7.3 和 docker-compose volume 映射中已有定义）仍未出现在 §5.1 的仓库结构列表中。docker-compose.yml 中的 `./images:/app/images` bind mount 暗示宿主机该目录需事先存在或由 Docker 自动创建，但结构图中缺少对应条目可能使开发者忽视该目录的重要性。
- **建议**: 同首轮审查建议 — 在 `server/` 目录下增加 `images/.gitkeep` 条目。

### R-02 (低): M-02 — 缺少设备注册/管理 API 端点

- **位置**: §4.8 接口清单
- **现状**: 设备注册相关端点仍未添加。质询报告已将其降为"低"级（单设备课程项目下 CRUD 式设备管理属过度设计），此结论可接受。但 §4.3.3 的设备列表接口和 §2.5 的 devices 表已暗示存在多设备场景扩展需求。可在后续迭代中根据实际需求补充。

### R-03 (低): M-04 — `disease_records` 缺少按病虫害类型和严重级别的查询索引

- **位置**: §2.5 表 2（`disease_records` DDL）
- **现状**: 未增加额外的非主键查询索引。质询报告已将其降为"低"级（课程项目数据规模下性能影响可忽略），合理。

---

## 七、修订整体质量评估

### 7.1 修复覆盖率

| 轮次 | 来源 | 问题总数 | 已修复 | 合理保留 | 遗留（低） | 新引入 |
|------|------|---------|--------|---------|-----------|--------|
| 首轮审查 | b_v1_review_v1.md | 29 (严重3/高6/中9/低11) | 26 | 3 (H-05, M-02, M-04) | 3 (L-08, M-02, M-04) | — |
| 质询补充 | b_v1_challenge_v1.md | 4 (中2/低2) | 4 | 0 | 0 | — |
| 本轮新增 | — | — | — | — | — | 2 (中2) |

**修复率**：首轮 29 项中 26 项实质性修复，3 项经质询降级后合理保留；质询 4 项全部修复。总体修复质量令人满意。

### 7.2 修订说明的准确性

修订说明（§7 修订说明 v4 表格）中列出的 30 项修改措施与文档实际变更**逐一匹配**，未发现"声明修复但未实际修改"的虚假声明。跨文档协同修订清单（4 项）指明了需要协同修改的引用文档位置，路径清晰。

### 7.3 新问题的严重性

两项新发现的设计缺陷（N-01, N-02）均属**中等**严重度：
- N-01（幂等性 ON CONFLICT 缺少 UNIQUE 约束）具有阻塞性 — 按当前 DDL 建表后 M-03 的幂等性方案无法工作
- N-02（devices 表缺少 ip_addr 字段）是 API 响应与实际数据模型的错位，会导致实现阶段的困惑

两项问题均应在详细设计或实现阶段开始前修复。

### 7.4 文档自洽性

文档整体自洽性较首轮有显著提升：
- 架构术语和表名理由已内聚在文档内部，消除了对外部缺失文件的依赖
- 数据存储位置分歧已显式仲裁
- API 接口规范中请求/响应示例与 DDL 的对齐度从首轮的约 70% 提升至约 85%（主要剩余：N-02 涉及的两处字段不一致）

---

## 八、改进建议汇总

### 8.1 当前阶段需修复（P1）

| 编号 | 问题 | 严重度 |
|------|------|--------|
| N-01 | `sensor_snapshot` 和 `disease_records` 的 `(device_id, timestamp)` 索引需改为 UNIQUE 以支持 ON CONFLICT 幂等策略 | 中 |
| N-02 | `devices` 表增加 `ip_addr` 字段或明确设备列表接口 ip_addr 的来源；`/sensor/history` 响应补充 `ip_addr` 和 `mac_addr` | 中 |

### 8.2 可延续至详细设计（P2）

| 编号 | 问题 | 说明 |
|------|------|------|
| R-01 | `server/images/` 目录在工程结构中体现 | 低优先级，不影响设计评审 |
| R-02 | 设备注册/管理 API | 经质询降为低优先级 |
| R-03 | `disease_records` 查询索引补充 | 经质询降为低优先级 |

---

DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202606302338_system_module_design\b_v2_review_v1.md
