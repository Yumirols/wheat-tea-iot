# 第 3 轮迭代需求 — 系统模块设计文档修订

**迭代轮次**: M=3
**运行模式**: execution
**修订对象**: `a_v2_copy_from_v1.md`（1536 行，>1000 行，采用 COPY_AND_EDIT 模式）
**生成日期**: 2026-06-30

---

## 一、前轮迭代回顾

### 第 1 轮 (M=1)

判定结果: **RETRY**。组件B诊断发现 30 项问题（CRITICAL 4 / HIGH 6 / MEDIUM 6 / LOW 14）。

### 第 2 轮 (M=2)

判定结果: **RETRY**。组件A产出 `a_v2_copy_from_v1.md`，对 30 项遗留问题的修复率达 **100%**。组件B诊断新发现 5 项轻度问题（MEDIUM 2 / LOW 3），组件B质询报告确认全部 5 项新发现均成立且严重度定级合理，最终判决为 **LOCATED**。

---

## 二、需要修复的问题

以下 5 项问题来自第 2 轮组件B诊断报告 `b_v2_diag_v1.md`，经质询报告 `b_v2_challenge_v1.md` 逐项交叉验证确认全部成立。

### [N1] MEDIUM — 图片存储持久化机制未定义

**关联章节**: §4.7.1 图片上传端点、§5.2 docker-compose

**问题描述**: 图片上传端点定义了 `POST /api/v1/image/upload` 成功返回 `image_path`，但未说明图片在 VPS 上的物理存储位置（本地文件系统路径 or Docker 挂载卷 or 外部对象存储）。docker-compose.yml（§5.2）中仅定义了 `db_data` 一个 volume，无图片存储相关的 volume 挂载。若图片存储在 API 容器内部，容器重建或重启后历史图片将丢失，`GET /api/v1/image/{image_id}` 将返回 1002 "image not found"。

**修复要求**:
1. 在 §5.2 docker-compose.yml 中增加图片存储 volume 挂载（如 `- ./images:/app/images`）
2. 在 §4.7 图片接口说明中补充存储策略说明（本地磁盘路径、Docker volume 映射关系）
3. 明确说明图片路径 `/images/...` 相对于 volume 挂载点的映射关系

### [N2] MEDIUM — IoTDA 命令应答 Webhook 回传路径不完整

**关联章节**: §3.2 流 B 时序图、§4.2 Webhook 配置

**问题描述**: 流 B（AI识别→报警联动→自动控制）的时序图中，命令应答通过 "MQTT PUB → IoTDA → HTTP POST (Webhook)" 路径回传至 Python API（行 541-543）。但 §4.2 的"双 Webhook 路由规则配置方案"仅定义了两条规则：
- `rule_sensor_forward`（service_id = "farmeye_env"）
- `rule_ai_forward`（service_id = "farmeye_ai"）

缺少命令应答的 Webhook 转发规则。若 IoTDA 未配置对应的数据转发规则，命令应答将无法推送到 Python API，导致 `control_logs` 表中的 `result_code` 字段无法被正确更新。

**修复要求**（二选一，推荐方案 A）:
- **方案 A（推荐）**: 在 IoTDA 增加第三条转发规则 `rule_cmd_response_forward`（service_id = "farmeye_cmd_response" 或匹配 `.../sys/commands/response/...` topic），将命令应答通过 Webhook 转发至 Python API 的新端点 `POST /api/v1/iotda/cmd/response`
  - 需同步修改：§4.2 双 Webhook 配置表（增加第三条规则）、§4.2 新增 4.2.3 命令应答接收端点、§3.2 流 B 时序图明确标注命令应答回传路径、§4.8 接口清单汇总表
- **方案 B**: 在 §3.2 流 B 说明中明确标注 Python API 通过轮询 IoTDA 设备影子/状态接口获取命令执行结果，并删除时序图中 "IoTDA → HTTP POST (Webhook)" 的误导标注

### [N3] LOW — 决策规则矩阵中环境条件边界值未明确开闭区间

**关联章节**: §2.4 决策规则矩阵

**问题描述**: 决策规则矩阵（行 288-301）中多处使用范围写法如 "temperature 15-25℃"、"humidity 50-80%"、"humidity > 85%"、"temperature 20-30℃"。其中带 `>` 的条件（如 `humidity > 85%`）明确了开闭性，但使用连字符表示范围的条目未明确开闭区间（15℃ 是否触发？25℃ 是否触发？）。前后端对边界值处理不一致时，可能导致同一条件下决策结果不同。

**修复要求**: 将决策规则矩阵中的范围表示统一为明确的开闭区间形式，如改 `temperature 15-25℃` 为 `15℃ ≤ temperature ≤ 25℃` 或 `15℃ < temperature < 25℃`（请在修订时根据领域合理性确定开/闭）。

### [N4] LOW — 数据聚合后存储的表结构未定义

**关联章节**: §2.5 数据保留与清理策略

**问题描述**: 数据保留策略（行 415）声明"sensor_snapshot 30 天前数据按天聚合（取均值/最大/最小）后仅保留聚合记录"，但当前 DDL 仅定义了 `sensor_snapshot`、`disease_records`、`control_logs` 三张表，缺少聚合表（如 `sensor_daily_aggregation`）的 DDL 定义。定时任务实现者需自行设计聚合表结构。

**修复要求**（选择其一）:
- 补充聚合表 DDL（如 `sensor_daily_aggregation`），包含设备ID、日期、各传感器字段的 min/max/avg 值、样本数量
- 或在策略说明中标注"聚合表结构将在详细设计阶段定义"

### [N5] LOW — Python API 端 Webhook 异常处理策略未说明

**关联章节**: §4.2.1（接收设备属性上报）、§4.2.2（接收 AI 识别结果上报）

**问题描述**: 两个 IoTDA Webhook 端点的"处理逻辑"步骤均以"返回 200 OK"结尾，未说明数据库写入失败时应返回何种 HTTP 状态码。§4.2 配置要点中说明了 IoTDA 侧重试机制（默认重试 3 次，间隔 30s）。若 API 在 DB 写入失败时仍返回 HTTP 200，IoTDA 将认为转发成功而不重试，导致数据静默丢失。

**修复要求**: 在 §4.2.1 和 §4.2.2 的处理逻辑步骤中增加错误处理说明——数据库写入失败时返回 HTTP 500（触发 IoTDA 侧重试机制），并记录错误日志。

---

## 三、质询报告额外提示

第 2 轮质询报告（`b_v2_challenge_v1.md` §5.2）指出了 3 项极微小边缘项（低于 LOW 等级），不强制要求修复但可在修订时酌情处理：

1. **时间戳格式不一致**: §4.1 通用约定声明时间戳格式为无时区的 `YYYY-MM-DDTHH:mm:ss`，但 §4.2.1 IoTDA Webhook 请求体中 `event_time` 使用 `2026-06-30T10:15:30Z`（UTC 时区后缀 Z）
2. **多设备扩展策略**: device_id 固定为 `farmeye_guard_ws63`，未说明多设备扩展策略
3. **决策规则矩阵运算符风格不一致**: 部分条件使用显式不等式（`humidity > 85%`），部分使用范围（`temperature 15-25℃`）— 此项与 N3 修复合并处理

---

## 四、修订策略

- **采用 COPY_AND_EDIT 模式**: 上一轮组件A产出（`a_v2_copy_from_v1.md`）共 1536 行，超过 1000 行阈值，请将原文件复制为新文件后执行修订
- **修订范围**: 仅修改上述 N1-N5 涉及的内容，保持文档其他部分不变
- **修订追溯**: 在文档末尾 §7 修订说明表中增加 v3 修订记录
- **版本标识**: 在文档头部版本表中增加 v3 行
