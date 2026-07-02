# 系统模块设计需求

## 项目概述
农眼卫士 - 小麦与茶叶病虫害智能识别与防治决策系统。基于物联网环境监测与边缘端 AI 图像识别技术，实现小麦与茶叶病虫害的智能识别、环境联动监测与防治决策的软硬件一体化系统。

## 任务说明
进行详细的系统模块设计，包括系统总体设计、功能设计、工程文件组织结构等。关注系统模块之间的数据交互，特别是 VPS 上 Python API 提供的接口规范。不需要对每个模块内部进行详细设计。

## 必须包含的模块
1. **嵌入式端 (Embedded MCU)** — WS63(Hi3863)+LiteOS，传感器数据采集、边缘AI结果上报、设备控制执行
2. **Python 上位机 (PC Upper Computer)** — PyQt/PySide，现场PC端监控与控制
3. **AI 模型识别 (AI Edge Inference)** — CNN 图像识别，病虫害检测与分级
4. **华为云设备接入平台 (IoTDA)** — MQTT 代理与命令中转
5. **鸿蒙应用 (HarmonyOS App)** — ArkTS/ArkUI，移动端监控与控制
6. **金仓数据库 (KingbaseES)** — 国产化数据存储中心

## 参考文档
- 系统规格说明: E:\dev\wheat-tea-iot\docs\system_specification.md
- 系统架构关系: E:\dev\wheat-tea-iot\docs\system_architecture_relationship.md
- 数据清单: E:\dev\wheat-tea-iot\docs\DATA_INVENTORY.md

## 关键数据交互点
- 嵌入式 → IoTDA (MQTT): 传感器环境数据、AI识别结果上报
- IoTDA → Python API (HTTP Webhook): 数据流转转发
- Python API → 金仓数据库 (SQL): 数据持久化
- Python API → IoTDA (HTTP API): 命令下发
- 鸿蒙应用 ↔ Python API (REST): 数据查询与控制
- Python 上位机 ↔ Python API (REST): 数据查询与控制
- Python API (FastAPI/Flask) 接口规范需详细定义
