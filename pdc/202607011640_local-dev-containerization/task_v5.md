# 任务指令（v5）

## 动作
NEW

## 任务描述

创建 API 基础设施层和传感器数据管道（IoTDA 数据摄入 + 传感器查询 + 业务服务）。预期产出以下文件：

### 1. server/app/api/deps.py
API Key 认证依赖注入和常用依赖导出。

**要求**：
- 提供 `verify_api_key(x_api_key: str = Header(None))` 依赖，从 `settings.API_KEYS` 中读取逗号分隔的密钥列表，匹配则返回密钥值，不匹配则抛出 HTTPException 401（code=1004, message="Invalid or missing API Key"）
- 当 `settings.API_KEYS` 为空字符串时，自动跳过认证（允许无密钥访问，用于开发模式）
- 重导出 `get_db` 从 `app.db.session`（作为公共依赖入口）
- 导入 `from fastapi import Header, HTTPException, Depends` 和 `from app.config import settings`

### 2. server/app/api/router.py
统一路由注册模块。

**要求**：
- 定义 `api_router` 为 `APIRouter(prefix=settings.API_V1_PREFIX)`
- 从 v1 各模块导入子路由器并注册：
  - `from app.api.v1.iotda import router as iotda_router` → `api_router.include_router(iotda_router)`
  - `from app.api.v1.sensor import router as sensor_router` → `api_router.include_router(sensor_router)`
  - （其余 v1 路由留待后续子任务注册时添加）
- 所有路由注册不带额外 prefix（已在 APIRouter 层面统一为 /api/v1）

### 3. server/app/api/v1/iotda.py
IoTDA Webhook 接收端点。

**要求**：
- 定义 `router = APIRouter()`（无额外 prefix）
- 所有端点默认不加认证依赖（IoTDA 推送无法携带自定义 Header），但在内部解析 device_id 进行校验

**端点 1：POST `/iotda/properties/report`** — 传感器属性上报
- 接收 IoTDA 标准设备属性上报 payload
- 解析 `notify_data.body.services[0].properties` 中的字段（temperature、humidity、light、co2、soil_n、soil_p、soil_k、distance、rssi、ip_addr、mac_addr、alarm_flag）
- 从 `notify_data.header.device_id` 提取设备 ID
- 如果 `device_id` 不存在于 devices 表，自动创建新设备记录（device_id + mac_addr，device_name 留空，online=false）
- 写入 sensor_snapshot 表
- 返回 `{"code": 0, "message": "success", "data": {"id": <新记录ID>}}`
- 幂等性：相同 device_id + timestamp 的重复写入由数据库 UNIQUE 索引拒绝，捕获异常后仍返回 200（IoTDA 重试场景）
- 未知 service_id（非 farmeye_env）：忽略写入，仍返回 200
- 缺少必要字段（notify_data）：返回 422

**端点 2：POST `/iotda/ai/report`** — AI 识别结果上报
- 接收 AI 识别 payload
- 解析 `notify_data.body.services[0].properties` 中的字段（crop_type、disease_type、confidence、severity、severity_code）
- 从 header 提取 device_id
- 写入 disease_records 表
- 返回 `{"code": 0, "message": "success", "data": {"id": <新记录ID>}}`
- 幂等性：相同 device_id + timestamp + disease_type 的重复写入由 UNIQUE 索引拒绝
- 未知 service_id（非 farmeye_ai）：忽略写入，返回 200

**端点 3：POST `/iotda/cmd/response`** — 命令应答上报
- 接收命令应答 payload
- 解析 command_id、result_code（可选）、result_msg（可选）
- 从 header 提取 device_id，从 properties 中提取 command_id
- 更新 control_logs 表中对应 command_id 的记录（设置 result_code、result_msg）
- 返回 `{"code": 0, "message": "success"}`
- 如果 command_id 不存在于 control_logs，仍返回 200（仅记录已消费）

**payload 格式参考**（代码中应包含示例注释）：
- 传感器上报: `{"resource":"device.property","event":"report","event_time":"...","notify_data":{"header":{"device_id":"..."},"body":{"services":[{"service_id":"farmeye_env","properties":{...}}]}}}`
- AI 上报: `{"resource":"device.message","event":"report","event_time":"...","notify_data":{"header":{"device_id":"..."},"body":{"services":[{"service_id":"farmeye_ai","properties":{...}}]}}}`

### 4. server/app/api/v1/sensor.py
传感器数据查询端点。

**要求**：
- 定义 `router = APIRouter()`（无额外 prefix）
- 路由使用 `deps.verify_api_key` 认证依赖

**端点 1：GET `/sensor/latest`** — 查询最新传感器数据
- 可选查询参数 `device_id: str = None`
- 指定 device_id：返回该设备最新一条 sensor_snapshot 记录
- 不指定 device_id：返回所有设备的最新记录（每个设备一条）
- 返回 `ResponseModel[list[SensorSnapshotRead] | SensorSnapshotRead]` 格式

**端点 2：GET `/sensor/history`** — 查询历史传感器数据
- 查询参数：`device_id: str`, `start: datetime = None`, `end: datetime = None`, `page: int = Query(1, ge=1)`, `page_size: int = Query(20, ge=1, le=100)`
- 支持时间范围筛选，支持分页
- 返回 `ResponseModel[SensorHistoryResponse]`（含 pagination 和 records）
- page_size 自动截断至最大 100

**端点 3：GET `/sensor/daily`** — 查询日聚合数据
- 查询参数：`device_id: str`, `start: date`, `end: date`, `page: int = Query(1, ge=1)`, `page_size: int = Query(20, ge=1, le=100)`
- 查询 sensor_daily_aggregation 表
- 返回响应包含聚合数据列表

### 5. server/app/services/sensor_service.py
传感器业务逻辑层。

**要求**：
- `create_snapshot(db: Session, device_id: str, properties: dict, timestamp: datetime) -> SensorSnapshot`
  - 从 properties 中提取温湿度等字段，构造 SensorSnapshot 对象
  - 调用 `ensure_device_exists(db, device_id, properties.get("mac_addr"))` 确保设备记录存在
  - 写入 sensor_snapshot，返回新记录
- `ensure_device_exists(db: Session, device_id: str, mac_addr: str | None) -> Device`
  - 检查 devices 表中是否存在该 device_id
  - 不存在则创建新 Device 记录（device_id, mac_addr, online=False）
  - 存在则更新 last_seen 为当前时间
  - 返回 Device 对象
- `get_latest_snapshots(db: Session, device_id: str | None = None) -> list[SensorSnapshot]`
  - 指定 device_id：返回该设备最新一条记录
  - 不指定：返回每个设备的最新记录（使用 ROW_NUMBER 窗口函数或子查询）
- `get_sensor_history(db: Session, device_id: str, start: datetime | None, end: datetime | None, page: int, page_size: int) -> tuple[list[SensorSnapshot], int]`
  - 分页查询 sensor_snapshot，支持时间范围
  - 返回 (records, total_count) 元组
- `get_daily_aggregation(db: Session, device_id: str, start: date, end: date, page: int, page_size: int) -> tuple[list[SensorDailyAggregation], int]`
  - 分页查询日聚合数据

### 6. server/app/services/iotda_client.py
IoTDA HTTP 客户端，用于向设备下发命令。

**要求**：
- `send_command(device_id: str, command: str, paras: dict | None = None) -> dict`
  - 调用华为 IoTDA 同步命令下发 API
  - 使用 `settings.IOTDA_ENDPOINT` 和 `settings.IOTDA_PROJECT_ID`
  - 请求头：`X-Auth-Token`（简单实现中可留空或使用占位）
  - 返回 IoTDA 响应：`{"command_id": "..."}`
  - 异常时抛出 `IotdaClientError` 自定义异常
- 当前为桩实现（placeholder）：因实际 IoTDA 认证需要 Token/IAM 鉴权，先实现为返回模拟成功响应 `{"command_id": f"mock_{uuid4()}"}`，注释标注 TODO 说明正式集成时需补充 IAM 认证

### 7. server/app/main.py 更新
在现有 main.py 中增加：
- 导入路由注册：`from app.api.router import api_router`
- 在 FastAPI app 创建后添加：`app.include_router(api_router)`
- 注意 health 端点和根路径使用了 `@app.get(...)` 装饰器，直接注册在 app 上，不需要路由 prefix 影响

## 选择理由

T5 聚焦于传感器数据管道——从 IoTDA Webhook 数据摄入（iotda.py + services）到传感器数据查询（sensor.py + sensor_service.py），是整套 API 服务中最核心的数据流路径。完成 T5 后，API 服务可以通过 IoTDA 接口接收传感器数据并通过 REST API 查询，具备了基本可用性。API 基础设施层（deps.py、router.py）是所有后续端点模块的前置依赖，必须优先建立。

## 任务上下文

- 参考 `docs/2_vps-deployment.md` 第 4 章（测试方案）的 4.2.1（IoTDA Webhook）和 4.2.2（传感器查询）的测试用例规格作为接口行为规范
- 参考 `docs/2_vps-deployment.md` 第 5.1 节（工程文件组织结构）的目录布局
- 已有产出：`server/app/` 下的完整骨架（config.py、db/session.py、db/base.py、models/、schemas/、main.py）、`server/init/01_create_tables.sql`（DDL）、`server/requirements*.txt`（依赖）
- models 中的 SensorSnapshot、SensorDailyAggregation、DiseaseRecord、ControlLog、Device 均已在 `app/models/__init__.py` 中统一导出
- db session 已在 `app/db/session.py` 中实现，`SessionLocal` 和 `get_db` 可直接使用
- schemas 中的 ResponseModel、PaginationParams、PaginationMeta、SensorSnapshotRead、SensorHistoryResponse 已在对应模块中定义
- `__init__.py` 文件已存在于 app/api/、app/api/v1/、app/services/ 目录中（当前为空）
