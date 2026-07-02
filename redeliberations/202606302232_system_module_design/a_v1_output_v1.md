# 农眼卫士 — 系统模块设计

## 文档版本

| 版本 | 日期 | 说明 |
|------|------|------|
| v1 | 2026-06-30 | 初版，首轮执行产出 |

---

## 1. 系统总体设计

### 1.1 系统定位

农眼卫士 (FarmEye Guard v1.0) 是基于物联网环境监测与边缘端 AI 图像识别技术，实现小麦与茶叶病虫害智能识别、环境联动监测与防治决策的软硬件一体化系统。系统采用 **"端-云-台"三层架构**，覆盖嵌入式感知、边缘智能、云端服务与多端交互四层能力。

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
| GPIO_15 | I2C SDA | OLED SSD1306 |
| GPIO_16 | I2C SCL | OLED SSD1306 |
| GPIO_17 | UART0 TX | 语音模块 su-03T |
| GPIO_18 | UART0 RX | 语音模块 su-03T |

**上报数据字段**（每 10s 一条，QoS 1）：

| 字段 | 类型 | 来源 |
|------|------|------|
| `temperature` | float | DHT11 |
| `humidity` | float | DHT11 |
| `light` | int (0-100) | LDR ADC |
| `co2` | int (ppm) | MH-Z19C |
| `soil_n` | float | 推导/模拟 |
| `soil_p` | float | 推导/模拟 |
| `soil_k` | float | 推导/模拟 |
| `distance` | int (cm) | HC-SR04 |
| `rssi` | int (dBm) | WiFi 协议栈 |
| `ip_addr` | string | lwIP DHCP |
| `mac_addr` | string | eFuse |
| `alarm_flag` | int (bitmask) | 板端计算 |

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

**严重度分级标准**：

| 级别 | 英文标识 | 含义 | 建议动作 |
|------|---------|------|---------|
| 0 | Normal | 健康，未检出 | 常规监测 |
| 1 | Mild | 轻度感染 | 物理防治 / 局部预防 |
| 2 | Moderate | 中度感染 | 针对性药剂喷洒，加强监测 |
| 3 | Severe | 重度爆发 | 紧急处置，生成全面防治方案 |

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

---

### 2.5 金仓数据库 (KingbaseES)

**角色**：国产化关系型数据存储中心。

**部署环境**：
- 位置：与 Python API 同 VPS
- 运行方式：Docker 容器（`kingbase/kb_v8`），通过 docker-compose 与 Python 后端网络互通
- 端口：5432（仅 Docker 内网，不对外暴露）

**数据表规划**：

#### 表 1：`sensor_snapshot` — 环境数据快照

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
    severity_code   SMALLINT NOT NULL,

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

---

### 2.7 Python 上位机 (PC Upper Computer)

**角色**：现场 PC 端集中监控与操作面板。

**职责**：
- 多设备监控仪表盘（同时查看多台嵌入式设备状态）
- 实时数据大屏（环境参数、AI 识别结果、报警状态）
- 设备远程控制面板
- 历史数据导出（CSV/Excel）
- 防治决策辅助界面

**技术栈**：PyQt6 / PySide6，图表使用 PyQtGraph 或 Matplotlib 嵌入

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
    │                                       │                          │──2. 决策引擎评估阈值            │
    │                                       │                          │    (如 Severity=Severe         │
    │                                       │                          │     则自动触发喷淋)            │
    │                                       │                          │                              │
    │                                       │◀──HTTP POST 命令下发──────│                              │
    │                                       │   IoTDA CMD API           │                              │
    │◀──MQTT CMD ("spray ON")──────────────│                          │                              │
    │                                       │                          │                              │
    │──MQTT PUB (CMD Response)────────────▶│                          │                              │
    │                                       │──HTTP POST (Webhook)─────▶│                              │
    │                                       │   or 状态同步              │──3. INSERT control_logs──────▶│
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
| 时间戳格式 | ISO 8601 / `YYYY-MM-DDTHH:mm:ss` |
| 分页参数 | `?page=1&page_size=20`，默认 `page_size=20`，最大 100 |

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
| 2001 | 数据库错误 |
| 5000 | 服务器内部错误 |

### 4.2 IoTDA Webhook 接收端点

#### 4.2.1 接收设备属性上报

```
POST /api/v1/iotda/properties/report
```

**说明**：由华为云 IoTDA 数据流转规则触发，将设备上报的属性数据推送给此端点。此接口不对客户端暴露，仅 IoTDA 调用。

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
2. 写入 `sensor_snapshot` 表
3. 检查 `alarm_flag` 是否非零，若触发则评估是否需要自动下发控制命令
4. 返回 200 OK

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

**说明**：由 IoTDA 转发嵌入式端上报的 AI 病虫害识别结果。可通过自定义 service_id（如 `farmeye_ai`）与属性上报区分，或通过 payload 中是否含 `disease_type` 字段路由。

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
1. 写入 `disease_records` 表
2. 若 `severity_code >= 3` (Severe)，触发自动防治决策逻辑
3. 返回 200 OK

**响应**：

```json
{
  "code": 0,
  "message": "received"
}
```

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

**成功响应**：

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
        "soil_k": 51.7
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
| `severity` | string | 否 | 严重级别：`Normal` / `Mild` / `Moderate` / `Severe` |
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
      "Normal": 3,
      "Mild": 5,
      "Moderate": 5,
      "Severe": 2
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

**说明**：根据最近一次 AI 识别结果和当前环境数据，返回防治建议。若最近 1 小时内无识别记录则返回空建议。

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
      "confidence": 0.92,
      "timestamp": "2026-06-30T10:15:30"
    },
    "current_env": {
      "temperature": 25.5,
      "humidity": 60.2
    },
    "advisory": {
      "action": "spray_fungicide",
      "description": "检测到中度小麦锈病，建议在48h内喷施三唑酮类杀菌剂。当前温湿度条件适宜锈病扩散，请加强监测频率。",
      "auto_action_triggered": true,
      "auto_action": "spray ON"
    }
  }
}
```

---

### 4.7 接口清单汇总

| 序号 | 方法 | 路径 | 用途 | 调用方 |
|------|------|------|------|--------|
| 1 | POST | `/api/v1/iotda/properties/report` | 接收设备属性上报 | IoTDA (Webhook) |
| 2 | POST | `/api/v1/iotda/ai/report` | 接收 AI 识别结果上报 | IoTDA (Webhook) |
| 3 | GET | `/api/v1/sensor/latest` | 获取最新传感器数据 | 鸿蒙 App / 上位机 |
| 4 | GET | `/api/v1/sensor/history` | 查询历史传感器数据 | 鸿蒙 App / 上位机 |
| 5 | GET | `/api/v1/device/list` | 获取设备列表 | 鸿蒙 App / 上位机 |
| 6 | GET | `/api/v1/disease/records` | 查询病虫害记录 | 鸿蒙 App / 上位机 |
| 7 | GET | `/api/v1/disease/stats` | 病虫害统计数据 | 鸿蒙 App / 上位机 |
| 8 | POST | `/api/v1/command` | 下发设备控制命令 | 鸿蒙 App / 上位机 |
| 9 | GET | `/api/v1/command/logs` | 查询控制日志 | 鸿蒙 App / 上位机 |
| 10 | GET | `/api/v1/advisory` | 获取防治建议 | 鸿蒙 App / 上位机 |

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
│   └── config/
│       └── board_config.h             # 引脚与硬件配置
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
│   │   │       └── advisory.py        # 防治建议接口
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
│   │   │   └── iotda_client.py        # 华为云 IoTDA API 客户端封装
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
├── client/                            # 客户端应用
│   ├── harmony/                       # 鸿蒙 App (ArkTS/ArkUI)
│   │   ├── entry/
│   │   │   └── src/
│   │   │       └── main/
│   │   │           └── ets/
│   │   │               ├── entryability/
│   │   │               ├── pages/         # 页面
│   │   │               │   ├── IndexPage.ets
│   │   │               │   ├── DashboardPage.ets
│   │   │               │   ├── DiseaseRecordsPage.ets
│   │   │               │   ├── ControlPage.ets
│   │   │               │   └── AdvisoryPage.ets
│   │   │               ├── common/        # 公共模块
│   │   │               │   ├── api.ets    # HTTP 请求封装
│   │   │               │   └── models.ets # 数据模型定义
│   │   │               └── components/    # 可复用组件
│   │   │                   ├── SensorCard.ets
│   │   │                   └── ChartView.ets
│   │   └── module.json5
│   │
│   └── upper-computer/               # Python 上位机 (PySide6)
│       ├── main.py                    # 应用入口
│       ├── requirements.txt
│       ├── ui/
│       │   ├── main_window.py         # 主窗口
│       │   ├── dashboard.py           # 仪表盘面板
│       │   ├── control_panel.py       # 设备控制面板
│       │   ├── history_view.py        # 历史数据视图
│       │   └── resources/            # UI 资源
│       ├── services/
│       │   ├── api_client.py          # 后端 API 客户端封装
│       │   └── data_poller.py         # 定时轮询服务
│       └── models/
│           └── data_models.py         # 本地数据模型
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
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: kingbase/kb_v8:latest
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

当前土壤氮磷钾数据为**推导值**（通过温湿度、光照等参数公式换算），非真实 NPK 传感器读数。代码实现时，应支持后续通过 RS485 接口接入真实 NPK 传感器替换推导逻辑，接口设计上预留扩展字段。

---

## 7. 下一步实施建议

1. **Phase 1 — 基础设施搭建**：VPS 上部署 docker-compose（API + KingbaseES），配置华为云 IoTDA 产品与设备
2. **Phase 2 — 嵌入式端开发**：传感器驱动 → MQTT 通信 → 命令执行，独立完成端到端验证
3. **Phase 3 — AI 模型训练与部署**：数据集准备 → CNN 训练 → ONNX 导出 → 边缘推理部署
4. **Phase 4 — API 后台开发**：IoTDA Webhook 接收 → 数据库 CRUD → REST API 暴露 → 决策引擎
5. **Phase 5 — 客户端开发**：鸿蒙 App + Python 上位机，对接 API 完成全链路联调
