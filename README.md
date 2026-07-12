# FarmEye Guard (农眼卫士) v1.0

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

基于物联网环境监测与边缘 AI 图像识别的小麦、茶叶病虫害智能识别与防治决策系统。系统采用 **"端-云-台"三层架构**，覆盖嵌入式感知、边缘智能推理、云端业务处理与多端交互。

---

## 技术栈

| 层级 | 技术 |
|------|------|
| **嵌入式 MCU** | HiSilicon WS63 (Hi3863, RISC-V 32-bit), Huawei LiteOS, C |
| **传感器** | DHT11 (温湿度), LDR (光照), MH-Z19C (CO₂), HC-SR04 (超声波) |
| **执行机构** | 继电器 (喷灌), 蜂鸣器, LED, su-03T 语音模块, SSD1306 OLED |
| **边缘 AI** | YOLOv8 CNN (Python/ONNX), 病虫害分类 |
| **云平台** | 华为云 IoTDA (设备管理 / MQTT Broker / 数据流转) |
| **后端 API** | Python 3.10+, FastAPI, Uvicorn, SQLAlchemy 2.0, Pydantic 2 |
| **数据库** | PostgreSQL 16 |
| **容器化** | Docker (多阶段构建), Docker Compose |
| **反向代理** | Nginx (生产环境) |
| **移动端** | HarmonyOS (ArkTS + ArkUI), `@ohos.net.http` |
| **桌面端** | Python 3.12+, PyQt5 (≥5.15), Matplotlib |
| **CI/CD** | GitHub Actions |
| **测试** | pytest, unittest, ruff, mypy |

---

## 目录结构

```
wheat-tea-iot/
├── docs/                     # 系统设计文档 (8 份)
│   ├── 0_system_specification.md       # 需求规格说明书
│   ├── 1_system_architecture.md        # 系统模块与架构设计
│   ├── 2_vps-deployment.md             # VPS 部署与运维
│   ├── 3_client-api-reference.md       # 客户端 API 参考
│   ├── 4_host-computer-architecture.md # 上位机架构
│   ├── 5_firmware-architecture.md      # 固件架构
│   ├── 6_hamony-architecture.md        # 鸿蒙 App 设计
│   ├── 7_AI-model.md                   # AI 模型设计
│   └── DATA_INVENTORY.md               # 数据资产清单
│
├── firmware/                 # 嵌入式固件 (WS63 Hi3863)
│   ├── src/                  # C 源码: 传感器/执行器/通信/报警/AI 接口
│   ├── vendor/               # 厂商 SDK (BearPi-Pico_H3863)
│   └── tools/                # 构建/烧录工具
│
├── ai-model/                 # AI 模型
│   └── aimodel-new.ipynb     # YOLOv8 训练 Notebook
│
├── server/                   # VPS 后端 (FastAPI)
│   ├── Dockerfile            # 多阶段构建 (base → dev / prod)
│   ├── docker-compose.yml    # API + PostgreSQL + Nginx
│   ├── alembic/              # 数据库迁移
│   ├── app/
│   │   ├── main.py           # FastAPI 入口
│   │   ├── config.py         # 配置管理
│   │   ├── api/              # 路由与接口 (17 个端点)
│   │   ├── models/           # SQLAlchemy ORM 模型
│   │   ├── schemas/          # Pydantic Schema
│   │   ├── services/         # 业务逻辑 (决策引擎)
│   │   ├── core/             # 日志等基础设施
│   │   └── db/               # 数据库会话管理
│   └── tests/                # 单元测试
│
├── harmony-app/              # 鸿蒙移动端 (ArkTS)
│   ├── entry/src/main/ets/
│   │   ├── pages/            # 5 个页面
│   │   ├── components/       # 12 个可复用组件
│   │   ├── services/         # API 服务层
│   │   └── common/           # 模型/常量/工具
│   └── ohosTest/             # 鸿蒙测试
│
├── host-computer/            # 桌面端 (PyQt5)
│   ├── main.py               # 应用入口
│   ├── api_client.py         # REST 客户端
│   └── widgets/              # 仪表盘/报警/控制/历史/统计
│
└── .github/workflows/        # CI/CD
    ├── server-test-verification.yml  # 后端测试 + lint
    └── host-computer-ci.yml          # 上位机检查
```

---

## 快速开始

### 前置要求

- **Docker** ≥ 24 (含 Compose ≥ 2)
- **Python** 3.10+ (后端) / 3.12+ (上位机)
- **Node.js** 14+ + DevEco Studio (鸿蒙 App)
- **BearPi-Pico_H3863 SDK** (固件)

### 1. 启动后端服务

```bash
cd server

# 开发环境 (热重载)
docker compose --profile dev up -d

# 生产环境
docker compose --profile production up -d
```

启动后 API 可用：`http://localhost:8000/api/v1/health`

### 2. 运行测试

```bash
cd server
pip install -r requirements-dev.txt

# 全量测试 + lint + 类型检查
pytest --cov=app
ruff check .
mypy app/
```

### 3. 启动上位机

```bash
cd host-computer
pip install -r requirements.txt  # (如存在) 或 pip install pyqt5 matplotlib requests
python main.py
```

### 4. 构建鸿蒙 App

使用 DevEco Studio 打开 `harmony-app/` 目录，配置签名后构建 `entry` 模块。

### 5. 编译固件

```bash
# 需要 BearPi-Pico_H3863 SDK 环境
cd firmware
# 参见 docs/5_firmware-architecture.md 获取完整构建说明
```

---

## API 概览

所有接口前缀：`/api/v1/`

| 模块 | 端点 | 说明 |
|------|------|------|
| Health | `GET /health` | 服务健康检查 |
| IoTDA | `POST /iotda/properties` | 设备属性上报 Webhook |
| IoTDA | `POST /iotda/ai` | AI 推理结果上报 |
| IoTDA | `POST /iotda/command-response` | 设备指令响应 |
| Sensor | `GET /sensors/latest?device_id=` | 最新环境数据 |
| Sensor | `GET /sensors/history` | 历史传感器数据 |
| Sensor | `GET /sensors/daily` | 日均聚合数据 |
| Disease | `GET /diseases` | 病虫害记录列表 |
| Disease | `GET /diseases/stats` | 病虫害统计 |
| Disease | `GET /diseases/heatmap` | 风险热力图 |
| Control | `POST /commands` | 下发控制指令 |
| Control | `GET /commands/logs` | 指令日志 |
| Advisory | `GET /advisory` | 防治建议 (决策引擎) |
| Image | `POST /images/upload` | 上传作物图片 |
| Image | `GET /images/{id}` | 获取图片 |
| Export | `GET /export/sensors` | 导出传感器数据 (CSV/Excel) |
| Device | `GET /devices` | 设备列表 |

详细文档见 [客户端 API 参考](./docs/3_client-api-reference.md)。

---

## 功能特性

- **多传感器融合**：温度、湿度、光照、CO₂浓度、超声波距离，支持土壤 NPK 公式推导
- **边缘 AI 推理**：YOLOv8 CNN 实时识别 4 类病虫害 (锈病/白粉病/炭疽病/茶小绿叶蝉)，输出置信度与严重度分级
- **智能决策引擎**：结合环境因子与病害置信度联动分析，自动生成喷灌/防治建议
- **设备报警**：MCU 内置位掩码报警引擎，支持阈值触发 + 本地声光/语音报警
- **双端交互**：鸿蒙手机 App (5 页面 + 12 组件) + Python 桌面端 (5 功能面板)
- **数据导出**：支持 CSV / Excel 格式传感器历史数据导出
- **容器化部署**：多阶段 Docker 构建，一键启动开发/生产环境
- **数据保留策略**：原始传感器数据 30 天，控制日志 90 天，病虫害记录永久保存

---

## CI/CD

| 工作流 | 触发条件 | 内容 |
|--------|---------|------|
| `server-test-verification` | `server/**` 变更 → push/PR | pytest + ruff lint + mypy |
| `host-computer-ci` | `host-computer/**` 变更 → push/PR | ruff lint + mypy |

---

## 许可证

本项目基于 [MIT License](./LICENSE) 发布。

Copyright (c) 2026 Yumiro
