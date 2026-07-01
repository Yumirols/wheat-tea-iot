# 第 2 轮迭代需求 — 系统模块设计修订

## 上一轮诊断摘要

经组件B质量审查诊断（`b_v1_diag_v1.md`），**共发现问题 30 项**：严重 4 / 高 6 / 中 6 / 低 14。组件B质询报告（`b_v1_challenge_v1.md`）已对全部 30 项进行交叉验证，结论：**全部成立、质询通过**。

---

## 本轮修订任务

请以 `a_v1_output_v1.md` 作为基础文件，针对以下问题进行修订，产出 `a_v2_output_v1.md`。

### 第一优先：阻断性问题（CRITICAL）

以下 4 项直接阻断实现，本轮必须全部修复：

**C1 — 病虫害严重度等级数量与规格书矛盾**
- 位置：第 2.2 节"严重度分级标准"表
- 问题：设计文档定义 4 级（Normal/Mild/Moderate/Severe），规格书仅定义 3 级（Mild/Moderate/Severe）
- 修订：删除"Normal（健康，未检出）"等级，改为 3 级；severity_code 改用 1-3 或 0-2；同步修改所有引用此等级的 API 响应（4.3 节 sensor/history records，4.4.1 节 disease/records，4.4.2 节 stats 的 by_severity，4.6.1 节 advisory 的 latest_detection）

**C2 — alarm_flag 位掩码完全未定义**
- 位置：第 2.1 节"上报数据字段"表
- 问题：`alarm_flag` 标为 `int (bitmask)` 但全文未定义位含义
- 修订：在第 2.1 节中引用 DATA_INVENTORY.md 的完整位掩码定义（0x01 高温 / 0x02 低温 / 0x04 高湿 / 0x08 低湿 / 0x10 低光照 / 0x20 高 CO2 / 0x40 低氮 / 0x80 低磷）

**C3 — 告警阈值完全未定义**
- 位置：第 2.4 节"决策引擎"
- 问题：声称基于"阈值规则"但全文无任何阈值
- 修订：在第 2.4 节或新增专节中明确列出所有传感器的告警阈值（temperature > 38.0℃ / < -10.0℃, humidity > 90.0% / < 15.0%, light < 100, co2 > 2000 ppm, soil_n < 30.0, soil_p < 10.0）

**C4 — 土壤 NPK 推导公式缺失**
- 位置：第 2.1 节"上报数据字段"表及第 6.5 节
- 问题：标注"推导/模拟"但未给出具体公式
- 修订：在第 2.1 节或第 6.5 节中写入 soil_n = 45.0 + temperature * 0.2 / soil_p = 18.0 + humidity * 0.1 / soil_k = 50.0 + light * 0.02

### 第二优先：功能缺口（HIGH）

**H1 — 病虫害记录 API 响应中缺少 image_path**
- 位置：第 4.4.1 节及 4.4.2 节响应
- 修订：在 `/api/v1/disease/records` 和 `/api/v1/disease/stats` 的 record 对象中增加 `image_path` 字段

**H2 — 缺少图片上传/获取 API 端点**
- 位置：第 4 节接口清单
- 修订：增加 `POST /api/v1/image/upload` 和 `GET /api/v1/image/{image_id}` 两个端点，定义请求/响应

**H3 — 缺少热力图功能**
- 位置：第 4.6 节防治建议接口及全文
- 修订：增加热力图数据接口（如 `GET /api/v1/disease/heatmap`），或在现有防治建议接口 data 中增加热力图数据结构；说明热力图数据格式（坐标+严重度）

**H4 — 缺少环境数据与病虫害发生的联动监测分析**
- 位置：全文
- 修订：在决策引擎或第 2.4 节中增加联动监测逻辑说明；提供相应的查询/统计 API（如在 advisory 中增加环境-病害关联分析）

**H5 — 设备在线/离线判定机制未定义**
- 位置：第 2.4 节或设备管理相关章节
- 修订：明确在线判定逻辑（如 30s 内无数据上报 = 离线），并说明离线判定在 Python API 侧的检测机制

**H6 — 鸿蒙端消息推送机制空白**
- 位置：第 2.6 节
- 修订：明确推送技术方案（HTTP 轮询 / WebSocket / 华为 Push Kit），给出选择理由和实现要点

### 第三优先：完善性问题（MEDIUM）

- **M1**：在第 4.2 节中明确 IoTDA 双 Webhook 的规则配置方案，说明在华为云 IoTDA 侧如何配置规则使传感器数据和 AI 数据路由到不同端点
- **M2**：在第 2.5 节中注明 `sensor_snapshot` 表名选择，说明与架构关系文档中 `sensor_data` 的差异
- **M3**：在第 2.4 节或流 B 中补充完整的决策规则矩阵（至少覆盖各病虫害类型 × 各严重度 × 关键环境条件的组合）
- **M4**：增加数据保留/清理策略章节（建议：sensor_snapshot 按天聚合后仅保留最近 30 天明细数据）
- **M5**：在 GPIO 表中 OLED 行补充 I2C 地址 `0x3C`
- **M6**：在上报数据字段说明中注明 distance=-1 的含义（超时/无目标），并说明处理方式

### 第四优先：润色性修订（LOW）

- **L1**：在架构命名旁标注与参考文档的等价关系
- **L2**：补充命令应答 payload 格式（引用 DATA_INVENTORY.md 第 3.3 节的 result_code/response_name/paras 结构）
- **L3**：在第 6.5 节中明确标注与规格书关于 NPK 传感器的矛盾，说明当前采用推导方案
- **L4**：为防治建议接口的 1 小时窗口补充选择依据或改为可配置
- **L5**：增加 `firmware/tests/` 目录或说明嵌入式端测试策略
- **L6**：确认金仓数据库镜像 tag 并固定版本号（非 latest）
- **L7**：补充预留错误码（1004 认证失败 / 1005 频率限制 / 3001 IoTDA 调用失败）
- **L8**：统一 sensor/latest 与 sensor/history 的返回字段集
- **L9**：增加日志配置模块占位
- **L10**：增加实时数据获取方式的选择说明（HTTP 轮询 vs WebSocket vs SSE）
- **L11**：明确列出上位机大屏展示的环境参数清单
- **L12**：增加 API 版本管理策略的简要说明
- **L13**：明确选择图表库（推荐 PyQtGraph 并给出理由）
- **L14**：在 sensor/history 查询响应中增加 alarm_flag 字段

---

## 参考文件

- 原设计文档：`a_v1_output_v1.md`（本次编辑的基线文件）
- 系统规格说明：`E:\dev\wheat-tea-iot\docs\system_specification.md`
- 系统架构关系：`E:\dev\wheat-tea-iot\docs\system_architecture_relationship.md`
- 数据清单：`E:\dev\wheat-tea-iot\docs\DATA_INVENTORY.md`
- 诊断报告：`b_v1_diag_v1.md`
- 质询报告：`b_v1_challenge_v1.md`
