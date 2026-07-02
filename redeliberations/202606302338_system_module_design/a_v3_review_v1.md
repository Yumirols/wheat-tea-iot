# 技术方案审查报告（v1）

## 审查结果

APPROVED

## 逐维度审查

### 1. 技术准确性

**[通过]** PostgreSQL/KingbaseES `ON CONFLICT` 语法要求冲突目标为 UNIQUE 约束或 UNIQUE 索引。方案已将 `sensor_snapshot` 和 `disease_records` 两表的索引正确修改为 `CREATE UNIQUE INDEX`，与后续 `INSERT ... ON CONFLICT ... DO NOTHING` 调用匹配。`disease_records` 索引增加 `disease_type` 列为合理增强，支持同秒内不同病虫害类型的并发上报。

**[通过]** `devices` 表新增 `ip_addr VARCHAR(16)` 字段类型恰当（IPv4 点分十进制最大长度 15 字符，留 1 字节安全边界）。

**[通过]** HTTP 503 Service Unavailable 用于 `degraded` 状态语义正确——服务仍在运行但部分功能降级，503 是最合适的 HTTP 状态码。

**[通过]** `command_id` 预生成方案（`cmd_YYYYMMDD_HHmmss_XXX` 格式，INSERT 时即写入）消除了 IoTDA 响应前的 NULL 窗口期，设计合理。

**[通过]** FastAPI、KingbaseES、华为云 IoTDA、psycopg2/SQLAlchemy 等技术选型均为真实存在且广泛使用的技术栈，能力描述与实际情况一致。

### 2. 完备性

**[通过]** N-01（索引类型修正）：三处修改均已覆盖——`sensor_snapshot` UNIQUE INDEX、`disease_records` UNIQUE INDEX（含 `disease_type` 增强）、`event_time` 毫秒精度说明（§4.2 幂等性说明段落）。

**[通过]** N-02（API 响应字段一致性）：三处修改均已覆盖——`devices` DDL 新增 `ip_addr` 字段（§2.5 表4）、§4.2.1 处理逻辑增加同步更新 `devices` 表 `ip_addr` 步骤、§4.3.2 `/sensor/history` 响应补充 `ip_addr` 和 `mac_addr` 字段。

**[通过]** O-01（联动分析字段补全）：§4.4.1 病虫害记录列表 API 响应 `records` 元素已补充 `linkage_risk_level` 和 `linkage_detail` 字段，且给出了具体示例值，实现者可直接据此编写查询逻辑。

**[通过]** O-02（日聚合查询 API）：新增 §4.3.3 `GET /api/v1/sensor/daily` 端点，参数完整（`device_id` 必填、`start`/`end` 可选日期、`page`/`page_size` 分页），响应示例包含所有聚合指标（均值/最大/最小值 + `record_count`）。§4.8 接口清单已同步新增 #6 条目，后续条目 #7–#17 已重编号。原 §4.3.3 设备列表接口已重编号为 §4.3.4。"聚合-保留-查询"链路已闭合。

**[通过]** O-03（健康检查状态码）：`degraded` HTTP 状态码已改为 503（§4.10.1），`healthy` 保持 200，`unhealthy` 保持 503。§5.2 docker-compose healthcheck 命令已同步改为 `grep -q '"status":"healthy"'` JSON 解析方式，与 503 状态码兼容。

**[通过]** O-04（command_id 时序说明）：§4.5.1 新增"处理逻辑"步骤（3. 预先生成 `command_id`：API 侧在 INSERT 时即写入）和"`command_id` 为 NULL 的场景说明"段落，明确了两种合法 NULL 场景（历史遗留记录、纯本地控制动作），并澄清自动触发命令在 INSERT 时 command_id 已确定不为 NULL。设计决策说明中解释了保留可为 NULL 而非 NOT NULL 的理由。

**[通过]** 文档版本表已新增 v5 条目（行11），末尾已新增修订说明（v5）节（行1948–1959），逐项列出本轮 6 项修复的具体修改措施。

**[通过]** 数据流完整性保持：sensor 上报→持久化→查询、disease 识别→持久化（含联动分析写入）→查询、日聚合→查询，三条链路均为完整闭环。

### 3. 可操作性

**[通过]** 每项 DDL 变更均给出了完整的 SQL 语句，实现者可直接执行或写入迁移脚本。

**[通过]** 每项 API 变更均给出了端点的 HTTP 方法、路径、参数表、请求体/响应体 JSON 示例，实现者可直接据此编写路由处理函数和 Pydantic Schema。

**[通过]** `command_id` 预生成的具体格式（`cmd_YYYYMMDD_HHmmss_XXX`）给出了明确的格式约定，实现者无需自行设计。

**[通过]** 节号重编号（§4.3.3 改为 sensor/daily，§4.3.4 改为 device/list）已在 v5 修订说明中明确记录，后续引用不会混淆。

**[轻微]** v4 修订说明中仍保留"§4.3.3 设备列表接口"的历史引用（行1910），但该处属于 v4 修订历史记录，反映的是 v4 时的节号状态，不影响当前文档的可操作性，可视为已解决（非阻塞）。

