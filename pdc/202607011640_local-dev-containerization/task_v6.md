# 任务指令（v6）

## 动作
NEW

## 任务描述

创建病虫害记录、设备列表、命令控制三组 API 端点及其对应的业务服务层。共创建 6 个新文件，修改 2 个已有文件。

### 需创建的文件

#### 1. `server/app/schemas/device.py` — 设备响应 Schema

定义 `DeviceRead(BaseModel)`，字段与 `Device` 模型对应：
- `id: int`
- `device_id: str`
- `device_name: Optional[str]`
- `mac_addr: Optional[str]`
- `ip_addr: Optional[str]`
- `registered_at: Optional[datetime]`
- `last_seen: Optional[datetime]`
- `online: bool`
- `created_at: Optional[datetime]`

配置 `model_config = {"from_attributes": True}`。

#### 2. `server/app/services/disease_service.py` — 病虫害业务逻辑

提供三个函数：

**`get_disease_records(db, device_id, crop_type, disease_type, severity, start, end, page, page_size) -> tuple[list[DiseaseRecord], int]`**

- 从 `DiseaseRecord` 模型查询，支持可选的 `device_id`、`crop_type`、`disease_type`、`severity` 筛选
- 支持 `timestamp` 时间范围过滤（`start` / `end`）
- 分页查询，返回 `(records, total_count)` 元组
- 按 `timestamp DESC` 排序

**`get_disease_stats(db, start, end) -> dict`**

- 统计指定时间范围内的病虫害记录
- 返回字典包含：
  - `total_detections: int` — 总记录数
  - `by_crop: dict[str, int]` — 按作物类型分组统计
  - `by_severity: dict[str, int]` — 按严重程度分组统计（Mild/Moderate/Severe）
  - `by_disease: dict[str, int]` — 按病害类型分组统计
- 使用 `db.query(func.count(...)).group_by(...)` 分组聚合

**`get_heatmap_data(db) -> dict`**

- 返回热力图数据：
  - `heatmap_points: list[dict]` — 每条记录含 `device_id`、`disease_type`、`severity`、`timestamp`、`crop_type`
  - `summary: dict` — 活跃病虫害类型数、受影响设备数等统计

#### 3. `server/app/services/command_service.py` — 命令控制业务逻辑

提供两个函数：

**`create_command(db, device_id, command, source, operator) -> dict`**

- 检查设备在线状态：从 `Device` 模型查询 `device_id`，若 `online != True`，返回 `{"status": "offline", "code": 1003}`
- 设备在线：调用 `iotda_client.send_command(device_id, command)` 下发命令
- 在 `control_logs` 表中创建一条 `ControlLog` 记录（command_id 来自 IoTDA 响应）
- 返回 `{"command_id": ..., "device_id": ..., "command": ..., "status": "sent"}`

**`get_command_logs(db, device_id, source, start, end, page, page_size) -> tuple[list[ControlLog], int]`**

- 从 `ControlLog` 模型查询，支持可选的 `device_id`、`source` 筛选
- 支持 `timestamp` 时间范围过滤
- 分页查询，按 `timestamp DESC` 排序
- 返回 `(records, total_count)` 元组

#### 4. `server/app/api/v1/disease.py` — 病虫害 API 端点

创建 `router = APIRouter()`，所有端点使用 `dependencies=[Depends(deps.verify_api_key)]`。

**GET `/disease/list`**

- 查询参数：`device_id`（可选）、`crop_type`（可选）、`disease_type`（可选）、`severity`（可选）、`start`（可选）、`end`（可选）、`page`（默认 1）、`page_size`（默认 20，最大 100）
- 调用 `disease_service.get_disease_records()`
- 响应格式：`{"code": 0, "message": "success", "data": {"pagination": {...}, "records": [...]}}`

**GET `/disease/stats`**

- 查询参数：`start`（可选）、`end`（可选）
- 调用 `disease_service.get_disease_stats()`
- 响应格式：`{"code": 0, "message": "success", "data": {...stats...}}`

**GET `/disease/heatmap`**

- 无参数
- 调用 `disease_service.get_heatmap_data()`
- 响应格式：`{"code": 0, "message": "success", "data": {"heatmap_points": [...], "summary": {...}}}`

#### 5. `server/app/api/v1/device.py` — 设备列表 API 端点

创建 `router = APIRouter()`，使用 `dependencies=[Depends(deps.verify_api_key)]`。

**GET `/device/list`**

- 查询参数：无（可选 `device_id` 参数用于查询单个设备）
- 查询 `Device` 模型，按 `last_seen DESC NULLS LAST` 排序
- 返回所有设备记录，包含在线状态
- 响应格式：`{"code": 0, "message": "success", "data": [...]}`

#### 6. `server/app/api/v1/command.py` — 命令控制 API 端点

创建 `router = APIRouter()`，使用 `dependencies=[Depends(deps.verify_api_key)]`。

**POST `/command/send`**

- 请求体：`CommandCreate`（device_id, command, source, operator）
- 调用 `command_service.create_command()`
- 响应格式：`{"code": 0, "message": "success", "data": {...command_result...}}`

**GET `/command/logs`**

- 查询参数：`device_id`（可选）、`source`（可选）、`start`（可选）、`end`（可选）、`page`（默认 1）、`page_size`（默认 20，最大 100）
- 调用 `command_service.get_command_logs()`
- 响应格式：`{"code": 0, "message": "success", "data": {"pagination": {...}, "records": [...]}}`

### 需修改的文件

#### 7. `server/app/schemas/__init__.py`

- 添加 `from app.schemas.device import DeviceRead` 导入
- 在 `__all__` 中添加 `"DeviceRead"`

#### 8. `server/app/api/router.py`

- 添加三个新路由导入：
  ```python
  from app.api.v1.disease import router as disease_router
  from app.api.v1.device import router as device_router
  from app.api.v1.command import router as command_router
  ```
- 注册三个新路由：
  ```python
  api_router.include_router(disease_router)
  api_router.include_router(device_router)
  api_router.include_router(command_router)
  ```
- 删除原有的 TODO 注释块

## 选择理由

DiseaseRecord、ControlLog、Device 的 ORM 模型和 Pydantic Schema 已在 T3/T4 准备就绪，iotda_client.send_command() 也在 T5 中实现。这三组端点覆盖任务范围中剩余 API 端点的核心部分，遵循与 sensor 端点相同的成熟模式（FastAPI router + Depends 认证 + Pydantic 响应），业务逻辑明确。完成 T6 后，REST API 层面除 advisory（含联动分析决策引擎）和 image（文件上传模式不同）外，其余端点全部到位。

## 任务上下文

- 参考设计文档 `docs/2_vps-deployment.md` §4.2.3（病虫害记录接口 5 个用例）、§4.2.2 测试 17（设备列表）、§4.2.4（设备控制接口 6 个用例）
- 已有 `DiseaseRecord`、`ControlLog`、`Device` 模型在 `app/models/` 中
- 已有 `DiseaseRecordRead`、`DiseaseStatsResponse`、`CommandCreate`、`CommandRead`、`CommandResponse` Schema
- 已有 `deps.verify_api_key` 认证依赖
- 已有 `iotda_client.send_command()` 函数可供 `command_service` 调用
- 已有 `sensor_service.py` 作为服务层模式参考（函数式风格，接收 `db: Session` 参数）

## 已有产出上下文

当前 `server/` 目录下已完成：
- 本地开发环境基础文件（requirements、.env 模板、.gitignore、.dockerignore）
- DDL 建表与种子数据（init/01_create_tables.sql、02_seed_data.sql）
- Alembic 迁移框架
- FastAPI 应用骨架（config、db/session、models、schemas、main.py）
- API 基础设施（deps.py API Key 认证、router.py 统一路由）
- IoTDA Webhook 端点（properties/report、ai/report、cmd/response）
- 传感器查询端点（sensor/latest、sensor/history、sensor/daily）
- 传感器业务服务与 IoTDA 客户端桩
- 所有 Python 代码语法正确、import 链完整

`router.py` 中已有 `# TODO: 后续子任务注册其他路由` 占位注释，T6 需将其替换为实际的 disease/device/command 路由注册。

## RETRY 说明
N/A
