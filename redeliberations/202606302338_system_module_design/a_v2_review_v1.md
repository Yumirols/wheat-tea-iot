# 技术方案审查报告（v4 — 第4轮修订验证）

## 审查结果

APPROVED

## 逐维度审查

### 1. 技术准确性

**[通过]** 技术选型均确认为真实且适用：
- **FastAPI** (Python web framework)：适合 REST API 构建，异步支持与 IoTDA Webhook 接收场景匹配
- **KingbaseES V8**：人大金仓国产数据库，基于 PostgreSQL，`ON CONFLICT` / `pg_isready` 等语法确认兼容
- **华为云 IoTDA**：MQTT Broker + 规则引擎 + 命令下发 API 均在其产品能力范围内，`service_id` 路由为 IoTDA 规则引擎的标准筛选维度
- **WS63 Hi3863 + LiteOS**：海思 Wi-Fi IoT 芯片，GPIO/ADC/UART/I2C 外设能力与设计文档引脚分配表一致
- **PySide6 / PyQt6 + PyQtGraph**：Python GUI 框架与实时绘图库，适合上位机仪表盘场景
- **ArkTS + ArkUI**：鸿蒙原生 UI 框架，`@ohos.net.http` 和 `@ohos.net.webSocket` 为系统 SDK 模块，名称准确
- **HC-SR04**：超声波测距模块标准量程 2cm-4m，`-1` 表示超时/无目标的约定合理
- 传感器量程与报警阈值的匹配经过校核（LDR 量程 0-100，`light < 20` 对应约 20% 光照强度，符合作物光合作用最低需求）

**[轻微]** `§6.1` 末尾的 `**选择在 VPS 而非华为云上部署 Python API 的附加理由**：` 标题后续内容缺失（其后直接进入 §6.2）。这不影响技术决策的正确性（§6.2-§6.3 实际上已在讨论 VPS 部署理由），但存在格式断裂。建议补充一行说明或将该标题改为引领性的过渡句。

### 2. 完备性

**[通过]** 全部 27 项强制修订项（C-03, H-01/H-02/H-04/H-06, M-01/M-03/M-05/M-06/M-07/M-08/M-09/S-01/S-02, L-01~L-07/L-09/L-10/L-12~L-14/S-03/S-04）均已覆盖，逐项验证如下：

- **C-03**：`system_architecture_relationship.md` 的所有功能引用已清除。§1.1 术语等价说明完全自包含，§2.5/§6.6 表名说明独立，§5.1 目录列表已移除该条目。全文唯一残留为修订历史表中对修复动作的自述性记录——非依赖引用。
- **H-01**：§6.1 已增加 6 维度分歧对比表（成本/国产化/数据主权/开发便利性/IoTDA集成延迟/规格一致性）及明确仲裁结论，并标注 `system_specification.md` §2.3 协同修订要求。
- **H-02**：§4.9 已定义 `GET /api/v1/export/sensor` 端点（含 CSV/XLSX 双格式支持），§4.8 接口清单第 15 项，§2.7 上位机已补充导出对接说明。
- **H-04**：§4.3.1 `GET /api/v1/sensor/latest` 响应格式已统一为 `records` 数组，附加格式统一说明。
- **H-06**：低光照报警阈值已从 `< 100` 修正为 `< 20`（§2.1 alarm_flag 表 + §2.4 告警阈值表），已标注 `DATA_INVENTORY.md` §2.3 协同修订。
- **M-01**：§2.5 新增 `devices` 表（5 字段 + 索引），§4.3.3 设备列表接口已补充数据来源说明。
- **M-03**：§4.2 已增加完整幂等性保障说明（三表三种去重策略 + `ON CONFLICT DO NOTHING`），§4.2.1-§4.2.3 处理逻辑均已嵌入幂等步骤。
- **M-05**：§4.10 已定义 `GET /api/v1/health` 端点（含三种健康状态判定逻辑），§4.8 第 16 项，§5.2 api 服务已配置 healthcheck。
- **M-06**：§2.3 MQTT 连接参数已拆为开发/生产双环境表（明文 1883 vs TLS 8883），附带 TLS 证书配置说明和跨文档协同标注。
- **M-07**：§2.4 联动监测逻辑已增加步骤 3-4（持久化写入 `disease_records`），§2.5 `disease_records` DDL 新增 `linkage_risk_level` / `linkage_detail` 字段，§3.2 流 B 序列图已标注联动分析 DB 写入。
- **M-08**：§4.3.2 `GET /api/v1/sensor/history` 响应 JSON 的 records 元素已增加 `device_id` 字段。
- **M-09**：§2.4 决策规则矩阵已增加"条件不满足时行为"列（`action=manual_inspect`），附带处理原则说明。
- **S-01**：§2.1 新增"数据上报策略"小节（`farmeye_env` / `farmeye_ai` 两个 service_id + 负载内容说明），§3.1 交互矩阵已更新。
- **S-02**：§2.4 设备在线判定机制已明确"进程内 dict + 单 worker + devices 表持久化"方案，含多 worker 升级说明。
- **L-01~L-07, L-09/L-10/L-12~L-14, S-03/S-04**：全部 13 项低优先级修订已在对应位置实现，与修订说明表（§文档末尾）列出的修改措施一致。

**[通过]** 数据流形成完整闭环：
- 流 A（传感器上报→持久化）：MCU → IoTDA → Webhook → API → KingbaseES
- 流 B（AI 识别→联动→控制）：MCU/AI → IoTDA → Webhook → API(写入+联动分析+决策+命令) → IoTDA API → MCU → CMD Response → Webhook → API(更新日志)
- 流 C（用户手动控制）：Client → API → IoTDA API → MCU，含错误路径（离线→1003）
- 流 D（多端查询）：Client → API → KingbaseES → API → Client

**[通过]** 跨文档协同修订清单已标注 4 项需同步修改的外部文件（`system_specification.md` §2.3/§3, `DATA_INVENTORY.md` §2.3/§3.4）。

### 3. 可操作性

**[通过]** 每项技术决策均有明确结论，无开放性问题：
- 数据库选型：KingbaseES V8，有具体镜像标签 `V008R006C008B0020`
- API 认证：API Key 双模式，有具体 Header 名 `X-API-Key` 和环境变量 `API_KEYS`
- MQTT 连接：双环境参数表（URI/端口/认证方式均已给定）
- 数据保留策略：3 张表的保留期限均已量化（30 天/永久/90 天）
- 部署方案：docker-compose.yml 完整可执行，含 healthcheck、depends_on、volume、环境变量

**[通过]** 实现路径清晰：
- Phase 1-5 的实施建议给出了顺序和交付物
- 各模块职责边界明确，无交叉或遗漏
- 16 个 API 端点每个均有完整的请求/响应示例

**[轻微]** §5.1 中 `server/app/models/` 目录仅列出 3 个模型文件（`sensor.py`, `disease.py`, `control.py`），但设计文档现已定义 5 张数据表（增加了 `devices` 和 `sensor_daily_aggregation`）。建议在模型目录中补充 `device.py` 和 `aggregation.py` 的条目以保持结构一致性。此为实现细节层面建议，不影响实现者理解整体架构——对应 ORM 模型文件的创建是实现者自然能推导的动作。

## 总结

本设计文档（v4）已完整处理第 4 轮迭代需求中的全部 27 项强制修订项。关键问题均已修复：悬空文件引用已清除（C-03），数据存储位置分歧已仲裁（H-01），缺失的 API 端点已补充（H-02/M-05），响应格式已统一（H-04/M-08），阈值错误已修正（H-06），数据表已完整（M-01/L-09），幂等性已保障（M-03），安全配置已增强（M-06），联动分析存储路径已明确（M-07），决策矩阵已补全（M-09），设备协议已澄清（S-01/S-02）。技术选型真实可靠，数据流闭环完整，工程结构可落地。实现者可以此文档为基础开始编码工作。
