# 系统模块设计 — 质量审查诊断报告

**审查对象**: `redeliberations/202606302338_system_module_design/a_v1_imported.md`（即 `docs/system_architecture.md`）
**参考文件**:
- `docs/system_specification.md`（系统规格说明书）
- `docs/DATA_INVENTORY.md`（数据清单）
**审查日期**: 2026-06-30
**审查轮次**: 首轮
**审查范围**: 一致性、完整性、正确性、模块职责清晰度、数据交互覆盖、接口规范完整性、工程文件组织结构、设计决策合理性

---

## 一、总体评价

该文档作为系统模块设计产出，覆盖了"端-云-台"三层架构的完整定义，对嵌入式端、AI 识别模块、IoTDA、Python API 后台、金仓数据库、鸿蒙应用和 Python 上位机七大模块的职责与边界做了较为详细的描述。API 接口规范（14 个端点）的请求/响应格式定义较为完整，工程文件组织结构清晰。

然而，文档存在以下结构性缺陷：
- **与系统规格说明书存在关键矛盾**：数据存储位置（华为云 vs VPS KingbaseES）在规格书与设计文档之间未达成一致，且设计中未对此做出解释。
- **数据库 Schema 存在阻塞性字段缺失**：`control_logs` 表缺少命令 ID 字段，直接影响命令应答匹配的正确实现。
- **若干引用文件不存在**：文档多处引用的 `system_architecture_relationship.md` 在仓库中缺失，导致术语对照和表名协调说明成为悬空引用。
- **API 接口在边界条件下行为未定义**：多设备场景下 `/sensor/latest` 的响应格式与单设备场景冲突，图片上传无关联记录时的元数据持久化未解决。

以下按严重程度分级列出全部发现问题，附具体位置和修改建议。

---

## 二、问题清单

### 严重 (Critical)

---

#### C-01: `control_logs` 表缺少 `command_id` 字段，命令应答匹配链路断裂

- **严重程度**: 严重
- **位置**: §2.5 表 3（`control_logs` DDL）；§4.2.3 处理逻辑步骤 2-3
- **问题描述**:
  §4.2.3 定义的命令应答接收端点（`POST /api/v1/iotda/cmd/response`）处理逻辑要求"根据 `request_id` 在 `control_logs` 表中查找对应的命令记录"。然而 §2.5 表 3 的 `control_logs` DDL 中**不存在 `command_id` 字段**。虽然 §4.2.3 末尾的注释承认了这一缺失并标注"将在详细设计阶段同步"，但当前设计文档中该表 schema 与业务流程不匹配，属于阻塞性缺陷——按当前 DDL 建表后命令应答匹配功能无法实现。

- **修改建议**:
  在 `control_logs` 表 DDL 中增加 `command_id VARCHAR(64)` 字段，并在 `(device_id, command_id)` 上建立索引以支持命令应答的高效匹配。

---

#### C-02: 系统对外暴露的 HTTP API 无任何认证/授权机制

- **严重程度**: 严重
- **位置**: §4.1 通用约定表，"认证方式"行
- **问题描述**:
  文档明确声明"初版可暂用无认证（VPS IP 白名单 + 内网）"。该设计存在以下风险：
  - Python API 部署在**境外公网 VPS**上，端口 8000 映射至宿主机公网，任何知道 IP 和端口的攻击者均可直接调用设备控制接口（`POST /api/v1/command`），远程操控农田现场的喷淋、灌溉等物理设备。
  - 病虫害数据、传感器历史数据、设备 IP/MAC 地址等敏感信息无访问控制。
  - 即使 VPS 配置 IP 白名单，鸿蒙 App 通过移动网络访问时 IP 动态变化，白名单方案不适用移动端。

- **修改建议**:
  至少实现基于 API Key 的简单认证（通过请求头 `X-API-Key` 传递），在 FastAPI 中间件层统一校验。鸿蒙 App 和上位机在配置中预置 API Key。同时补充 API Key 的分发与轮换策略说明。

---

#### C-03: 设计文档多处引用的 `system_architecture_relationship.md` 文件不存在

- **严重程度**: 严重
- **位置**: §1.1 架构术语说明、§2.5 表 1、§5.1 `docs/` 目录结构、§6.6
- **问题描述**:
  文档在以下位置引用了 `system_architecture_relationship.md`：
  - §1.1：术语等价说明引用该文档 §1 定义
  - §2.5 表 1 注释：表名对照引用该文档 §2.5
  - §5.1 仓库顶层结构：将 `system_architecture_relationship.md` 列为 `docs/` 下的文档之一
  - §6.6：`sensor_snapshot` vs `sensor_data` 命名协调引用该文档

  经检查，该文件在仓库中**不存在**（Glob 搜索无结果）。所有引用成为悬空引用，架构术语和表名对照失去了上下文支撑。

- **修改建议**:
  （a）若该文件计划产出但尚未编写，应在文档中标注"（待产出）"并在此处给出完整的术语对照而不依赖外部文档；（b）若该文件是已计划但尚未纳入仓库的文档，应补充创建；（c）§5.1 的 `docs/` 目录列表中移除该条目或标注为计划产出。

---

### 高 (High)

---

#### H-01: 系统规格说明书与模块设计在数据存储位置上存在矛盾

- **严重程度**: 高
- **位置**: `system_specification.md` §2.3；本设计文档 §1.2-§1.3、§2.4-§2.5
- **问题描述**:
  - 规格说明书 §2.3 明确要求"将病虫害及环境数据上传并存储至**华为云**"，并"利用 Python 平台处理**云端数据**"。
  - 模块设计将 Python API 后台和金仓数据库部署在**境外公网 VPS**上，数据存储于自建 KingbaseES 而非华为云存储服务。
  - 设计文档 §6.1 对 VPS 部署做了设计决策说明，但**未解释与规格书的这一分歧**，也未说明规格书是否需要修订。

- **修改建议**:
  （a）在 §6.1 中增加与规格书的矛盾说明与仲裁理由（如：华为云数据库服务成本考量、KingbaseES 国产化要求、数据主权等）；（b）更新规格说明书 §2.3，将"华为云"修正为"VPS 自建 KingbaseES 数据库"或标注为架构演进后的变化；（c）若数据需要同时在华为云保留副本（如 IoTDA 侧的数据存储），须在设计中明确。

---

#### H-02: Python 上位机"历史数据导出"功能无对应 API 端点

- **严重程度**: 高
- **位置**: §2.7 Python 上位机职责；§4.8 接口清单汇总
- **问题描述**:
  §2.7 明确列出上位机职责包括"历史数据导出（CSV/Excel）"，但 §4.8 的 14 个 API 端点中没有数据导出接口。当前接口仅支持按分页查询（`/sensor/history`、`/disease/records`），上位机若需导出全量数据，须自行循环分页拼接，效率低且易出错。

- **修改建议**:
  增加 `GET /api/v1/export/sensor?device_id=...&start=...&end=...&format=csv` 端点，服务端直接返回 CSV 文件流（`Content-Type: text/csv`，`Content-Disposition: attachment`）。Excel 格式通过 CSV 转换或选用 `openpyxl` 服务端生成。同时在下位机 API 客户端封装中对接此端点。

---

#### H-03: 图片上传接口在无关联 `disease_record_id` 时元数据无法持久化

- **严重程度**: 高
- **位置**: §4.7.1；§2.5 数据库表规划
- **问题描述**:
  - `POST /api/v1/image/upload` 的 `disease_record_id` 参数为**非必填**。当用户上传图片但不传此参数时，返回的 `image_id` 和 `image_path` 仅存在于响应中，**没有任何数据库表记录该图片的元数据**。
  - 数据库设计中无独立的 `images` 表。图片文件的唯一持久化链接是通过 `disease_records.image_path` 字段，但该字段仅在提供 `disease_record_id` 时才会被写入。
  - 后果：用户上传图片后若丢失返回的 `image_id`，该图片将成为"孤儿文件"，无法通过 API 检索和管理。

- **修改建议**:
  （a）增加独立的 `images` 表（字段：`id`、`image_id`、`file_path`、`file_size`、`device_id`、`disease_record_id`（可空）、`uploaded_at`），作为图片元数据的权威记录；（b）`GET /api/v1/image/{image_id}` 通过该表解析文件路径；（c）`disease_records.image_path` 通过 `disease_record_id` 外键关联该表，保持数据一致性。

---

#### H-04: `GET /api/v1/sensor/latest` 多设备场景响应格式与单设备场景冲突

- **严重程度**: 高
- **位置**: §4.3.1
- **问题描述**:
  - 查询参数说明："不传 [`device_id`] 则返回所有设备各自最新一条"。
  - 但成功响应示例是**单个设备对象**结构（`"device_id": "...", "temperature": ...`），不是数组。
  - 当多个设备存在时，此响应格式无法容纳多条记录，客户端无法解析。

- **修改建议**:
  统一响应格式：始终返回 `records` 数组，即使只有一条记录。修改为：
  ```json
  {
    "code": 0,
    "message": "success",
    "data": {
      "records": [
        { "device_id": "...", "timestamp": "...", "temperature": ... }
      ]
    }
  }
  ```

---

#### H-05: 湿度报警阈值与 DATA_INVENTORY 中传感器量程存在边界矛盾

- **严重程度**: 高
- **位置**: §2.1 alarm_flag 位掩码表（`ALARM_HUMI_HIGH` 触发条件）；`DATA_INVENTORY.md` §2.2
- **问题描述**:
  - DATA_INVENTORY §2.2 定义 humidity **范围为 20 ~ 90%**，报警条件为 `> 90.0%`。
  - 若传感器量程上限即为 90%，则 `humidity > 90.0%` 的条件在量程范围内**永远无法触发**（最大只能到 90.0，不大于 90.0）。
  - DHT11 数据手册典型量程为 20-90% RH（精度 ±5%），偶尔可能在极端条件下超出，但依赖边界值触发不可靠。

- **修改建议**:
  （a）确认 DHT11 在该硬件平台上的实际量程与精度；（b）将高湿报警阈值调整为 `>= 90.0%` 或 `>= 85.0%`（留出传感器容差）；（c）在 `DATA_INVENTORY.md` 中补充量程与报警阈值的关系说明。

---

#### H-06: 光照报警阈值导致几乎持续误报

- **严重程度**: 高
- **位置**: §2.1 alarm_flag 位掩码表（`ALARM_LIGHT_LOW` 触发条件）；`DATA_INVENTORY.md` §2.3
- **问题描述**:
  - 光照数据范围为 0-100（百分比），报警条件为 `light < 100`。
  - 这意味着只要光照未达到 100%（即几乎永远），低光照报警就会持续触发。
  - 在农田/茶园实际环境中，100% 光照几乎不可能达到（即使是正午强光，LDR 经 ADC 归一化后也未必满量程）。

- **修改建议**:
  将低光照报警阈值调整为合理值（如 `light < 20` 或 `light < 10`），参考农作物光合作用最低光照需求设定。同步更新 `DATA_INVENTORY.md` §2.3 的报警条件。

---

### 中 (Medium)

---

#### M-01: 数据库缺少独立的设备信息表

- **严重程度**: 中
- **位置**: §2.5 数据表规划
- **问题描述**:
  当前设计中设备信息（`device_id`、`mac_addr`、`ip_addr`）仅作为 `sensor_snapshot` 表中的字段存在，没有独立的 `devices` 表。这导致：
  - 设备上线/下线状态（§4.3.3 `GET /api/v1/device/list` 中的 `online` 字段）只能从内存缓存（Redis 或进程内 dict）获取，服务重启后所有设备状态丢失。
  - 设备注册时间、设备名称、部署位置等元信息无处存储。
  - 多设备场景下设备管理无持久化基础。

- **修改建议**:
  增加 `devices` 表（字段：`id`、`device_id`（唯一键）、`device_name`、`mac_addr`、`registered_at`、`last_seen`、`online`（布尔））。设备在线状态持久化至该表，API 的 `/api/v1/device/list` 直接查表返回。

---

#### M-02: 缺少设备注册/管理 API 端点

- **严重程度**: 中
- **位置**: §4.8 接口清单汇总
- **问题描述**:
  当前 API 端点清单中没有设备注册、设备信息更新、设备删除接口。在 IoTDA 侧完成设备注册后，Python API 侧并无法获知新设备的存在，除非该设备开始上报数据。这使设备生命周期管理完全依赖外部平台（IoTDA）。

- **修改建议**:
  增加以下端点：
  - `POST /api/v1/device/register`：注册设备（接受 device_id、device_name、部署位置等）
  - `PUT /api/v1/device/{device_id}`：更新设备信息
  - `DELETE /api/v1/device/{device_id}`：注销设备
  同时支持从 IoTDA 同步设备列表（调用 IoTDA 的设备查询 API）。

---

#### M-03: IoTDA Webhook 接收缺少幂等性保障

- **严重程度**: 中
- **位置**: §4.2.1、§4.2.2、§4.2.3 处理逻辑
- **问题描述**:
  - §4.2 提到"规则转发失败时，IoTDA 侧有重试机制（默认重试 3 次，间隔 30s）"。
  - 若 Python API 成功处理了数据（写入数据库）但返回 200 的响应在网络中丢失，IoTDA 将重试推送，导致**同一条传感器数据或病虫害记录被重复写入**。
  - 当前三个 Webhook 接收端点的处理逻辑均未包含去重/幂等性检查。

- **修改建议**:
  （a）在 `sensor_snapshot` 和 `disease_records` 表的写入逻辑中增加基于 `(device_id, timestamp)` 或 IoTDA 消息 ID 的去重判断（`INSERT ... ON CONFLICT DO NOTHING` 或应用层先查后插）；（b）在 §4.2 的处理逻辑中增加"幂等性保证"步骤说明。

---

#### M-04: `disease_records` 表缺少按病虫害类型和严重级别的查询索引

- **严重程度**: 中
- **位置**: §2.5 表 2（`disease_records` DDL）
- **问题描述**:
  `disease_records` 表仅建有 `(device_id, timestamp)` 复合索引。但 API 端点支持按 `crop_type`、`disease_type`、`severity` 等字段筛选（§4.4.1），统计数据接口（§4.4.2）还需按这些维度做聚合查询。缺少相应索引会导致全表扫描。

- **修改建议**:
  增加以下索引：
  - `(crop_type, disease_type)` 复合索引
  - `(severity_code)` 索引
  - `(device_id, disease_type, timestamp)` 复合索引（覆盖最常见的查询组合）

---

#### M-05: 缺少 API 健康检查端点

- **严重程度**: 中
- **位置**: §4.8 接口清单汇总
- **问题描述**:
  当前 14 个 API 端点中无健康检查端点。对于 Docker 容器化部署的服务，缺少健康检查端点意味着：
  - docker-compose 的 `healthcheck` 只能依赖进程存活判断，无法确认应用内部状态（数据库连接、IoTDA 连通性等）
  - 反向代理（Nginx）无法做后端可用性探测
  - 运维监控无法区分"服务运行中"与"服务可用"

- **修改建议**:
  增加 `GET /api/v1/health` 端点，返回数据库连接状态、IoTDA 连通性（可选）、服务运行时间等信息。在 `docker-compose.yml` 中将 `healthcheck` 指向此端点。

---

#### M-06: MQTT 设备连接仅使用明文端口（1883），未涉及 TLS

- **严重程度**: 中
- **位置**: §2.3 MQTT 连接参数表、`DATA_INVENTORY.md` §3.4
- **问题描述**:
  - MQTT 连接配置仅给出了明文端口 1883，而非 TLS 端口 8883。
  - 设备上报的传感器数据（包括设备 IP、MAC 地址）在公网上明文传输，存在被窃听和篡改的风险。
  - 命令下发（如 `spray ON`）若被中间人篡改可能导致物理设备误动作。

- **修改建议**:
  （a）在连接参数表中增加 TLS 端口 8883 的备选配置；（b）说明明文端口仅用于开发/调试阶段，生产环境必须切换到 TLS；（c）说明 IoTDA 侧的 TLS 证书配置要求（设备端需预置 CA 证书或使用 PSK）。

---

#### M-07: 决策引擎中 AI 识别记录写入与联动分析的时序不明确

- **严重程度**: 中
- **位置**: §2.4 决策引擎逻辑描述；§3.2 流 B 序列图
- **问题描述**:
  §2.4 环境-病虫害联动监测逻辑描述为：
  > 1. 从 `sensor_snapshot` 表拉取最近 1 小时内的环境数据
  > 2. 计算环境因子与当前病虫害的关联度
  > 3. 将联动分析结果写入防治建议...

  但 §3.2 流 B 的序列图显示决策引擎评估发生在 `INSERT disease_records` 之后，而 `disease_records.action_taken` 字段并未在图中被更新。决策引擎产出的"联动分析结果"写入何处（是否写入 `disease_records` 的新增字段？）未定义。

- **修改建议**:
  （a）明确联动分析结果的存储位置（建议在 `disease_records` 中增加 `linkage_risk_level` 和 `linkage_detail` 字段，或建立独立的 `env_disease_linkage` 关联表）；（b）更新流 B 序列图，将联动分析结果的数据库写入步骤显式标出；（c）说明 `action_taken` 字段在自动控制触发后由哪一步骤更新。

---

#### M-08: `GET /api/v1/sensor/history` 响应记录中缺少 `device_id` 字段

- **严重程度**: 中
- **位置**: §4.3.2 成功响应 JSON
- **问题描述**:
  `/api/v1/sensor/history` 的查询参数中 `device_id` 是必填项，响应 JSON 中的 `records` 数组元素包含温度、湿度等数据字段但不包含 `device_id`。虽然单次请求已限定了设备，但：
  - 客户端在前端展示多个设备的历史数据时需要自行关联 `device_id`
  - 若未来 `device_id` 改为非必填，响应记录将无法区分来源

- **修改建议**:
  在 `/sensor/history` 响应 JSON 的 `records` 数组每个元素中增加 `device_id` 字段，与 `/sensor/latest` 保持一致。

---

#### M-09: 决策规则矩阵未覆盖"环境条件不满足"时的行为

- **严重程度**: 中
- **位置**: §2.4 决策规则矩阵
- **问题描述**:
  决策规则矩阵中 severity_code=2 的行都有触发环境条件列（如 `humidity > 85%` 或 `15℃ ≤ temperature ≤ 25℃`），但矩阵未说明**当环境条件不满足时**系统的行为。例如：
  - rust severity_code=2 但 humidity=50% 且 temperature=10℃，是否完全不做任何动作？是否仍有防治建议生成？
  - 文档对"不触发自动动作"和"不生成防治建议"之间的区别未做区分。

- **修改建议**:
  在决策规则矩阵中增加"条件不满足时行为"列，明确即使不触发自动动作，仍需要生成防治建议（仅 `action` 为 `manual_inspect` 或类似标识）并通过 `/api/v1/advisory` 返回。

---

### 低 (Low)

---

#### L-01: AI 推理输出 JSON 缺失时间戳字段

- **严重程度**: 低
- **位置**: §2.2 输出数据结构
- **问题描述**:
  AI 推理模块传递给 MCU 的输出 JSON 不包含 `timestamp` 字段。虽然 MCU 在封装上报时可以添加，但推理结果的精确时间点应由 AI 模块生成（推理耗时不确定），否则 `disease_records.timestamp` 记录的是 MCU 打包时间而非实际推理时间。

- **修改建议**:
  在 AI 推理输出 JSON 中增加 `timestamp` 字段（ISO 8601 格式，由 AI 推理模块的 RTC 时钟提供）。

---

#### L-02: 上位机大屏"最新病虫害识别"标注为"事件驱动"但依赖轮询架构

- **严重程度**: 低
- **位置**: §2.7 大屏展示参数清单第 11 项
- **问题描述**:
  大屏展示中"最新病虫害识别"的刷新频率标注为"事件驱动"，但整个系统的客户端数据获取策略是 HTTP 轮询（§2.4 实时数据获取方式选择）。上位机无法真正实现事件驱动的数据更新。

- **修改建议**:
  将刷新频率改为"按轮询周期（10s），有更新时高亮显示"，或注明事件驱动通过 v1.1 的 WebSocket 升级实现。

---

#### L-03: `alarm_flag` 位掩码中 `soil_k` 无对应 bit 位但未在设计中说明

- **严重程度**: 低
- **位置**: §2.1 alarm_flag 位掩码表；`DATA_INVENTORY.md` §2.7
- **问题描述**:
  - `DATA_INVENTORY.md` §2.7 明确注明 `soil_k` 报警位"已定义未使用"。
  - 设计文档 §2.1 的 alarm_flag 表仅定义了 8 个 bit（0x01-0x80），没有任何与 `soil_k` 相关的位。
  - 设计中未解释为何 `soil_k` 不参与报警判断，也未说明预留扩展位的情况。

- **修改建议**:
  在 alarm_flag 表下方增加注释："`soil_k` 因缺乏公认的土壤钾素缺乏临界值标准（其值受土壤类型、作物品种影响较大），不纳入板端自动报警，其趋势分析在服务端防治建议引擎中处理。" 同时在位掩码定义中标注 0x0100-0x8000 为预留位。

---

#### L-04: 语音播报内容未在模块设计中定义

- **严重程度**: 低
- **位置**: §2.1 嵌入式端职责（"本地报警联动"）；`system_specification.md` §5.1
- **问题描述**:
  规格说明书 §5.1 给出了具体的语音播报样例（"检测到小麦锈病，请及时喷施农药"），但模块设计文档中语音模块（su-03T）仅出现在 GPIO 引脚表中，未定义各报警条件下的语音播报内容表，也未说明语音文件/文本的存储和触发逻辑。

- **修改建议**:
  在 §2.1 中增加"语音播报内容表"，按报警类型/AI 识别结果列出对应的语音播报文本（或语音文件索引号）。注明语音文件预存储在 su-03T 模块的 Flash 中，MCU 通过 UART0 发送播放指令和索引号。

---

#### L-05: `control_logs` 查询接口响应缺少 `command_id` 字段

- **严重程度**: 低
- **位置**: §4.5.2 成功响应 JSON
- **问题描述**:
  与 C-01 相关。`GET /api/v1/command/logs` 的成功响应示例中，每条记录包含 `id`、`device_id`、`timestamp`、`command` 等字段，但**不包含 `command_id`**。在 `control_logs` 表增加 `command_id` 字段后，该接口的响应也应同步包含此字段，以便客户端追踪命令的完整生命周期。

- **修改建议**:
  在 §4.5.2 的响应 JSON 的 records 元素中增加 `"command_id": "cmd_20260630_101530_001"` 字段。

---

#### L-06: `docker-compose.yml` 中 KingbaseES 的 healthcheck 命令可能不兼容

- **严重程度**: 低
- **位置**: §5.2 docker-compose.yml
- **问题描述**:
  KingbaseES 的命令行客户端工具名称为 `ksql`，但不同版本的 KingbaseES 可能使用不同的命令名（如早期版本使用 `isql` 或要求通过完整路径调用）。healthcheck 中的 `test: ["CMD", "ksql", "-U", "farmeye", "-c", "SELECT 1"]` 假设容器中 `ksql` 在 PATH 中且接受与 PostgreSQL `psql` 相同的参数格式。这需要在实际部署中验证。

- **修改建议**:
  （a）确认 `kingbase/kb_v8:V008R006C008B0020` 镜像中 `ksql` 的确切路径和参数格式；（b）备选方案：使用 `pg_isready` 兼容工具（若 KingbaseES 提供）或 TCP 端口检测（`test: ["CMD-SHELL", "nc -z localhost 5432"]`）。

---

#### L-07: 分页参数 `page_size` 上限为 100 但未说明超出时的行为

- **严重程度**: 低
- **位置**: §4.1 通用约定表，"分页参数"行
- **问题描述**:
  分页参数定义为"默认 `page_size=20`，最大 100"，但未说明当客户端请求 `page_size=200` 时的 API 行为——是静默截断为 100、返回 1001（参数校验失败）错误码、还是忽略上限？

- **修改建议**:
  明确超出上限时的行为：建议返回错误码 1001，`message` 中注明 `"page_size 最大值为 100"`。

---

#### L-08: 仓库顶层结构中 `server/images/` 目录未在结构中体现

- **严重程度**: 低
- **位置**: §5.1 仓库顶层结构
- **问题描述**:
  §4.7.3 说明图片存储在宿主机 `./images/`（相对于 `docker-compose.yml`，即 `server/images/`），但 §5.1 的 `server/` 目录结构中没有列出 `images/` 目录（即使它是运行时通过 bind mount 创建的，也应在 `.gitkeep` 中预留）。

- **修改建议**:
  在 `server/` 目录下增加 `images/.gitkeep`，并更新 §5.1 结构图。

---

#### L-09: 数据保留策略中 `sensor_daily_aggregation` 表结构未定义

- **严重程度**: 低
- **位置**: §2.5 数据保留与清理策略表
- **问题描述**:
  `sensor_snapshot` 表的保留策略为"30 天前数据按天聚合后仅保留聚合记录"，但聚合目标表 `sensor_daily_aggregation` 的结构"将在详细设计阶段定义"。当前设计中缺乏哪怕概要的聚合表字段定义，使得定时任务 `data_retention.py` 的实现缺乏输入。

- **修改建议**:
  在 §2.5 中增加 `sensor_daily_aggregation` 的概要 DDL（至少包含：`device_id`、`date`、`avg_temperature`、`min_temperature`、`max_temperature`、`avg_humidity`、`min_humidity`、`max_humidity`、`alarm_count`、`record_count`），详细字段可在后续阶段完善。

---

#### L-10: 病虫害热力图在单设备场景中缺少空间坐标数据

- **严重程度**: 低
- **位置**: §4.4.3
- **问题描述**:
  `/api/v1/disease/heatmap` 说明中提到"单设备场景中，热力图展示该设备覆盖区域内**不同位置**的病虫害检测密度与严重度"，但：
  - `disease_records` 表中无位置/坐标字段
  - AI 推理模块的输出中无"检测到的目标在图像中的位置"信息
  - 单设备单摄像头场景下，无法区分"设备覆盖区域内的不同位置"

- **修改建议**:
  （a）在文档中明确热力图的"位置"粒度：单设备场景下基于时间轴展示（时间热力图），多设备场景下基于设备部署坐标展示（空间热力图）；（b）若需要真正的空间热力图，须在 `disease_records` 中增加位置字段，并在 AI 推理输出中包含目标在图像中的边界框坐标。

---

#### L-11: 上位机图表技术选型理由中声称 PyQtGraph ">60fps" 与 10s 刷新频率不匹配

- **严重程度**: 低
- **位置**: §2.7 图表库选择理由
- **问题描述**:
  选择 PyQtGraph 的理由之一是"专为实时数据场景设计，刷新率高（>60fps），适合 10s 更新的传感器曲线"。10s 更新一次的数据显然不需要 >60fps 的渲染能力（60fps 意味着每秒 60 帧，而数据每 10 秒才变化一次）。此理由的技术说服力不足。

- **修改建议**:
  调整为更准确的理由描述，如："PyQtGraph 在数据点累积较多（如历史趋势数万点）时仍能保持流畅渲染，且与 PyQt6/PySide6 原生集成无需额外 Web 引擎依赖。"

---

#### L-12: `GET /api/v1/advisory` 缺少时间窗口参数

- **严重程度**: 低
- **位置**: §4.6.1
- **问题描述**:
  `/api/v1/advisory` 仅接受 `device_id` 参数，默认窗口为最近 1 小时（`ADVISORY_WINDOW_MINUTES=60`）。但客户端可能希望查看特定时间点的防治建议历史，或扩大窗口以获取更全面的分析。当前接口无法指定 `start`/`end` 或 `window_minutes` 参数。

- **修改建议**:
  增加可选查询参数 `start` 和 `end`（ISO 8601），允许客户端指定自定义时间窗口。同时增加 `window_minutes` 参数覆盖默认值（范围限制 10-1440）。

---

#### L-13: 工程结构中鸿蒙 App 缺少测试目录

- **严重程度**: 低
- **位置**: §5.1 `harmony-app/` 目录结构
- **问题描述**:
  `firmware/` 和 `server/` 均有 `tests/` 目录，但 `harmony-app/` 和 `host-computer/` 没有测试目录。虽然嵌入式与后端测试优先级更高，但客户端测试策略完全缺失。

- **修改建议**:
  在 `harmony-app/` 中增加测试配置说明（鸿蒙 `ohosTest` 模块），在 `host-computer/` 中增加 `tests/` 目录。可在文档中标注"客户端测试在 Phase 5 中实施"但不应完全省略。

---

#### L-14: HC-SR04 超声波传感器在规格说明书中未被提及

- **严重程度**: 低
- **位置**: `system_specification.md` §3 硬件架构表；本设计文档 §2.1 传感器组
- **问题描述**:
  规格说明书 §3 的硬件架构表中列出了温湿度、土壤 NPK、光照、CO2 传感器，以及语音模块、蜂鸣器、LED、继电器，但**未列出 HC-SR04 超声波传感器**。然而该传感器出现在模块设计的 GPIO 引脚表和数据上报字段中。这是两个文档间的轻微不一致。

- **修改建议**:
  更新规格说明书 §3 硬件架构表，增加 HC-SR04 超声波测距模块（注明用途：测量植株高度或水位监测）。

---

## 三、改进建议汇总

### 3.1 阻塞性问题（必须在详细设计前修复）

| 编号 | 问题 | 优先级 |
|------|------|--------|
| C-01 | `control_logs` 表增加 `command_id` 字段 | P0 |
| C-02 | API 增加认证机制（至少 API Key） | P0 |
| C-03 | 补充或移除对 `system_architecture_relationship.md` 的引用 | P0 |
| H-01 | 与规格说明书在数据存储位置上达成一致 | P1 |
| H-04 | `/sensor/latest` 多设备响应格式修正 | P1 |
| H-05 | 湿度与光照报警阈值修正 | P1 |

### 3.2 数据库 Schema 需变更项

| 变更 | 影响范围 |
|------|---------|
| `control_logs` 增加 `command_id VARCHAR(64)` + 索引 | §2.5 表3, §4.2.3, §4.5.2 |
| 新建 `devices` 表 | §2.5, §4.3.3 |
| 新建 `images` 表 | §2.5, §4.7 |
| 新建 `sensor_daily_aggregation` 表（概要 DDL） | §2.5 |
| `disease_records` 增加 `linkage_risk_level` / `linkage_detail` 字段 | §2.4, §2.5 表2 |
| `disease_records` 增加索引：`(crop_type, disease_type)` 和 `(severity_code)` | §2.5 表2 |

### 3.3 API 端点需增加/变更项

| 变更 | 类型 |
|------|------|
| `GET /api/v1/health` — 健康检查 | 新增 |
| `POST /api/v1/device/register` — 设备注册 | 新增 |
| `PUT /api/v1/device/{device_id}` — 设备信息更新 | 新增 |
| `GET /api/v1/export/sensor` — 数据导出（CSV/Excel） | 新增 |
| `GET /api/v1/sensor/latest` — 响应格式从单对象改为 records 数组 | 变更 |
| `GET /api/v1/sensor/history` — 响应 records 元素增加 `device_id` | 变更 |
| `GET /api/v1/advisory` — 增加 `start`/`end`/`window_minutes` 参数 | 变更 |
| `GET /api/v1/command/logs` — 响应 records 元素增加 `command_id` | 变更 |

### 3.4 文档间协同修订项

| 项 | 涉及文档 |
|----|---------|
| 数据存储位置矛盾 | `system_specification.md` §2.3 与本设计文档 §6.1 |
| HC-SR04 传感器纳入硬件清单 | `system_specification.md` §3 |
| 湿度/光照报警阈值修正 | `DATA_INVENTORY.md` §2.2, §2.3 |
| `sensor_snapshot` 表名统一 | 本设计文档 §6.6，以及 `system_architecture_relationship.md`（若创建） |
| 语音播报内容定义 | 本设计文档 §2.1 |

### 3.5 结构性与可维护性建议

1. **建立跨文档术语表**：`device_id`、`service_id`、`command_id`、`request_id` 等标识符在多处出现，建议在 `docs/glossary.md` 中统一定义和交叉引用。
2. **制定 API 版本策略文档**：当前 §4.1 简述了 URL 路径版本化策略，建议单独抽取为 `docs/api_versioning.md`，包含废弃时间线、迁移指南模板等。
3. **补充部署运维文档**：当前 `docker-compose.yml` 仅覆盖生产环境，建议补充开发环境 Compose 文件（含 hot-reload）和数据库备份/恢复策略说明。
4. **增加安全设计章节**：将认证、传输加密（MQTT TLS + HTTP TLS）、密钥管理等安全相关设计统一收纳至独立章节。

---

DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202606302338_system_module_design\b_v1_review_v1.md
