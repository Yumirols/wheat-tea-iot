# 农眼卫士 (FarmEye Guard v1.0) — 表现层客户端 REST API 接口文档

本接口文档面向**鸿蒙应用开发者 (ArkTS)**与 **Python 上位机开发者 (PySide6)**，定义了用于进行环境监测数据查询、病虫害记录查询、图像上传、防治建议拉取及设备控制下发的所有客户端 REST 接口。

---

## 一、 通用交互规范

### 1.1 基础 URL
*   **开发调试环境**：`http://<VPS_IP>:8000/api/v1`
*   **生产环境（Nginx 反向代理）**：`http://<VPS_IP>/api/v1`（使用标准 80 或 443 端口，无需加端口号）

### 1.2 请求与响应格式
*   **数据格式**：所有请求与响应的内容类型均为 `application/json`。
*   **通用响应结构**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {} // 具体的业务数据
    }
    ```

### 1.3 认证机制 (API Key)
客户端在发起任何 REST 请求时，必须在 HTTP 请求头中添加 `X-Api-Key` 字段。
*   **测试密钥**：`farmeye_prod_key_001`
*   **请求头示例**：
    ```http
    X-Api-Key: farmeye_prod_key_001
    ```
> **注意**：如果 VPS 后端的 `API_KEYS` 环境变量未配置或为空（本地开发调试模式），后端将自动跳过 API Key 校验。但在正式联调与表现层开发时，**建议一律携带此请求头**。

### 1.4 分页规范
对于返回列表的接口，均支持分页查询。参数形如 `?page=1&page_size=20`。
*   `page`: 当前页码，从 `1` 开始，默认值 `1`。
*   `page_size`: 每页条数，范围为 `1 - 100`，默认值 `20`。超过 `100` 时服务端会自动截断至 `100` 并正常响应。

---

## 二、 接口清单与详细规范

### 2.1 设备管理

#### 2.1.1 查询设备列表 / 设备信息
*   **请求方法**：`GET`
*   **接口路径**：`/device/list`
*   **Query 参数**：
    *   `device_id` (可选，String)：指定查询的设备 ID。若不传，则返回所有设备列表。
*   **响应示例 (成功)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": [
        {
          "id": 1,
          "device_id": "farmeye_guard_ws63",
          "device_name": "FarmEye Guard WS63 #1",
          "mac_addr": "A1:B2:C3:D4:E5:F6",
          "ip_addr": "192.168.1.100",
          "registered_at": "2026-07-03T06:00:00",
          "last_seen": "2026-07-03T06:28:50",
          "online": true,
          "created_at": "2026-07-03T06:00:00"
        }
      ]
    }
    ```

---

### 2.2 环境监测数据

#### 2.2.1 查询最新传感器快照
主要用于客户端首页的卡片和数值刷新。
*   **请求方法**：`GET`
*   **接口路径**：`/sensor/latest`
*   **Query 参数**：
    *   `device_id` (可选，String)：指定查询的设备 ID。
*   **逻辑说明**：
    *   **传 `device_id` 时**：直接返回该设备最新的一条环境数据快照对象（如果没有数据，`data` 字段返回 `null`）。
    *   **不传 `device_id` 时**：返回所有设备的最新快照列表（每个设备各占一条记录）。
*   **响应示例 (携带 `device_id` 成功)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {
        "id": 125,
        "device_id": "farmeye_guard_ws63",
        "mac_addr": "A1:B2:C3:D4:E5:F6",
        "timestamp": "2026-07-03T06:28:50",
        "temperature": 28.5,
        "humidity": 75.0,
        "light": 42000,
        "co2": 430,
        "soil_n": 14.2,
        "soil_p": 7.8,
        "soil_k": 16.3,
        "distance": 28,
        "rssi": -62,
        "ip_addr": "192.168.1.100",
        "alarm_flag": 0,
        "created_at": "2026-07-03T06:28:50"
      }
    }
    ```
    > **alarm_flag (报警位掩码) 速查**：
    > * `0x01` (高温) / `0x02` (低温) / `0x04` (高湿) / `0x08` (低湿)
    > * `0x10` (低光照) / `0x20` (高 CO2) / `0x40` (低氮) / `0x80` (低磷)

#### 2.2.2 查询历史传感器数据
主要用于绘制折线趋势图。
*   **请求方法**：`GET`
*   **接口路径**：`/sensor/history`
*   **Query 参数**：
    *   `device_id` (**必填**，String)：指定设备 ID。
    *   `start` (可选，DateTime String，如 `2026-07-03T00:00:00`)：起始时间。
    *   `end` (可选，DateTime String，如 `2026-07-03T23:59:59`)：结束时间。
    *   `page` (可选，Int)：当前页码，默认 1。
    *   `page_size` (可选，Int)：每页条数，默认 20。
*   **响应示例 (成功)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {
        "pagination": {
          "total": 1450,
          "page": 1,
          "page_size": 2
        },
        "records": [
          {
            "id": 125,
            "device_id": "farmeye_guard_ws63",
            "timestamp": "2026-07-03T06:28:50",
            "temperature": 28.5,
            "humidity": 75.0,
            "light": 42000,
            "co2": 430,
            "soil_n": 14.2,
            "soil_p": 7.8,
            "soil_k": 16.3,
            "distance": 28,
            "rssi": -62,
            "ip_addr": "192.168.1.100",
            "alarm_flag": 0
          },
          {
            "id": 124,
            "device_id": "farmeye_guard_ws63",
            "timestamp": "2026-07-03T06:28:40",
            "temperature": 28.4,
            "humidity": 75.1,
            "light": 41900,
            "co2": 428,
            "soil_n": 14.1,
            "soil_p": 7.8,
            "soil_k": 16.3,
            "distance": 28,
            "rssi": -63,
            "ip_addr": "192.168.1.100",
            "alarm_flag": 0
          }
        ]
      }
    }
    ```

#### 2.2.3 查询日聚合环境数据
用于中长期趋势大屏或报表分析。
*   **请求方法**：`GET`
*   **接口路径**：`/sensor/daily`
*   **Query 参数**：
    *   `device_id` (**必填**，String)：指定设备 ID。
    *   `start` (**必填**，Date String，如 `2026-06-01`)：起始日期。
    *   `end` (**必填**，Date String，如 `2026-06-30`)：结束日期。
    *   `page` / `page_size` (可选，分页)。
*   **响应示例 (成功)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {
        "pagination": { "total": 30, "page": 1, "page_size": 1 },
        "records": [
          {
            "id": 1,
            "device_id": "farmeye_guard_ws63",
            "agg_date": "2026-06-30",
            "avg_temperature": 27.2,
            "max_temperature": 32.1,
            "min_temperature": 22.0,
            "avg_humidity": 70.5,
            "max_humidity": 85.0,
            "min_humidity": 60.0,
            "avg_light": 35000.0,
            "max_light": 50000,
            "min_light": 1000,
            "avg_co2": 440.0,
            "max_co2": 520,
            "min_co2": 400,
            "record_count": 8640,
            "created_at": "2026-07-01T00:01:00"
          }
        ]
      }
    }
    ```

---

### 2.3 病虫害记录

#### 2.3.1 分页查询病虫害记录列表
*   **请求方法**：`GET`
*   **接口路径**：`/disease/list`
*   **Query 参数**：
    *   `device_id` (可选，String)：按设备 ID 筛选。
    *   `crop_type` (可选，String)：按作物类型筛选（如 `wheat` 小麦 / `tea` 茶叶）。
    *   `disease_type` (可选，String)：按病虫害类型筛选（如 `rust` 锈病 / `powdery_mildew` 白粉病 / `anthracnose` 炭疽病 / `leafhopper` 小绿叶蝉）。
    *   `severity` (可选，String)：严重程度（`Mild` 轻度 / `Moderate` 中度 / `Severe` 重度）。
    *   `start` / `end` (可选，DateTime String)：时间范围。
    *   `page` / `page_size` (可选，分页)。
*   **响应示例 (成功)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {
        "pagination": { "total": 1, "page": 1, "page_size": 20 },
        "records": [
          {
            "id": 5,
            "device_id": "farmeye_guard_ws63",
            "timestamp": "2026-07-03T06:15:00",
            "crop_type": "wheat",
            "disease_type": "rust",
            "max_conf": 0.925,
            "severity": "Moderate",
            "severity_code": 2,
            "object_number": 2,
            "all_object": [
              {
                "类别": "rust",
                "置信度": 0.925,
                "位置": [10.0, 20.0, 50.0, 60.0]
              },
              {
                "类别": "rust",
                "置信度": 0.85,
                "位置": [30.0, 40.0, 70.0, 80.0]
              }
            ],
            "linkage_risk_level": "medium",
            "linkage_detail": "当前环境湿度为 75.0%，温度在 15-25℃ 范围内，适宜锈病孢子萌发与高风险扩散，建议尽快人工巡检与药剂防护。",
            "image_path": "/images/2026/07/03/img_20260703_061500_021.jpg",
            "action_taken": "manual_inspect",
            "created_at": "2026-07-03T06:15:00"
          }
        ]
      }
    }
    ```

#### 2.3.2 获取病虫害多维度统计数据
用于上位机大屏图表或统计卡片展示。
*   **请求方法**：`GET`
*   **接口路径**：`/disease/stats`
*   **Query 参数**：
    *   `start` / `end` (可选，筛选时间段)。
*   **响应示例 (成功)**：
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
          "Moderate": 7,
          "Severe": 3
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

#### 2.3.3 获取病虫害热力图数据
*   **请求方法**：`GET`
*   **接口路径**：`/disease/heatmap`
*   **响应示例 (成功)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {
        "heatmap_points": [
          {
            "device_id": "farmeye_guard_ws63",
            "disease_type": "rust",
            "severity": "Moderate",
            "timestamp": "2026-07-03T06:15:00",
            "crop_type": "wheat"
          }
        ],
        "summary": {
          "active_disease_types": 1,
          "affected_devices": 1,
          "total_records": 1
        }
      }
    }
    ```

---

### 2.4 图像存储与浏览

#### 2.4.1 上传病虫害图像
*   **请求方法**：`POST`
*   **接口路径**：`/image/upload`
*   **Content-Type**：`multipart/form-data`
*   **请求参数 (Form Data)**：
    *   `file` (**必需**，Binary File)：支持 `jpg/png` 格式，文件大小不超过 10MB。
    *   `disease_record_id` (可选，Int)：关联的病虫害记录 ID。如果传入，系统会自动将该记录的 `image_path` 字段更新为上传图片的公开 URL。
    *   `device_id` (可选，String)：所属设备 ID，有利于后端路径组织。
*   **响应示例 (成功)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {
        "image_id": "img_20260703_061500_021",
        "image_path": "/images/2026/07/03/img_20260703_061500_021.jpg",
        "file_size": 154200,
        "uploaded_at": "2026-07-03T06:15:01"
      }
    }
    ```

#### 2.4.2 浏览/下载病虫害图像
*   **请求方法**：`GET`
*   **接口路径**：`/image/{image_id}`
*   **参数说明**：路径参数，输入上传时获取的 `image_id`（如 `img_20260703_061500_021`）。
*   **响应**：返回该图片的**原始二进制流文件 (FileResponse)**，客户端直接绑定到 ImageViewer 控件展示。

---

### 2.5 设备控制与日志

#### 2.5.1 手动下发控制指令
鸿蒙 App 或 上位机控制面板按钮按下时触发。
*   **请求方法**：`POST`
*   **接口路径**：`/command/send`
*   **请求体 (JSON)**：
    ```json
    {
      "device_id": "farmeye_guard_ws63",
      "command": "spray ON", // 继电器1开
      "source": "manual_app", // 可选 'manual_app' (鸿蒙端) / 'manual_pc' (上位机)
      "operator": "user_admin" // 可选，操作人名称
    }
    ```
    > **支持的命令规范 (command)**：
    > * `"led ON"` / `"led OFF"`（控制 LED 灯指示）
    > * `"beep ON"` / `"beep OFF"`（控制蜂鸣器）
    > * `"spray ON"` / `"spray OFF"`（控制喷淋继电器）
    > * `"irrig ON"` / `"irrig OFF"`（控制灌溉继电器）
*   **响应示例 (下发成功并设备已响应)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {
        "command_id": "cmd_20260703_143000_187",
        "device_id": "farmeye_guard_ws63",
        "command": "spray ON",
        "status": "sent"
      }
    }
    ```
*   **响应示例 (设备离线失败)**：
    如果后台判定设备已离线（超过 30s 未上报传感器数据），不会调用华为云 API，直接返回：
    ```json
    {
      "code": 1003,
      "message": "Device offline/unreachable",
      "data": null
    }
    ```

#### 2.5.2 查询控制日志记录
*   **请求方法**：`GET`
*   **接口路径**：`/command/logs`
*   **Query 参数**：
    *   `device_id` (可选，String)：按设备筛选。
    *   `source` (可选，String)：来源筛选 (`auto` 自动控制 / `manual_app` / `manual_pc`)。
    *   `start` / `end` / `page` / `page_size` (可选，筛选及分页)。
*   **响应示例 (成功)**：
    ```json
    {
      "code": 0,
      "message": "success",
      "data": {
        "pagination": { "total": 1, "page": 1, "page_size": 20 },
        "records": [
          {
            "id": 10,
            "device_id": "farmeye_guard_ws63",
            "command_id": "cmd_20260703_143000_187",
            "timestamp": "2026-07-03T14:30:00",
            "command": "spray ON",
            "source": "manual_app",
            "operator": "user_admin",
            "result_code": 0,
            "result_msg": "success"
          }
        ]
      }
    }
    ```

---

### 2.6 智能防治建议

#### 2.6.1 获取综合防治建议
供鸿蒙端或上位机“防治诊断”大屏轮询拉取（推荐轮询间隔 10s）。
*   **请求方法**：`GET`
*   **接口路径**：`/advisory`
*   **Query 参数**：
    *   `device_id` (可选，String)：按设备筛选。
    *   `start` / `end` (可选)。
    *   `window_minutes` (可选，Int)：查询的时间窗口分钟数，默认 `60`。系统会自动聚合此时间窗口内的 AI 识别结果，结合当前环境数据输出联动防治分析。
*   **响应示例 (成功 - 存在扩散风险)**：
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
          "max_conf": 0.925,
          "object_number": 2,
          "all_object": [
            {
              "类别": "rust",
              "置信度": 0.925,
              "位置": [10.0, 20.0, 50.0, 60.0]
            },
            {
              "类别": "rust",
              "置信度": 0.85,
              "位置": [30.0, 40.0, 70.0, 80.0]
            }
          ],
          "timestamp": "2026-07-03T06:15:00"
        },
        "current_env": {
          "temperature": 23.5,
          "humidity": 88.2,
          "light": 35,
          "co2": 450
        },
        "env_disease_linkage": {
          "risk_level": "high",
          "matched_conditions": [
            "humidity > 85%",
            "15℃ <= temperature <= 25℃"
          ],
          "recommendation": "当前温度在 15-25℃ 且湿度高达 88.2%，高度吻合锈病高湿繁殖环境，孢子扩散风险极高。"
        },
        "advisory": {
          "action": "manual_inspect",
          "description": "检测到中度小麦锈病且环境适宜扩散。建议立即进行人工现场排查，准备在 48 小时内对中心病区喷洒三唑酮等针对性杀菌药剂，并密切关注周边健康叶片变化。",
          "auto_action_triggered": false,
          "auto_action": null
        }
      }
    }
    ```
    > **说明**：如果该窗口内没有任何 AI 检测记录，`data` 内部各子字段将直接返回 `null`。

---

## 三、 全局业务错误码说明

当接口响应 HTTP 状态码为 `200` 时，业务层依靠外层 JSON 的 `code` 来判断具体状态。以下是系统的全局错误码字典：

| 错误码 (code) | 消息 (message) | 场景说明 |
| :--- | :--- | :--- |
| `0` | `success` | 请求处理完全成功。 |
| `1001` | `Parameter validation failed` | 参数验证失败（如缺失必填参数，或分页参数超出范围）。 |
| `1002` | `Resource not found` | 资源不存在（如查询了不存在的图片 ID）。 |
| `1003` | `Device offline/unreachable` | 设备离线（超过 30s 无上报），禁止下发控制指令。 |
| `1004` | `Invalid or missing API Key` | 安全校验失败，`X-Api-Key` 请求头缺失或与服务器配置不匹配。 |
| `1005` | `Request rate limit exceeded` | 接口调用频率限制（防止大屏轮询过快导致拒绝服务）。 |
| `2001` | `Database execution error` | 后端数据库（KingbaseES / Postgres）交互失败。 |
| `3001` | `Huawei IoTDA service call failed` | 华为云物联网平台接口调用失败（通常是 IoTDA 鉴权失效或项目 ID 错误）。 |
| `5000` | `Internal server error` | 服务端未捕获的内部运行异常。 |
