# 农眼卫士 — 系统模块设计

## 文档版本

| 版本 | 日期 | 说明 |
|------|------|------|
| v1 | 2026-06-30 | 初版，首轮执行产出 |
| v2 | 2026-06-30 | 第2轮修订，修复30项问题（严重4/高6/中6/低14） |
| v3 | 2026-06-30 | 第3轮修订，修复5项问题（中2/低3） |

---

## 1. 系统总体设计

### 1.1 系统定位

农眼卫士 (FarmEye Guard v1.0) 是基于物联网环境监测与边缘端 AI 图像识别技术，实现小麦与茶叶病虫害智能识别、环境联动监测与防治决策的软硬件一体化系统。系统采用 **"端-云-台"三层架构**，覆盖嵌入式感知、边缘智能、云端服务与多端交互四层能力。

> **架构术语等价说明**：本设计文档使用的架构命名与参考文档对应关系如下：
> - "端" = 边缘智能与感知层（`system_architecture_relationship.md` §1 Edge）= 设备层（本文 §1.3）
> - "云" = 华为云物联网平台 + 境外公网 VPS Docker 环境（`system_architecture_relationship.md` §1 HW_Cloud + VPS）
> - "台" = 多端交互与决策层（`system_architecture_relationship.md` §1 Clients）= 表现层（本文 §1.3）
> - "sensor_snapshot"（本文 §2.5 表1）= `system_architecture_relationship.md` 中所述的 `sensor_data` 表（见 §6.6 命名对照说明）

### 1.2 部署拓扑总览

```
┌─────────────────────────────────────────────────────────────────────┐
│                          客户端/表现层                                │
│  ┌──────────────────────┐          ┌──────────────────────┐         │
│  │  鸿蒙移动应用         │          │  Python 上位机        │         │
│  │  (ArkTS/ArkUI)       │          │  (PyQt/PySide)       │         │
│  └──────────┬───────────┘          └──────────┬───────────┘         │
│             │          HTTP REST API          │                      │
└─────────────┼─────────────────────────────────┼──────────────────────┘
              │                                 │
┌─────────────┼─────────────────────────────────┼──────────────────────┐
│             │     境外公网 VPS (Docker 容器化)  │                      │
│             ▼                                 ▼                      │
│  ┌──────────────────────────────────────────────────────┐           │
│  │              Python API 后台 (FastAPI)                 │           │
│  │  - IoTDA Webhook 接收端                               │           │
│  │  - REST API 服务端                                    │           │
│  │  - 业务逻辑与决策引擎                                  │           │
│  │  - 命令下发中转                                       │           │
│  └──────────┬───────────────────────────────┬───────────┘           │
│             │ SQL (psycopg2/SQLAlchemy)      │ HTTP API              │
│             ▼                               │                       │
│  ┌──────────────────────┐                   │                       │
│  │  金仓数据库           │                   │                       │
│  │  (KingbaseES)        │                   │                       │
│  └──────────────────────┘                   │                       │
│                                             │                       │
└─────────────────────────────────────────────┼───────────────────────┘
                                              │
┌─────────────────────────────────────────────┼───────────────────────┐
│                   华为云物联网平台            ▼                       │
│  ┌──────────────────────────────────────────────────────┐           │
│  │           设备接入平台 (IoTDA)                          │           │
│  │  - MQTT Broker & 设备管理                              │           │
│  │  - 数据流转规则引擎 (HTTP Webhook)                       │           │
│  │  - 命令下发 API                                        │           │
│  └──────────────────────────┬───────────────────────────┘           │
│                             │ MQTT (TLS/明文 1883)                   │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────────┐
│                   边缘智能与感知层                                    │
│                             ▼                                        │
│  ┌──────────────────────────────────────────────────────┐           │
│  │         嵌入式 MCU 主控 (WS63 Hi3863 + LiteOS)          │           │
│  │                                                        │           │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐    │           │
│  │  │ 传感器组  │  │ AI 模型  │  │  执行机构         │    │           │
│  │  │ DHT11    │  │ CNN 推理 │  │  继电器/LED/蜂鸣  │    │           │
│  │  │ LDR      │  │ 病虫害分类│  │  语音模块         │    │           │
│  │  │ MH-Z19C  │  │ 严重度分级│  │  OLED 显示屏      │    │           │
│  │  │ HC-SR04  │  │          │  │                  │    │           │
│  │  └──────────┘  └──────────┘  └──────────────────┘    │           │
│  └──────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.3 三层架构定义

| 层级 | 部署位置 | 核心组件 | 通信协议 |
|------|---------|---------|---------|
| **表现层** | 农户手机 / 现场 PC | 鸿蒙 App (ArkUI)、Python 上位机 (PyQt) | HTTP REST |
| **服务层** | 境外公网 VPS (Docker) | Python API (FastAPI)、KingbaseES 数据库 | HTTP / SQL |
| **设备层** | 农田/茶园现场 + 华为云 | 嵌入式 MCU、AI 推理模块、IoTDA | MQTT / HTTP Webhook |

---

## 2. 模块职责与边界

### 2.1 嵌入式端 (Embedded MCU) — WS63 Hi3863 + LiteOS

**角色**：现场感知与控制的物理核心。

**职责**：
- 传感器数据采集：定时读取 DHT11、LDR、MH-Z19C、HC-SR04 等传感器，周期 5s 采集、10s 上报
- 边缘 AI 结果接收：通过板内 IPC 接收 AI 推理模块的识别结果（类别、置信度、严重级别）
- 数据打包上报：将传感器数据与 AI 识别结果按 IoTDA 规范格式封装为 MQTT 消息，以 QoS 1 上报
- 命令接收执行：保持 MQTT 长连接，接收云端下发的控制指令（LED、蜂鸣器、继电器、语音模块）
- 本地报警联动：根据传感器阈值或 AI 识别结果触发本地 GPIO 报警（LED 闪烁 + 蜂鸣 + 语音播报）

**硬件资源与引脚**：

| GPIO | 功能 | 外设 |
|------|------|------|
| GPIO_02 | 指示灯 | LED1 |
| GPIO_03 | 指示灯 | LED2 |
| GPIO_04 | 单总线传感器 | DHT11 温湿度 |
| GPIO_05 | ADC CH5 | LDR 光照传感器 |
| GPIO_06 | 数字输出 | HC-SR04 TRIG |
| GPIO_07 | UART1 RX | MH-Z19C CO2 |
| GPIO_08 | UART1 TX | MH-Z19C CO2 |
| GPIO_09 | 数字输入 | HC-SR04 ECHO |
| GPIO_10 | 继电器 | 喷淋/氮肥 |
| GPIO_11 | 数字输出 | 蜂鸣器 |
| GPIO_13 | 继电器 | 灌溉/磷肥 |
| GPIO_15 | I2C SDA | OLED SSD1306 (I2C 地址 `0x3C`) |
| GPIO_16 | I2C SCL | OLED SSD1306 |
| GPIO_17 | UART0 TX | 语音模块 su-03T |
| GPIO_18 | UART0 RX | 语音模块 su-03T |

**上报数据字段**（每 10s 一条，QoS 1）：

| 字段 | 类型 | 单位 | 来源 | 说明 |
|------|------|------|------|------|
| `temperature` | float | ℃ | DHT11 | 环境温度 |
| `humidity` | float | % | DHT11 | 环境湿度 |
| `light` | int (0-100) | % | LDR ADC | 光照百分比 |
| `co2` | int | ppm | MH-Z19C | CO2 浓度 |
| `soil_n` | float | mg/kg | 推导（公式见下方） | 土壤氮素 |
| `soil_p` | float | mg/kg | 推导（公式见下方） | 土壤磷素 |
| `soil_k` | float | mg/kg | 推导（公式见下方） | 土壤钾素 |
| `distance` | int | cm | HC-SR04 | 超声波测距；`-1` 表示超时/无目标，服务端应忽略或标记为无效 |
| `rssi` | int | dBm | WiFi 协议栈 | WiFi 信号强度 |
| `ip_addr` | string | — | lwIP DHCP | 设备 IP 地址 |
| `mac_addr` | string | — | eFuse | 设备 MAC 地址 |
| `alarm_flag` | int (bitmask) | — | 板端计算 | 报警状态位掩码（位定义见下表） |

**土壤 NPK 推导公式**（因实际硬件未配备 NPK 传感器，采用推导方案；后续可接入 RS485 NPK 传感器替换）：

```
soil_n = 45.0 + temperature * 0.2
soil_p = 18.0 + humidity * 0.1
soil_k = 50.0 + light * 0.02
```

**alarm_flag 位掩码定义**（引用自 `DATA_INVENTORY.md` §2.12）：

| Bit | 宏名 | 含义 | 触发条件 | 板端动作 |
|-----|------|------|---------|---------|
| 0x01 | `ALARM_TEMP_HIGH` | 高温 | `temperature > 38.0℃` | LED + 蜂鸣 + 语音 |
| 0x02 | `ALARM_TEMP_LOW` | 低温 | `temperature < -10.0℃` | LED + 蜂鸣 + 语音 |
| 0x04 | `ALARM_HUMI_HIGH` | 高湿 | `humidity > 90.0%` | LED + 蜂鸣 + 语音 |
| 0x08 | `ALARM_HUMI_LOW` | 低湿 | `humidity < 15.0%` | LED + 蜂鸣 + 语音 |
| 0x10 | `ALARM_LIGHT_LOW` | 低光照 | `light < 100` | LED + 蜂鸣 + 语音 |
| 0x20 | `ALARM_CO2_HIGH` | 高 CO2 | `co2 > 2000 ppm` | LED + 蜂鸣 + 语音 |
| 0x40 | `ALARM_N_LOW` | 低氮 | `soil_n < 30.0` | LED + 蜂鸣 + 喷淋 ON |
| 0x80 | `ALARM_P_LOW` | 低磷 | `soil_p < 10.0` | LED + 蜂鸣 + 灌溉 ON |

---

### 2.2 AI 模型识别 (AI Edge Inference)

**角色**：边缘端实时病虫害视觉感知。

**职责**：
- 接收摄像头实时图像帧输入
- 运行 CNN 模型进行推理，识别作物类别与病虫害类型
- 输出识别结果：病害/害虫类别、置信度、严重度分级
- 将推理结果传递至嵌入式 MCU 主控（板内通信，具体方式依硬件平台而定——串口、共享内存或 SDK API）

**识别目标清单**：

| 类别 | 目标 | 病害/害虫类型 |
|------|------|--------------|
| 小麦病害 | 锈病 (Rust) | 条锈病、叶锈病 |
| 小麦病害 | 白粉病 (Powdery Mildew) | 白粉病 |
| 茶叶病害 | 茶炭疽病 (Anthracnose) | 茶炭疽病 |
| 茶叶害虫 | 茶小绿叶蝉 (Leafhopper) | 茶小绿叶蝉 |
| 扩展害虫 | 蚜虫、红蜘蛛 | 常见农业害虫 |

**严重度分级标准**（3 级，与规格书 §4.2 一致）：

| 级别 | severity_code | 英文标识 | 含义 | 建议动作 |
|------|:---:|---------|------|---------|
| 1 | 1 | Mild | 轻度感染 | 物理防治 / 局部预防 |
| 2 | 2 | Moderate | 中度感染 | 针对性药剂喷洒，加强监测 |
| 3 | 3 | Severe | 重度爆发 | 紧急处置，生成全面防治方案 |

**输出数据结构**（传递给 MCU）：

```json
{
  "detection": {
    "crop_type": "wheat",
    "disease_type": "rust",
    "confidence": 0.92,
    "severity": "Moderate",
    "severity_code": 2
  }
}
```

---

### 2.3 华为云设备接入平台 (IoTDA)

**角色**：设备连接管理、MQTT 消息代理与数据流转中枢。

**职责**：
- 设备注册与认证管理（device_id: `farmeye_guard_ws63`）
- MQTT Broker：接收设备属性上报，下发控制命令
- 数据流转规则引擎：配置 HTTP Webhook 规则，将设备上报数据实时转发至 Python API
- 命令下发网关：提供 HTTP API 供 Python API 后台调用，向指定设备下发控制指令

**MQTT 连接参数**：

| 参数 | 值 |
|------|-----|
| Broker 地址 | `5b0d2d88ef.st1.iotda-device.cn-north-4.myhuaweicloud.com` |
| 端口 | 1883 (MQTT 明文) |
| Device ID | `farmeye_guard_ws63` |
| Username | `farmeye_guard_ws63` |
| Keep-alive | 120s |

**MQTT Topic 约定**：

| 方向 | Topic | QoS | 用途 |
|------|-------|-----|------|
| 设备 → 云 | `$oc/devices/{device_id}/sys/properties/report` | 1 | 属性上报 |
| 云 → 设备 | `$oc/devices/{device_id}/sys/commands/#` | 0/1 | 命令下发 |
| 设备 → 云 | `$oc/devices/{device_id}/sys/commands/response/request_id={request_id}` | 0 | 命令应答 |

**命令应答 payload 格式**（引用自 `DATA_INVENTORY.md` §3.3）：

```json
{
  "result_code": 0,
  "response_name": "farmeye_guard",
  "paras": { "result": "success" }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `result_code` | int | 0=成功，非0=失败 |
| `response_name` | string | 应答者标识 |
| `paras` | object | 附加参数（如 `{"result": "success"}` / `{"result": "fail", "reason": "..."}`） |

---

### 2.4 Python API 后台 (FastAPI) — VPS 核心服务

**角色**：系统的逻辑中枢。承接所有业务计算的编排、数据持久化、API 服务暴露和命令下发中转。

**部署环境**：
- 位置：境外公网 VPS
- 运行方式：Docker 容器（通过 docker-compose 与 KingbaseES 共同编排）
- 对外端口：8000（映射至宿主机，允许华为云 IoTDA Webhook 及公网客户端访问）
- 数据库端口 5432 仅限 Docker 内网互通，不对外暴露

**职责**：
1. **IoTDA 数据接收端点**：接收华为云 IoTDA 规则引擎 HTTP Webhook 推送的设备数据
2. **数据持久化**：将传感器快照、病虫害记录、控制日志写入金仓数据库
3. **REST API 服务**：向鸿蒙 App 和 Python 上位机暴露数据查询与控制接口
4. **决策引擎**：基于阈值规则与 AI 识别结果生成自动控制决策
5. **命令下发**：调用华为云 IoTDA 的 HTTP API，向嵌入式端下发设备控制命令

**告警阈值定义**（引用自 `DATA_INVENTORY.md` §2.1–§2.7）：

| 传感器 | 字段 | 阈值条件 | 触发位 | 说明 |
|--------|------|---------|--------|------|
| DHT11 | `temperature` | `> 38.0℃` | 0x01 | 高温告警 |
| DHT11 | `temperature` | `< -10.0℃` | 0x02 | 低温告警 |
| DHT11 | `humidity` | `> 90.0%` | 0x04 | 高湿告警 |
| DHT11 | `humidity` | `< 15.0%` | 0x08 | 低湿告警 |
| LDR | `light` | `< 100` | 0x10 | 低光照告警 |
| MH-Z19C | `co2` | `> 2000 ppm` | 0x20 | 高 CO2 告警 |
| 推导 | `soil_n` | `< 30.0` | 0x40 | 低氮告警 |
| 推导 | `soil_p` | `< 10.0` | 0x80 | 低磷告警 |

**决策规则矩阵**（覆盖病虫害类型 × 严重度 × 关键环境条件）：

| # | 病虫害 | severity_code | 触发环境条件 | 自动动作 | 防治建议 |
|---|--------|:---:|------------|---------|---------|
| 1 | rust (锈病) | 1 | — | 无自动 | 加强监测，检查叶片 |
| 2 | rust (锈病) | 2 | `humidity > 85%` 或 `15℃ ≤ temperature ≤ 25℃` | 无自动 | 48h 内喷施三唑酮 |
| 3 | rust (锈病) | 3 | 任意 | `spray ON` | 立即喷施杀菌剂，隔离病区 |
| 4 | powdery_mildew (白粉病) | 1 | — | 无自动 | 加强通风，降低湿度 |
| 5 | powdery_mildew (白粉病) | 2 | `50% ≤ humidity ≤ 80%` | 无自动 | 喷施嘧菌酯 |
| 6 | powdery_mildew (白粉病) | 3 | 任意 | `spray ON` | 立即喷施杀菌剂 |
| 7 | anthracnose (茶炭疽病) | 1 | — | 无自动 | 检查茶园湿度 |
| 8 | anthracnose (茶炭疽病) | 2 | `humidity > 80%` 或 `20℃ ≤ temperature ≤ 30℃` | 无自动 | 喷施苯醚甲环唑 |
| 9 | anthracnose (茶炭疽病) | 3 | 任意 | `spray ON` | 立即喷施杀菌剂 |
| 10 | leafhopper (茶小绿叶蝉) | 1 | — | 无自动 | 监控虫口密度 |
| 11 | leafhopper (茶小绿叶蝉) | 2 | `20℃ ≤ temperature ≤ 30℃` | 无自动 | 喷施吡虫啉 |
| 12 | leafhopper (茶小绿叶蝉) | 3 | 任意 | `spray ON` | 立即喷施杀虫剂 |

**环境-病虫害联动监测逻辑**：

当收到 AI 识别结果时，决策引擎执行以下联动分析：
1. 从 `sensor_snapshot` 表拉取最近 1 小时内的环境数据（温度、湿度、光照、CO2）
2. 计算环境因子与当前病虫害的关联度（如湿度偏高 + 锈病检测 → 高风险扩散）
3. 将联动分析结果写入防治建议的 `env_disease_linkage` 字段（见 §4.6.1）
4. 若满足决策规则矩阵中的自动动作条件，触发命令下发

**设备在线/离线判定机制**：

- **判定规则**：超过 30 秒无传感器数据上报即标记为离线
- **Python API 侧实现**：定时任务（每 30s）扫描 `sensor_snapshot` 表中各设备的 `MAX(timestamp)`，若当前时间 - 最后上报时间 > 30s，则将 `device_list` 中的 `online` 字段置为 `false`
- **状态存储**：设备在线状态维护在内存缓存（Redis 或进程内 dict）中，随 `/api/v1/device/list` 返回
- **离线处理**：向离线设备下发命令时，API 直接返回错误码 `1003`（设备离线），不调用 IoTDA

**实时数据获取方式选择**：

客户端实时数据获取推荐 **HTTP 轮询**（间隔 10s），理由：
- 鸿蒙 `@ohos.net.http` 原生支持，无需额外依赖
- 上位机 PyQt 可轻松实现 QTimer + requests 轮询
- 数据本身 10s 更新一次，轮询间隔与数据产生频率匹配
- WebSocket / SSE 作为后续优化方向（需额外建立长连接管理），初版暂不采用

---

### 2.5 金仓数据库 (KingbaseES)

**角色**：国产化关系型数据存储中心。

**部署环境**：
- 位置：与 Python API 同 VPS
- 运行方式：Docker 容器（`kingbase/kb_v8`），通过 docker-compose 与 Python 后端网络互通
- 端口：5432（仅 Docker 内网，不对外暴露）

**数据表规划**：

#### 表 1：`sensor_snapshot` — 环境数据快照

> **表名说明**：本表名为 `sensor_snapshot`，与架构关系文档（`system_architecture_relationship.md` §2.5）中所述的 `sensor_data` 为同一概念。选择 `sensor_snapshot` 的原因是该名称更准确地反映"每次上报为一次环境快照"的语义，区别于持续采集的时间序列流。两文档协同修改以保持一致。

```sql
CREATE TABLE sensor_snapshot (
    id          BIGSERIAL PRIMARY KEY,
    device_id   VARCHAR(64) NOT NULL,
    mac_addr    VARCHAR(17),
    timestamp   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    temperature DECIMAL(4,1),
    humidity    DECIMAL(4,1),
    light       INT,
    co2         INT,
    soil_n      DECIMAL(5,1),
    soil_p      DECIMAL(5,1),
    soil_k      DECIMAL(5,1),
    distance    INT,
    rssi        SMALLINT,
    ip_addr     VARCHAR(16),
    alarm_flag  INT,

    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sensor_device_time ON sensor_snapshot (device_id, timestamp);
```

#### 表 2：`disease_records` — 病虫害识别记录

```sql
CREATE TABLE disease_records (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    crop_type       VARCHAR(32) NOT NULL,
    disease_type    VARCHAR(64) NOT NULL,
    confidence      DECIMAL(4,3),
    severity        VARCHAR(16) NOT NULL,
    severity_code   SMALLINT NOT NULL,  -- 1=Mild, 2=Moderate, 3=Severe

    image_path      VARCHAR(512),
    action_taken    VARCHAR(128),

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_disease_device_time ON disease_records (device_id, timestamp);
```

#### 表 3：`control_logs` — 设备控制日志

```sql
CREATE TABLE control_logs (
    id              BIGSERIAL PRIMARY KEY,
    device_id       VARCHAR(64) NOT NULL,
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    command         VARCHAR(64) NOT NULL,
    source          VARCHAR(32) NOT NULL,   -- 'auto' / 'manual_app' / 'manual_pc'
    operator        VARCHAR(64),
    result_code     INT,
    result_msg      VARCHAR(255),

    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_control_device_time ON control_logs (device_id, timestamp);
```

**数据保留与清理策略**：

| 表 | 策略 | 说明 |
|----|------|------|
| `sensor_snapshot` | 保留最近 30 天明细；30 天前数据按天聚合（取均值/最大/最小）后仅保留聚合记录 | 定时任务每日凌晨执行；聚合表结构（如 `sensor_daily_aggregation`）将在详细设计阶段定义 |
| `disease_records` | 永久保留（数据量小） | — |
| `control_logs` | 保留最近 90 天 | 定时任务每日凌晨执行 |

---

### 2.6 鸿蒙应用 (HarmonyOS App)

**角色**：移动端监控与远程控制终端。

**职责**：
- 环境参数实时展示卡片（温湿度、光照、CO2、土壤 NPK、信号强度）
- 病虫害预警消息推送（接收重度检测通知）
- 历史数据趋势图表（折线图/柱状图）
- 远程设备控制：手动开启/关闭喷淋、灌溉、蜂鸣器
- 病虫害记录浏览（按时间、类别筛选）
- 防治建议查看

**技术栈**：ArkTS + ArkUI（声明式 UI），网络请求使用 `@ohos.net.http`

**消息推送技术方案**：

采取 **HTTP 轮询 + WebSocket 渐进升级** 策略：

| 阶段 | 方案 | 说明 |
|------|------|------|
| 初版 (v1.0) | HTTP 短轮询 | 鸿蒙端每 10s 调用 `GET /api/v1/advisory` 检查是否有新的重度告警记录；实现简单，`@ohos.net.http` 原生支持 |
| 升级 (v1.1) | WebSocket 长连接 | 鸿蒙端通过 `@ohos.net.webSocket` 建立 WebSocket 连接，服务端主动推送重度告警事件，降低轮询开销 |
| 备选 | 华为 Push Kit | 若需要后台/离线推送能力（App 不在前台时），可集成华为 Push Kit，但需华为开发者账号和额外配置 |

选择理由：初版优先保证功能可用，HTTP 轮询不依赖额外 SDK 和华为账号，与现有技术栈一致。WebSocket 作为 v1.1 优化项。

---

### 2.7 Python 上位机 (Host Computer)

**角色**：现场 PC 端集中监控与操作面板。

**职责**：
- 多设备监控仪表盘（同时查看多台嵌入式设备状态）
- 实时数据大屏（环境参数、AI 识别结果、报警状态）
- 设备远程控制面板
- 历史数据导出（CSV/Excel）
- 防治决策辅助界面

**技术栈**：PyQt6 / PySide6，图表库选用 **PyQtGraph**。

**图表库选择理由**（PyQtGraph）：
- 与 PyQt6/PySide6 原生集成，无需嵌入 Web 组件或额外渲染进程
- 专为实时数据场景设计，刷新率高（>60fps），适合 10s 更新的传感器曲线
- 纯 Python 实现，部署简单，不引入 Matplotlib 的重量级依赖链
- Matplotlib 仅在导出静态图表（CSV/Excel 附带图像）时作为备选

**大屏展示环境参数清单**：

| # | 参数 | 显示形式 | 刷新频率 |
|---|------|---------|---------|
| 1 | 温度 (temperature) | 数值卡片 + 实时曲线 | 10s |
| 2 | 湿度 (humidity) | 数值卡片 + 实时曲线 | 10s |
| 3 | 光照 (light) | 数值卡片 + 进度条 | 10s |
| 4 | CO2 (co2) | 数值卡片 + 实时曲线 | 10s |
| 5 | 土壤氮 (soil_n) | 数值卡片 | 10s |
| 6 | 土壤磷 (soil_p) | 数值卡片 | 10s |
| 7 | 土壤钾 (soil_k) | 数值卡片 | 10s |
| 8 | 超声波距离 (distance) | 数值卡片 | 10s |
| 9 | WiFi 信号 (rssi) | 信号强度图标 | 10s |
| 10 | 报警状态 (alarm_flag) | 状态指示灯（绿/黄/红） | 10s |
| 11 | 最新病虫害识别 | 信息卡片（类型+严重度） | 事件驱动 |
| 12 | 设备在线状态 | 在线/离线标识 | 30s |

---

## 3. 模块间数据交互

### 3.1 交互总览矩阵

以下矩阵列出 A 到 B 的通信方式、协议和数据载荷方向：

| 发送方 (A) | 接收方 (B) | 协议 | 触发方式 | 数据内容 |
|------------|-----------|------|---------|---------|
| 嵌入式 MCU | IoTDA | MQTT | 定时 10s | 传感器快照 + alarm_flag |
| 嵌入式 MCU | IoTDA | MQTT | 事件触发 | AI 识别结果 (crop, disease, confidence, severity) |
| IoTDA | Python API | HTTP POST (Webhook) | 实时转发 | 同上 JSON 载荷 |
| Python API | KingbaseES | SQL/TCP | 同步 | INSERT/UPDATE/SELECT |
| Python API | IoTDA | HTTP POST (IoTDA API) | 事件触发 | 设备命令下发请求 |
| IoTDA | 嵌入式 MCU | MQTT | 实时推送 | 控制命令 ("led ON" 等) |
| 鸿蒙 App | Python API | HTTP REST | 用户操作/轮询 | GET 查询 / POST 控制 |
| Python 上位机 | Python API | HTTP REST | 用户操作/轮询 | GET 查询 / POST 控制 |

### 3.2 详细数据流说明

#### 流 A：传感器定时上报 → 持久化

```
嵌入式 MCU                               IoTDA                          Python API                      KingbaseES
    │                                       │                               │                               │
    │──MQTT PUB (10s)──────────────────────▶│                               │                               │
    │  topic: .../properties/report         │                               │                               │
    │  payload: sensor JSON                 │──HTTP POST (Webhook)─────────▶│                               │
    │                                       │  payload: 同 MQTT JSON        │                               │
    │                                       │                               │──INSERT INTO sensor_snapshot─▶│
    │                                       │                               │◀──────────── OK ───────────────│
    │                                       │◀─────── HTTP 200 ─────────────│                               │
```

#### 流 B：AI 识别上报 → 报警联动 → 自动控制

```
嵌入式 MCU (含AI推理)                    IoTDA                     Python API                    KingbaseES
    │                                       │                          │                              │
    │──MQTT PUB (事件触发)─────────────────▶│                          │                              │
    │  payload: {crop, disease,            │──HTTP POST (Webhook)─────▶│                              │
    │            confidence, severity}      │                          │                              │
    │                                       │                          │──1. INSERT disease_records───▶│
    │                                       │                          │                              │
    │                                       │                          │──2. 决策引擎评估：              │
    │                                       │                          │    a. 查决策规则矩阵匹配        │
    │                                       │                          │    b. 拉取最近1h环境数据        │
    │                                       │                          │    c. 环境-病害联动分析          │
    │                                       │                          │    (如 severity_code>=3        │
    │                                       │                          │     则自动触发喷淋)            │
    │                                       │                          │                              │
    │                                       │◀──HTTP POST 命令下发──────│                              │
    │                                       │   IoTDA CMD API           │                              │
    │◀──MQTT CMD ("spray ON")──────────────│                          │                              │
    │                                       │                          │                              │
    │──MQTT PUB (CMD Response)────────────▶│                          │                              │
    │                                       │──HTTP POST (Webhook)─────▶│                              │
    │                                       │   rule_cmd_response_       │──3. UPDATE control_logs──────▶│
    │                                       │   forward → /iotda/cmd/    │   (更新 result_code & msg)    │
    │                                       │   response                 │                              │
```

#### 流 C：用户手动控制

```
鸿蒙 App / 上位机                        Python API                       IoTDA                  嵌入式 MCU
    │                                       │                               │                        │
    │──POST /api/v1/command────────────────▶│                               │                        │
    │  payload: {device_id, command}        │                               │                        │
    │                                       │──INSERT control_logs──────────│                        │
    │                                       │  (source='manual_app')        │                        │
    │                                       │                               │                        │
    │                                       │──POST IoTDA 命令下发 API──────▶│                        │
    │                                       │                               │──MQTT CMD────────────▶│
    │                                       │                               │◀──CMD Response────────│
    │                                       │◀──IoTDA 响应──────────────────│                        │
    │◀──HTTP 200 {result}──────────────────│                               │                        │
```

#### 流 D：多端数据查询

```
鸿蒙 App / 上位机                        Python API                      KingbaseES
    │                                       │                               │
    │──GET /api/v1/sensor/latest───────────▶│                               │
    │                                       │──SELECT * FROM                │
    │                                       │   sensor_snapshot             │
    │                                       │   ORDER BY timestamp DESC     │
    │                                       │   LIMIT 1────────────────────▶│
    │                                       │◀──── row data ────────────────│
    │◀──HTTP 200 {JSON}────────────────────│                               │
```

---

## 4. Python API 接口规范 (FastAPI)

本节详细定义部署在 VPS 上的 Python API 后台的完整 REST 接口规范。所有接口基础路径为 `/api/v1`。

### 4.1 通用约定

| 项目 | 约定 |
|------|------|
| 基础 URL | `http://<VPS_IP>:8000/api/v1` |
| 请求 Content-Type | `application/json` |
| 响应 Content-Type | `application/json` |
| 认证方式 | 初版可暂用无认证（VPS IP 白名单 + 内网），后续可扩展 API Key |
| 时间戳格式 | ISO 8601 / `YYYY-MM-DDTHH:mm:ss`（API 响应使用无时区格式；IoTDA Webhook 推送的 `event_time` 使用 UTC 时区后缀 `Z`，接收端需兼容处理） |
| 分页参数 | `?page=1&page_size=20`，默认 `page_size=20`，最大 100 |

**API 版本管理策略**：
- 路径前缀版本化：`/api/v1/`、`/api/v2/`，主版本号变更时新建路由模块
- 旧版本保持向后兼容至少一个大版本周期（即 v1 在 v2 发布后继续维护至 v2 稳定）
- 破坏性变更（字段删除/重命名）仅在新主版本号中引入

**通用响应结构**：

```json
{
  "code": 0,
  "message": "success",
  "data": { ... }
}
```

| code | 含义 |
|------|------|
| 0 | 成功 |
| 1001 | 参数校验失败 |
| 1002 | 资源不存在 |
| 1003 | 设备离线/不可达 |
| 1004 | 认证失败 |
| 1005 | 请求频率限制 |
| 2001 | 数据库错误 |
| 3001 | IoTDA 调用失败 |
| 5000 | 服务器内部错误 |

### 4.2 IoTDA Webhook 接收端点

**三 Webhook 路由规则配置方案**：

在华为云 IoTDA 控制台的"数据流转规则"中配置三条规则，将传感器数据、AI 识别结果和命令应答分别路由至不同端点：

| 规则名称 | 触发条件 | 目标 URL | 用途 |
|---------|---------|---------|------|
| `rule_sensor_forward` | `service_id = "farmeye_env"` | `POST /api/v1/iotda/properties/report` | 传感器环境数据 |
| `rule_ai_forward` | `service_id = "farmeye_ai"` | `POST /api/v1/iotda/ai/report` | AI 识别结果 |
| `rule_cmd_response_forward` | topic 匹配 `.../sys/commands/response/...` | `POST /api/v1/iotda/cmd/response` | 命令应答回传 |

配置要点：
- 在 IoTDA 规则引擎中通过 SQL 条件 `WHERE service_id = 'farmeye_env'` 和 `WHERE service_id = 'farmeye_ai'` 区分前两条规则
- `rule_cmd_response_forward` 通过 MQTT topic 模式匹配 `$oc/devices/{device_id}/sys/commands/response/request_id={request_id}` 触发
- 三条规则可指向同一 VPS 的不同路径
- 规则转发失败时，IoTDA 侧有重试机制（默认重试 3 次，间隔 30s）

#### 4.2.1 接收设备属性上报

```
POST /api/v1/iotda/properties/report
```

**说明**：由华为云 IoTDA 数据流转规则 `rule_sensor_forward` 触发，将设备上报的属性数据推送给此端点。此接口不对客户端暴露，仅 IoTDA 调用。

**请求体**（IoTDA 转发格式）：

```json
{
  "resource": "device.property",
  "event": "report",
  "event_time": "2026-06-30T10:15:30Z",
  "notify_data": {
    "header": {
      "device_id": "farmeye_guard_ws63",
      "product_id": "farmeye_guard",
      "app_id": "farmeye_guard_app"
    },
    "body": {
      "services": [{
        "service_id": "farmeye_env",
        "properties": {
          "temperature": 25.5,
          "humidity": 60.2,
          "light": 85,
          "co2": 450,
          "soil_n": 50.1,
          "soil_p": 24.0,
          "soil_k": 51.7,
          "distance": 150,
          "rssi": -45,
          "ip_addr": "192.168.1.100",
          "mac_addr": "A1:B2:C3:D4:E5:F6",
          "alarm_flag": 0
        }
      }]
    }
  }
}
```

**处理逻辑**：
1. 解析 `notify_data.body.services[0].properties` 中的各字段
2. 写入 `sensor_snapshot` 表；若数据库写入失败，返回 HTTP 500（触发 IoTDA 侧重试机制），并记录错误日志
3. 检查 `alarm_flag` 是否非零，若触发则评估是否需要自动下发控制命令
4. 更新设备在线状态（最后上报时间）
5. 返回 200 OK

**响应**：

```json
{
  "code": 0,
  "message": "received"
}
```

#### 4.2.2 接收 AI 识别结果上报

```
POST /api/v1/iotda/ai/report
```

**说明**：由 IoTDA 数据流转规则 `rule_ai_forward` 触发，通过 `service_id = "farmeye_ai"` 与属性上报区分路由。

**请求体**：

```json
{
  "resource": "device.message",
  "event": "report",
  "event_time": "2026-06-30T10:15:30Z",
  "notify_data": {
    "header": {
      "device_id": "farmeye_guard_ws63"
    },
    "body": {
      "services": [{
        "service_id": "farmeye_ai",
        "properties": {
          "crop_type": "wheat",
          "disease_type": "rust",
          "confidence": 0.92,
          "severity": "Moderate",
          "severity_code": 2
        }
      }]
    }
  }
}
```

**处理逻辑**：
1. 写入 `disease_records` 表；若数据库写入失败，返回 HTTP 500（触发 IoTDA 侧重试机制），并记录错误日志
2. 若 `severity_code >= 3` (Severe)，触发自动防治决策逻辑（见决策规则矩阵 §2.4）
3. 执行环境-病害联动分析（拉取最近 1h 环境数据，计算关联）
4. 返回 200 OK

**响应**：

```json
{
  "code": 0,
  "message": "received"
}
```

#### 4.2.3 接收命令应答上报

```
POST /api/v1/iotda/cmd/response
```

**说明**：由 IoTDA 数据流转规则 `rule_cmd_response_forward` 触发，将设备执行命令后的应答结果推送给此端点。用于更新 `control_logs` 表中的 `result_code` 和 `result_msg` 字段。此接口不对客户端暴露，仅 IoTDA 调用。

**请求体**（IoTDA 转发格式）：

```json
{
  "resource": "device.command",
  "event": "response",
  "event_time": "2026-06-30T10:15:35Z",
  "notify_data": {
    "header": {
      "device_id": "farmeye_guard_ws63",
      "request_id": "cmd_20260630_101530_001"
    },
    "body": {
      "result_code": 0,
      "response_name": "farmeye_guard",
      "paras": { "result": "success" }
    }
  }
}
```

**处理逻辑**：
1. 解析 `notify_data.header.request_id` 获取命令 ID
2. 根据 `request_id` 在 `control_logs` 表中查找对应的命令记录（`command_id = request_id`）
3. 更新该记录：`result_code` ← `notify_data.body.result_code`，`result_msg` ← `notify_data.body.paras.result`（或 `paras.reason`）
4. 若数据库写入失败，返回 HTTP 500（触发 IoTDA 侧重试机制），并记录错误日志
5. 返回 200 OK

**响应**：

```json
{
  "code": 0,
  "message": "received"
}
```

> **注意**：`control_logs` 表的 `result_code` 字段（§2.5 表3）需要新增 `command_id` 字段（VARCHAR(64)），以便通过 IoTDA 命令 ID 匹配命令应答。该 DDL 变更将在详细设计阶段同步。

---

### 4.3 传感器数据查询接口

#### 4.3.1 获取最新传感器数据

```
GET /api/v1/sensor/latest?device_id=farmeye_guard_ws63
```

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `device_id` | string | 否 | 设备 ID，不传则返回所有设备各自最新一条 |

**成功响应**：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "device_id": "farmeye_guard_ws63",
    "timestamp": "2026-06-30T10:15:30",
    "temperature": 25.5,
    "humidity": 60.2,
    "light": 85,
    "co2": 450,
    "soil_n": 50.1,
    "soil_p": 24.0,
    "soil_k": 51.7,
    "distance": 150,
    "rssi": -45,
    "ip_addr": "192.168.1.100",
    "mac_addr": "A1:B2:C3:D4:E5:F6",
    "alarm_flag": 0
  }
}
```

#### 4.3.2 查询历史传感器数据

```
GET /api/v1/sensor/history?device_id=farmeye_guard_ws63&start=2026-06-30T00:00:00&end=2026-06-30T23:59:59&page=1&page_size=20
```

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `device_id` | string | 是 | 设备 ID |
| `start` | datetime | 否 | 起始时间 (ISO 8601) |
| `end` | datetime | 否 | 结束时间 (ISO 8601) |
| `page` | int | 否 | 页码，默认 1 |
| `page_size` | int | 否 | 每页条数，默认 20，最大 100 |

**成功响应**（字段集与 `/sensor/latest` 统一）：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 1440,
    "page": 1,
    "page_size": 20,
    "records": [
      {
        "timestamp": "2026-06-30T10:15:30",
        "temperature": 25.5,
        "humidity": 60.2,
        "light": 85,
        "co2": 450,
        "soil_n": 50.1,
        "soil_p": 24.0,
        "soil_k": 51.7,
        "distance": 150,
        "rssi": -45,
        "alarm_flag": 0
      }
    ]
  }
}
```

#### 4.3.3 获取设备列表

```
GET /api/v1/device/list
```

**成功响应**：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "devices": [
      {
        "device_id": "farmeye_guard_ws63",
        "mac_addr": "A1:B2:C3:D4:E5:F6",
        "ip_addr": "192.168.1.100",
        "online": true,
        "last_seen": "2026-06-30T10:15:30"
      }
    ]
  }
}
```

---

### 4.4 病虫害记录查询接口

#### 4.4.1 查询病虫害记录列表

```
GET /api/v1/disease/records?device_id=farmeye_guard_ws63&crop_type=wheat&severity=Moderate&start=2026-06-01&end=2026-06-30&page=1&page_size=20
```

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `device_id` | string | 否 | 设备 ID |
| `crop_type` | string | 否 | 作物类型：`wheat` / `tea` |
| `disease_type` | string | 否 | 病虫害类型：`rust` / `powdery_mildew` / `anthracnose` / `leafhopper` |
| `severity` | string | 否 | 严重级别：`Mild` / `Moderate` / `Severe` |
| `start` | date | 否 | 起始日期 |
| `end` | date | 否 | 结束日期 |
| `page` | int | 否 | 页码 |
| `page_size` | int | 否 | 每页条数 |

**成功响应**：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 15,
    "page": 1,
    "page_size": 20,
    "records": [
      {
        "id": 1001,
        "device_id": "farmeye_guard_ws63",
        "timestamp": "2026-06-30T10:15:30",
        "crop_type": "wheat",
        "disease_type": "rust",
        "confidence": 0.92,
        "severity": "Moderate",
        "severity_code": 2,
        "image_path": "/images/2026/06/30/rust_1001.jpg",
        "action_taken": "auto_spray"
      }
    ]
  }
}
```

#### 4.4.2 获取病虫害统计

```
GET /api/v1/disease/stats?device_id=farmeye_guard_ws63&start=2026-06-01&end=2026-06-30
```

**成功响应**：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total_detections": 15,
    "by_crop": {
      "wheat": 10,
      "tea": 5
    },
    "by_severity": {
      "Mild": 5,
      "Moderate": 5,
      "Severe": 5
    },
    "by_disease": {
      "rust": 6,
      "powdery_mildew": 4,
      "anthracnose": 3,
      "leafhopper": 2
    }
  }
}
```

#### 4.4.3 病虫害热力图数据

```
GET /api/v1/disease/heatmap?device_id=farmeye_guard_ws63&start=2026-06-01&end=2026-06-30
```

**说明**：返回指定时间范围内的病虫害空间分布数据，用于上位机/鸿蒙端渲染热力图。单设备场景中，热力图展示该设备覆盖区域内不同位置的病虫害检测密度与严重度；多设备场景中，按设备坐标聚合展示。

**查询参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `device_id` | string | 否 | 设备 ID，不传则返回所有设备的数据 |
| `start` | date | 否 | 起始日期 |
| `end` | date | 否 | 结束日期 |

**成功响应**：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "heatmap_points": [
      {
        "device_id": "farmeye_guard_ws63",
        "timestamp": "2026-06-30T10:15:30",
        "crop_type": "wheat",
        "disease_type": "rust",
        "severity": "Moderate",
        "severity_code": 2
      },
      {
        "device_id": "farmeye_guard_ws63",
        "timestamp": "2026-06-30T11:20:00",
        "crop_type": "wheat",
        "disease_type": "rust",
        "severity": "Severe",
        "severity_code": 3
      }
    ],
    "summary": {
      "total_points": 25,
      "severity_distribution": {
        "Mild": 10,
        "Moderate": 10,
        "Severe": 5
      }
    }
  }
}
```

---

### 4.5 设备控制接口

#### 4.5.1 下发设备控制命令

```
POST /api/v1/command
```

**说明**：鸿蒙 App 或 Python 上位机通过此接口向指定嵌入式设备下发控制命令。Python API 收到请求后，调用华为云 IoTDA 的命令下发 API，将命令转发至设备。

**请求体**：

```json
{
  "device_id": "farmeye_guard_ws63",
  "command": "spray ON",
  "source": "manual_app",
  "operator": "user_zhangsan"
}
```

**字段说明**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `device_id` | string | 是 | 目标设备 ID |
| `command` | string | 是 | 控制命令，支持值见下表 |
| `source` | string | 是 | 命令来源：`auto` / `manual_app` / `manual_pc` |
| `operator` | string | 否 | 操作者标识（手动操作时填写） |

**支持的命令列表**：

| command | 动作说明 |
|---------|---------|
| `led ON` | 打开 LED 指示灯 |
| `led OFF` | 关闭 LED 指示灯 |
| `beep ON` | 打开蜂鸣器 |
| `beep OFF` | 关闭蜂鸣器 |
| `spray ON` | 开启喷淋继电器 |
| `spray OFF` | 关闭喷淋继电器 |
| `irrig ON` | 开启灌溉继电器 |
| `irrig OFF` | 关闭灌溉继电器 |

**成功响应**：

```json
{
  "code": 0,
  "message": "command sent",
  "data": {
    "command_id": "cmd_20260630_101530_001",
    "device_id": "farmeye_guard_ws63",
    "command": "spray ON",
    "status": "sent"
  }
}
```

**错误响应**（设备离线）：

```json
{
  "code": 1003,
  "message": "device offline or unreachable",
  "data": null
}
```

#### 4.5.2 查询控制日志

```
GET /api/v1/command/logs?device_id=farmeye_guard_ws63&page=1&page_size=20
```

**成功响应**：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "total": 50,
    "page": 1,
    "page_size": 20,
    "records": [
      {
        "id": 2001,
        "device_id": "farmeye_guard_ws63",
        "timestamp": "2026-06-30T10:15:30",
        "command": "spray ON",
        "source": "auto",
        "operator": null,
        "result_code": 0,
        "result_msg": "success"
      }
    ]
  }
}
```

---

### 4.6 防治建议接口

#### 4.6.1 获取防治建议

```
GET /api/v1/advisory?device_id=farmeye_guard_ws63
```

**说明**：根据最近一次 AI 识别结果和当前环境数据，返回防治建议。默认窗口为最近 1 小时（可通过配置项 `ADVISORY_WINDOW_MINUTES` 调整，默认值 60）。

> **1 小时窗口选择依据**：传感器上报周期为 10s，病虫害识别为事件触发型。1 小时窗口在"及时性"与"避免频繁告警"之间取得平衡——既覆盖近期的检测结果，又避免因过于久远的记录（如 24 小时前）产生过时建议。该值可通过环境变量 `ADVISORY_WINDOW_MINUTES` 配置。

**成功响应**：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "latest_detection": {
      "crop_type": "wheat",
      "disease_type": "rust",
      "severity": "Moderate",
      "severity_code": 2,
      "confidence": 0.92,
      "timestamp": "2026-06-30T10:15:30"
    },
    "current_env": {
      "temperature": 25.5,
      "humidity": 60.2,
      "light": 85,
      "co2": 450
    },
    "env_disease_linkage": {
      "risk_level": "medium",
      "matched_conditions": [
        "humidity favors rust spread (>85% typical threshold; current 60.2% is below but rising)",
        "temperature 25.5℃ within rust favorable range 15-25℃ (at upper bound)"
      ],
      "recommendation": "当前温湿度条件有利于锈病扩散，建议加强监测频率至5min/次"
    },
    "advisory": {
      "action": "spray_fungicide",
      "description": "检测到中度小麦锈病（severity_code=2），建议在48h内喷施三唑酮类杀菌剂。当前温湿度条件适宜锈病扩散，请加强监测频率。",
      "auto_action_triggered": false,
      "auto_action": null
    }
  }
}
```

---

### 4.7 图片接口

#### 4.7.1 上传病虫害图片

```
POST /api/v1/image/upload
```

**说明**：鸿蒙 App 或上位机上传病虫害现场图片，与识别记录关联。

**请求体**（multipart/form-data）：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `file` | file | 是 | 图片文件（支持 jpg/png，最大 10MB） |
| `disease_record_id` | int | 否 | 关联的病虫害记录 ID，传入则将图片路径写入该记录 |
| `device_id` | string | 否 | 设备 ID（用于路径组织） |

**成功响应**：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "image_id": "img_20260630_101530_001",
    "image_path": "/images/2026/06/30/img_20260630_101530_001.jpg",
    "file_size": 204800,
    "uploaded_at": "2026-06-30T10:15:30"
  }
}
```

#### 4.7.2 获取图片

```
GET /api/v1/image/{image_id}
```

**说明**：通过图片 ID 获取已上传的病虫害图片。

**路径参数**：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `image_id` | string | 是 | 图片唯一标识（上传时返回的 `image_id`） |

**成功响应**：返回图片二进制流（Content-Type: `image/jpeg` 或 `image/png`）。

**错误响应**（图片不存在）：

```json
{
  "code": 1002,
  "message": "image not found",
  "data": null
}
```

#### 4.7.3 图片存储策略

**存储位置**：图片文件存储在 VPS 宿主机的本地磁盘目录 `./images`，通过 Docker volume 绑定挂载映射至 API 容器内的 `/app/images` 路径。

**路径映射关系**：
- 宿主机路径：`./images/`（相对于 `docker-compose.yml` 所在目录，即 `server/images/`）
- 容器内路径：`/app/images/`
- API 返回的 `image_path`（如 `/images/2026/06/30/img_xxx.jpg`）为容器内相对路径，文件实际存储在宿主机 `./images/2026/06/30/img_xxx.jpg`

**目录组织**：图片按日期分目录存储，格式为 `YYYY/MM/DD/`，由 API 服务在写入时自动创建。

**持久化保证**：由于采用 Docker bind mount，图片数据独立于容器生命周期。容器重建或重启后，宿主机上的图片文件不会丢失，`GET /api/v1/image/{image_id}` 可持续正常访问。

---

### 4.8 接口清单汇总

| 序号 | 方法 | 路径 | 用途 | 调用方 |
|------|------|------|------|--------|
| 1 | POST | `/api/v1/iotda/properties/report` | 接收设备属性上报 | IoTDA (Webhook) |
| 2 | POST | `/api/v1/iotda/ai/report` | 接收 AI 识别结果上报 | IoTDA (Webhook) |
| 3 | POST | `/api/v1/iotda/cmd/response` | 接收命令应答上报 | IoTDA (Webhook) |
| 4 | GET | `/api/v1/sensor/latest` | 获取最新传感器数据 | 鸿蒙 App / 上位机 |
| 5 | GET | `/api/v1/sensor/history` | 查询历史传感器数据 | 鸿蒙 App / 上位机 |
| 6 | GET | `/api/v1/device/list` | 获取设备列表 | 鸿蒙 App / 上位机 |
| 7 | GET | `/api/v1/disease/records` | 查询病虫害记录 | 鸿蒙 App / 上位机 |
| 8 | GET | `/api/v1/disease/stats` | 病虫害统计数据 | 鸿蒙 App / 上位机 |
| 9 | GET | `/api/v1/disease/heatmap` | 病虫害热力图数据 | 鸿蒙 App / 上位机 |
| 10 | POST | `/api/v1/command` | 下发设备控制命令 | 鸿蒙 App / 上位机 |
| 11 | GET | `/api/v1/command/logs` | 查询控制日志 | 鸿蒙 App / 上位机 |
| 12 | GET | `/api/v1/advisory` | 获取防治建议 | 鸿蒙 App / 上位机 |
| 13 | POST | `/api/v1/image/upload` | 上传病虫害图片 | 鸿蒙 App / 上位机 |
| 14 | GET | `/api/v1/image/{image_id}` | 获取图片 | 鸿蒙 App / 上位机 |

---

## 5. 工程文件组织结构

### 5.1 仓库顶层结构

```
wheat-tea-iot/
├── README.md                          # 项目说明
├── LICENSE                            # 开源协议
├── .gitignore                         # Git 忽略规则
│
├── docs/                              # 项目文档
│   ├── system_specification.md        # 系统规格说明书
│   ├── system_architecture_relationship.md  # 系统架构关系说明
│   ├── DATA_INVENTORY.md              # 数据清单
│   └── api_specification.md           # API 接口规范（本文档导出）
│
├── firmware/                          # 嵌入式端固件代码 (WS63 Hi3863 + LiteOS)
│   ├── CMakeLists.txt                 # 构建配置
│   ├── src/
│   │   ├── main.c                     # 主入口
│   │   ├── sensor/                    # 传感器驱动模块
│   │   │   ├── dht11.c / .h           # DHT11 温湿度
│   │   │   ├── ldr.c / .h             # LDR 光照
│   │   │   ├── mhz19c.c / .h          # MH-Z19C CO2
│   │   │   ├── hcsr04.c / .h          # HC-SR04 超声波
│   │   │   └── sensor_manager.c / .h  # 传感器统一调度
│   │   ├── actuator/                  # 执行机构模块
│   │   │   ├── relay.c / .h           # 继电器控制
│   │   │   ├── beeper.c / .h          # 蜂鸣器
│   │   │   ├── led.c / .h             # LED 指示
│   │   │   └── voice.c / .h           # 语音模块
│   │   ├── comm/                      # 通信模块
│   │   │   ├── mqtt_client.c / .h     # MQTT 客户端（对接 IoTDA）
│   │   │   ├── wifi_manager.c / .h    # WiFi 连接管理
│   │   │   └── protocol.c / .h        # 数据打包/解包协议
│   │   ├── ai/                        # AI 接口模块
│   │   │   └── ai_interface.c / .h    # 与 AI 推理模块的本地通信接口
│   │   ├── alarm/                     # 报警逻辑
│   │   │   └── alarm_engine.c / .h    # 报警阈值判断与位掩码计算
│   │   └── util/                      # 通用工具
│   │       ├── ringbuffer.c / .h      # 环形缓冲区
│   │       └── timer.c / .h           # 软件定时器
│   ├── config/
│   │   └── board_config.h             # 引脚与硬件配置
│   └── tests/                         # 嵌入式端测试
│       ├── test_sensor.c              # 传感器驱动单元测试
│       ├── test_mqtt.c                # MQTT 通信测试
│       └── test_alarm.c               # 报警逻辑单元测试
│
├── ai-model/                          # AI 模型模块
│   ├── models/                        # 训练好的模型文件
│   │   ├── wheat_disease.onnx         # 小麦病害模型
│   │   └── tea_disease.onnx           # 茶叶病虫害模型
│   ├── inference/                     # 推理引擎
│   │   ├── infer.py                   # Python 推理脚本 (ONNX Runtime)
│   │   └── preprocess.py              # 图像预处理
│   ├── training/                      # 训练相关
│   │   ├── dataset/                   # 数据集
│   │   ├── train.py                   # 训练脚本
│   │   └── augment.py                 # 数据增强
│   └── requirements.txt               # Python 依赖
│
├── server/                            # VPS Python API 后台 (FastAPI)
│   ├── Dockerfile                     # Docker 镜像构建
│   ├── docker-compose.yml             # Docker Compose 编排（API + KingbaseES）
│   ├── requirements.txt               # Python 依赖
│   ├── alembic.ini                    # 数据库迁移配置
│   ├── alembic/                       # 迁移脚本
│   ├── app/
│   │   ├── main.py                    # FastAPI 应用入口
│   │   ├── config.py                  # 配置管理（环境变量/VPS 地址等）
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── router.py              # 路由汇总注册
│   │   │   ├── deps.py                # 依赖注入（数据库会话等）
│   │   │   └── v1/
│   │   │       ├── __init__.py
│   │   │       ├── iotda.py           # IoTDA Webhook 接收端点
│   │   │       ├── sensor.py          # 传感器数据查询接口
│   │   │       ├── disease.py         # 病虫害记录接口
│   │   │       ├── device.py          # 设备列表接口
│   │   │       ├── command.py         # 设备控制接口
│   │   │       ├── advisory.py        # 防治建议接口
│   │   │       └── image.py           # 图片上传/获取接口
│   │   ├── models/                    # SQLAlchemy 数据模型
│   │   │   ├── __init__.py
│   │   │   ├── sensor.py              # SensorSnapshot 模型
│   │   │   ├── disease.py             # DiseaseRecord 模型
│   │   │   └── control.py             # ControlLog 模型
│   │   ├── schemas/                   # Pydantic 请求/响应 Schema
│   │   │   ├── __init__.py
│   │   │   ├── sensor.py
│   │   │   ├── disease.py
│   │   │   ├── command.py
│   │   │   └── common.py              # 通用响应模型
│   │   ├── services/                  # 业务逻辑层
│   │   │   ├── __init__.py
│   │   │   ├── sensor_service.py      # 传感器数据处理
│   │   │   ├── disease_service.py     # 病虫害记录处理
│   │   │   ├── command_service.py     # 命令下发服务
│   │   │   ├── advisory_service.py    # 防治建议引擎
│   │   │   ├── iotda_client.py        # 华为云 IoTDA API 客户端封装
│   │   │   └── data_retention.py      # 数据保留策略定时任务
│   │   ├── core/                      # 核心配置
│   │   │   ├── __init__.py
│   │   │   └── logging_config.py      # 日志配置模块
│   │   └── db/
│   │       ├── __init__.py
│   │       ├── session.py             # 数据库会话管理
│   │       └── base.py                # ORM Base
│   └── tests/                         # 测试
│       ├── __init__.py
│       ├── test_sensor.py
│       ├── test_disease.py
│       └── test_command.py
│
├── harmony-app/                       # 鸿蒙 App (ArkTS/ArkUI)
│   ├── entry/
│   │   └── src/
│   │       └── main/
│   │           └── ets/
│   │               ├── entryability/
│   │               ├── pages/         # 页面
│   │               │   ├── IndexPage.ets
│   │               │   ├── DashboardPage.ets
│   │               │   ├── DiseaseRecordsPage.ets
│   │               │   ├── ControlPage.ets
│   │               │   └── AdvisoryPage.ets
│   │               ├── common/        # 公共模块
│   │               │   ├── api.ets    # HTTP 请求封装
│   │               │   └── models.ets # 数据模型定义
│   │               └── components/    # 可复用组件
│   │                   ├── SensorCard.ets
│   │                   └── ChartView.ets
│   └── module.json5
│
├── host-computer/                     # Python 上位机 (PySide6)
│   ├── main.py                    # 应用入口
│   ├── requirements.txt
│   ├── ui/
│   │   ├── main_window.py         # 主窗口
│   │   ├── dashboard.py           # 仪表盘面板
│   │   ├── control_panel.py       # 设备控制面板
│   │   ├── history_view.py        # 历史数据视图
│   │   └── resources/            # UI 资源
│   ├── services/
│   │   ├── api_client.py          # 后端 API 客户端封装
│   │   └── data_poller.py         # 定时轮询服务
│   └── models/
│       └── data_models.py         # 本地数据模型
│
└── deploy/                            # 部署相关
    ├── docker-compose.prod.yml        # 生产环境 compose
    └── nginx/
        └── farmeye.conf               # Nginx 反向代理配置（可选）
```

### 5.2 VPS 部署结构 (docker-compose)

```yaml
# server/docker-compose.yml
version: "3.9"
services:
  api:
    build: .
    container_name: farmeye-api
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql+psycopg2://farmeye:farmeye_pwd@db:5432/farmeye_db
      - IOTDA_ENDPOINT=https://iotda.cn-north-4.myhuaweicloud.com
      - IOTDA_PROJECT_ID=your_project_id
      - ADVISORY_WINDOW_MINUTES=60
      - DATA_RETENTION_SENSOR_DAYS=30
      - DATA_RETENTION_CONTROL_DAYS=90
      - IMAGE_STORAGE_PATH=/app/images
    volumes:
      - ./images:/app/images
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: kingbase/kb_v8:V008R006C008B0020
    container_name: farmeye-db
    ports:
      - "127.0.0.1:5432:5432"   # 仅本地回环，保护数据库安全
    environment:
      - DB_USER=farmeye
      - DB_PASSWORD=farmeye_pwd
      - DB_NAME=farmeye_db
    volumes:
      - db_data:/var/lib/kingbase/data
    healthcheck:
      test: ["CMD", "ksql", "-U", "farmeye", "-c", "SELECT 1"]
      interval: 10s
      retries: 5
    restart: unless-stopped

volumes:
  db_data:
```

---

## 6. 关键设计决策与说明

### 6.1 关于 Python API 部署在 VPS 的设计

选择在境外公网 VPS 上部署 Python API 后台，而非直接部署在华为云上，原因如下：
- VPS 上已有运行中的代理等服务，复用同一台机器降低成本
- Docker 容器化保证服务隔离，不影响宿主机现有配置
- 数据库端口仅 Docker 内网可访问，保障安全
- 境外 VPS 到华为云 IoTDA 的延迟通常 <300ms，满足非强实时场景需求

### 6.2 关于数据流转路径

采用"设备 → IoTDA → VPS API"的间接路径而非"设备 → VPS API"直连，原因：
- IoTDA 提供可靠的设备认证、连接管理、离线消息缓存能力
- MQTT 长连接统一由华为云托管，VPS 侧无需处理海量设备连接
- 即使 VPS 短暂不可用，数据仍在 IoTDA 侧缓存，恢复后补推

### 6.3 关于命令下发链路

命令下发采用"VPS API → IoTDA API → MQTT → 设备"的路径，即**由 Python API 主动调用华为云 IoTDA 的 HTTP API 下发命令**，而非直接通过 MQTT 向设备发消息。原因：
- 复用 IoTDA 的设备管理和命令追踪能力
- VPS 无需维护与设备的 MQTT 直连
- IoTDA 提供命令执行状态回调，便于追踪命令是否送达

### 6.4 关于 AI 模型部署位置

AI 推理模型部署在边缘端（嵌入式侧），与 MCU 通过板内通信。推理结果由 MCU 统一通过 MQTT 上报，而非独立上报通道。原因：
- 减少网络连接数和功耗
- 统一的数据格式便于 IoTDA 规则引擎处理
- 边缘推理保证实时性，无网络延迟

### 6.5 关于土壤 NPK 数据

当前土壤氮磷钾数据为**推导值**（通过温湿度、光照等参数公式换算），非真实 NPK 传感器读数。推导公式如下：

```
soil_n = 45.0 + temperature * 0.2
soil_p = 18.0 + humidity * 0.1
soil_k = 50.0 + light * 0.02
```

> **与规格书的矛盾说明**：系统规格说明（`system_specification.md` §3 硬件架构表）列出了"土壤氮磷钾传感器"，但实际硬件平台（WS63 Hi3863）的 GPIO 布局中未接入真实 NPK 传感器。当前采用推导方案作为课程项目的折中实现，公式参数参考 `DATA_INVENTORY.md` §2.5–§2.7。代码实现时，应支持后续通过 RS485 接口接入真实 NPK 传感器替换推导逻辑，接口设计上预留扩展字段。

### 6.6 关于 sensor_snapshot 表名

本设计文档使用 `sensor_snapshot` 作为环境数据表名。架构关系文档（`system_architecture_relationship.md` §2.5）中对应表名为 `sensor_data`。选择 `sensor_snapshot` 的理由是：该名称更准确地反映每次上报为一次完整环境快照（而非持续流式写入的单条数据），建议两文档协调统一。

### 6.7 关于嵌入式端测试策略

嵌入式端测试分两层：
- **单元测试**：在 `firmware/tests/` 目录下，对传感器驱动、MQTT 通信、报警逻辑等模块编写独立单元测试（基于 LiteOS 测试框架或裸机 mock）
- **集成测试**：在硬件开发板上进行端到端验证（传感器采集 → MQTT 上报 → IoTDA 接收），通过华为云 IoTDA 控制台观察数据到达情况

---

## 7. 下一步实施建议

1. **Phase 1 — 基础设施搭建**：VPS 上部署 docker-compose（API + KingbaseES），配置华为云 IoTDA 产品与设备
2. **Phase 2 — 嵌入式端开发**：传感器驱动 → MQTT 通信 → 命令执行，独立完成端到端验证
3. **Phase 3 — AI 模型训练与部署**：数据集准备 → CNN 训练 → ONNX 导出 → 边缘推理部署
4. **Phase 4 — API 后台开发**：IoTDA Webhook 接收 → 数据库 CRUD → REST API 暴露 → 决策引擎
5. **Phase 5 — 客户端开发**：鸿蒙 App + Python 上位机，对接 API 完成全链路联调

