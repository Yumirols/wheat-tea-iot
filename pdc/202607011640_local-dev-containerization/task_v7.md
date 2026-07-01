# 任务指令（v7）

## 动作
NEW

## 任务描述

实现防治建议（Advisory）联动分析决策引擎及其 API 端点、图片上传管理 API 端点、以及数据保留定时任务。共创建 4 个新文件，修改 2 个已有文件。

### 产出清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | `server/app/services/advisory_service.py` | 联动分析决策引擎 |
| 新建 | `server/app/api/v1/advisory.py` | 防治建议 API 端点 |
| 新建 | `server/app/api/v1/image.py` | 图片上传与获取 API 端点 |
| 新建 | `server/app/services/data_retention.py` | 数据保留定时任务 |
| 修改 | `server/app/api/router.py` | 注册 advisory 和 image 子路由 |
| 修改 | `server/app/schemas/__init__.py` | 添加新 Schema 导出 |

### 详细需求

#### 1. advisory_service.py — 联动分析决策引擎

提供三个核心函数：

**a) `get_advisory(db: Session, device_id: Optional[str], start: Optional[datetime], end: Optional[datetime], window_minutes: Optional[int]) -> AdvisoryResult`**

根据时间窗口内的 AI 识别结果和环境数据，返回防治建议。

1. 时间窗口计算：
   - 若同时提供 start/end，直接使用；否则以 `window_minutes`（默认 `settings.ADVISORY_WINDOW_MINUTES`=60）计算：`end=now, start=end - window_minutes`
2. 查询 disease_records（支持 device_id 筛选，按 timestamp DESC 取最新 1 条作为 `latest_detection`）
3. 查询 sensor_snapshot（同一设备、同一时间窗口内，按 timestamp DESC 取最新 1 条作为 `current_env`）
4. 调用 `evaluate_linkage()` 进行环境-病虫害联动分析
5. 调用 `generate_advisory()` 基于决策规则矩阵生成防治建议
6. 返回 `AdvisoryResult` 包含以下字段：
   - `latest_detection`: Optional 最新检测信息（crop_type, disease_type, severity, severity_code, confidence, timestamp）
   - `current_env`: Optional 当前环境信息（temperature, humidity, light, co2）
   - `env_disease_linkage`: Optional 联动分析结果（risk_level, matched_conditions: list[str], recommendation: str）
   - `advisory`: Optional 防治建议（action, description, auto_action_triggered: bool, auto_action: Optional[str]）
   - 若时间窗口内无任何检测记录，所有字段均为 None（但 API 响应中 data 仍返回空结构而非 404）

**b) `evaluate_linkage(detection: DiseaseRecord, env_data: SensorSnapshot) -> LinkageResult`**

环境-病虫害联动分析逻辑：

1. 构建环境条件描述列表（如温度是否偏高/偏低、湿度是否利于病害扩散等）
2. 根据 disease_type 判断相关环境因子：
   - `rust`（锈病）：关注 humidity > 85%、temperature 15-25℃
   - `powdery_mildew`（白粉病）：关注 humidity 50%-80%
   - `anthracnose`（茶炭疽病）：关注 humidity > 80%、temperature 20-30℃
   - `leafhopper`（茶小绿叶蝉）：关注 temperature 20-30℃
3. 根据匹配条件数量确定 risk_level：
   - 0 条匹配 → `low`
   - 1 条匹配 → `medium`
   - 2+ 条匹配 → `high`
4. 生成 `recommendation` 字符串（中文，描述当前环境条件对病虫害发展的影响）
5. 返回 LinkageResult（risk_level, matched_conditions, recommendation）

**c) `generate_advisory(detection: DiseaseRecord, linkage: Optional[LinkageResult]) -> AdvisoryAction`**

基于决策规则矩阵生成防治建议（参考 `docs/1_system_architecture.md` §2.4 决策规则矩阵）：

| 病虫害 | severity_code=1 | severity_code=2 | severity_code=3 |
|--------|:--------------:|:--------------:|:--------------:|
| rust (锈病) | manual_inspect, 加强监测 | 环境触发则 spray_fungicide/三唑酮，否则 manual_inspect | spray ON 自动 + 立即喷施杀菌剂 |
| powdery_mildew (白粉病) | manual_inspect, 加强通风 | 环境触发则 spray_fungicide/嘧菌酯，否则 manual_inspect | spray ON 自动 + 立即喷施杀菌剂 |
| anthracnose (茶炭疽病) | manual_inspect, 检查湿度 | 环境触发则 spray_fungicide/苯醚甲环唑，否则 manual_inspect | spray ON 自动 + 立即喷施杀菌剂 |
| leafhopper (茶小绿叶蝉) | manual_inspect, 监控虫口密度 | 环境触发则 spray_insecticide/吡虫啉，否则 manual_inspect | spray ON 自动 + 立即喷施杀虫剂 |

规则要点：
- severity_code=1：一律 `manual_inspect`，给出监测建议
- severity_code=2：检查环境条件是否触发（调用 linkage 的 matched_conditions），触发则给出具体药剂建议，否则 manual_inspect
- severity_code=3：`auto_action_triggered = True`，auto_action = "spray ON"
- 环境触发条件见决策矩阵（参考 `docs/1_system_architecture.md` §2.4）

返回 AdvisoryAction（action, description, auto_action_triggered, auto_action）。

#### 2. advisory.py — 防治建议 API 端点

**`GET /api/v1/advisory`**

查询参数：

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `device_id` | string | 否 | 设备 ID |
| `start` | datetime | 否 | 起始时间 (ISO 8601) |
| `end` | datetime | 否 | 结束时间 (ISO 8601) |
| `window_minutes` | int | 否 | 窗口分钟数，默认 60 |

响应格式（与 `docs/1_system_architecture.md` §4.6.1 一致）：

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
      "confidence": 0.92,
      "timestamp": "2026-06-30T10:15:30"
    },
    "current_env": {
      "temperature": 25.5,
      "humidity": 60.2,
      "light": 85,
      "co2": 450
    },
    "env_disease_linkage": {
      "risk_level": "medium",
      "matched_conditions": [
        "humidity favors rust spread (>85% typical threshold; current 60.2% is below but rising)",
        "temperature 25.5℃ within rust favorable range 15-25℃ (at upper bound)"
      ],
      "recommendation": "当前温湿度条件有利于锈病扩散，建议加强监测频率至5min/次"
    },
    "advisory": {
      "action": "spray_fungicide",
      "description": "检测到中度小麦锈病（severity_code=2），建议在48h内喷施三唑酮类杀菌剂。当前温湿度条件适宜锈病扩散，请加强监测频率。",
      "auto_action_triggered": false,
      "auto_action": null
    }
  }
}
```

无检测记录时的响应（data 内各字段为 null/None）：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "latest_detection": null,
    "current_env": null,
    "env_disease_linkage": null,
    "advisory": null
  }
}
```

使用 `Depends(deps.verify_api_key)` 认证，`Depends(get_db)` 注入会话。

#### 3. image.py — 图片上传与获取 API 端点

**a) `POST /api/v1/image/upload`**

请求体：multipart/form-data

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `file` | UploadFile | 是 | 图片文件（jpg/png，最大 10MB） |
| `disease_record_id` | int | 否 | 关联的病虫害记录 ID |
| `device_id` | string | 否 | 设备 ID（用于路径组织） |

处理逻辑：
1. 验证文件类型（仅允许 image/jpeg, image/png），文件大小限制 10MB
2. 生成 image_id：格式 `img_{yyyyMMdd}_{HHmmss}_{3位随机}`（如 `img_20260630_101530_001`）
3. 按日期组织存储路径：`{IMAGE_STORAGE_PATH}/YYYY/MM/DD/{image_id}.{ext}`
4. 创建目录（如不存在），写入文件
5. 若提供 disease_record_id，更新对应记录的 image_path 字段
6. 返回 ImageUploadResponse（image_id, image_path, file_size, uploaded_at）

成功响应：
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "image_id": "img_20260630_101530_001",
    "image_path": "/images/2026/06/30/img_20260630_101530_001.jpg",
    "file_size": 204800,
    "uploaded_at": "2026-06-30T10:15:30"
  }
}
```

错误处理：
- 文件类型不支持 → 422，`{"code": 1004, "message": "unsupported file type"}`
- 文件过大 → 422，`{"code": 1005, "message": "file too large, max 10MB"}`
- disease_record_id 不存在 → 404，`{"code": 1001, "message": "disease record not found"}`

使用 `Depends(deps.verify_api_key)` 认证，`Depends(get_db)` 注入会话。

**b) `GET /api/v1/image/{image_id}`**

路径参数：image_id（上传时返回的标识）

处理逻辑：
1. 根据 image_id 模式反向查找文件（遍历 IMAGE_STORAGE_PATH 目录，通常仅适用于少量图片；或使用内存 dict 记录路径映射）
2. 文件存在 → 返回图片二进制流（Content-Type 根据扩展名自动判断）
3. 文件不存在 → `{"code": 1002, "message": "image not found", "data": null}`
4. 安全防护：验证 image_id 不包含 `../`、`..\\` 等路径遍历字符

使用 `Depends(deps.verify_api_key)` 认证。

#### 4. data_retention.py — 数据保留定时任务

实现 `cleanup_expired_data()` 同步函数（参考 `docs/2_vps-deployment.md` §2.4）。

逻辑：
1. 使用 `SessionLocal` 直接创建数据库会话（独立于 FastAPI 请求上下文）
2. 步骤 1：聚合 `DATA_RETENTION_SENSOR_DAYS`（默认 30）天前的 sensor_snapshot 数据到 sensor_daily_aggregation，使用 ON CONFLICT (device_id, agg_date) DO NOTHING
3. 步骤 2：删除已聚合的 sensor_snapshot 原始明细
4. 步骤 3：删除 `DATA_RETENTION_CONTROL_DAYS`（默认 90）天前的 control_logs 数据
5. 事务性：全部成功则 commit，异常则 rollback
6. 日志记录清理结果

设计决策：
- 定义为普通同步函数（非 async def），内部使用同步 SQLAlchemy 调用（SessionLocal）
- 在 APScheduler 中配置时使用 ThreadPoolExecutor，避免阻塞事件循环
- 后续在 main.py 的 startup 事件中通过 APScheduler 注册定时任务（当前仅实现函数逻辑，定时注册在后续 Docker/启动脚本子任务中完成）

#### 5. router.py 修改

在 `api_router` 中注册 advisory 和 image 子路由，顺序放在 command 之后：

```python
from app.api.v1.advisory import router as advisory_router
from app.api.v1.image import router as image_router

api_router.include_router(advisory_router)
api_router.include_router(image_router)
```

#### 6. schemas/__init__.py 修改

添加新 Schema 导入和导出。在现有 `__all__` 列表中新增。

### Schema 定义

需要新建的 Pydantic Schema（定义在对应 API 文件中或统一位置）：

**AdvisoryResponse**（在 advisory.py 中就地定义或放在 schemas/ 下）：
```python
class LatestDetection(BaseModel):
    crop_type: str
    disease_type: str
    severity: str
    severity_code: int
    confidence: Optional[float]
    timestamp: datetime
    model_config = {"from_attributes": True}

class CurrentEnv(BaseModel):
    temperature: Optional[Decimal]
    humidity: Optional[Decimal]
    light: Optional[int]
    co2: Optional[int]

class EnvDiseaseLinkage(BaseModel):
    risk_level: str
    matched_conditions: list[str]
    recommendation: str

class AdvisoryAction(BaseModel):
    action: str
    description: str
    auto_action_triggered: bool
    auto_action: Optional[str]

class AdvisoryResponseData(BaseModel):
    latest_detection: Optional[LatestDetection] = None
    current_env: Optional[CurrentEnv] = None
    env_disease_linkage: Optional[EnvDiseaseLinkage] = None
    advisory: Optional[AdvisoryAction] = None
```

**ImageUploadResponse**（在 image.py 中就地定义）：
```python
class ImageUploadResponse(BaseModel):
    image_id: str
    image_path: str
    file_size: int
    uploaded_at: datetime
```

## 选择理由

T5 实现了 IoTDA 数据接收管道（含 ai/report 联动分析触发点），T6 完成了 disease/device/command 的核心查询端点。当前剩余需要实现的 API 端点和服务包括 advisory（含联动分析决策引擎）、image（图片上传/获取）、data_retention（后台定时任务）。这三者都属于"完成剩余 API/服务"这一关注点，且对已有代码的修改模式相同（注册路由 + 导出 Schema），combined 为一个子任务可以避免碎片化。

Advisory 服务是业务最复杂的部分——需要实现基于病虫害类型 × severity_code × 环境条件的决策规则矩阵（12 条规则），这是整个系统的核心智能逻辑。Image 端点是唯一使用 multipart/form-data 文件上传模式的端点。Data_retention 是定时后台任务，实现简单但需要与 APScheduler 集成。

## 任务上下文

- **advisory_service 决策引擎参考**：`docs/1_system_architecture.md` §2.4 决策规则矩阵（12 条规则，覆盖 rust/powdery_mildew/anthracnose/leafhopper 四种病虫害 × 三个严重等级 × 环境触发条件）
- **advisory API 响应格式参考**：`docs/1_system_architecture.md` §4.6.1
- **image API 参考**：`docs/1_system_architecture.md` §4.7（上传/获取/存储策略）
- **data_retention 参考**：`docs/2_vps-deployment.md` §2.4（完整实现代码，可作为直接模板）
- **DiseaseRecord 模型**已含 linkage_risk_level 和 linkage_detail 字段（在 `server/app/models/disease.py`）
- **config.py**已配置 ADVISORY_WINDOW_MINUTES、IMAGE_STORAGE_PATH、DATA_RETENTION_SENSOR_DAYS、DATA_RETENTION_CONTROL_DAYS
- **router.py**位于 `server/app/api/router.py`，当前注册了 iotda/sensor/disease/device/command 五个子路由

## 已有产出上下文

- server/app/ 下已有完整的应用骨架：models/（5 个 ORM 模型）、schemas/（common/sensor/disease/command/device）、services/（sensor_service/iotda_client/command_service/disease_service）、api/v1/（iotda/sensor/disease/device/command）
- main.py 已配置 CORS 中间件、健康检查端点、生命周期事件
- router.py 已注册 5 个子路由共 12 条 API 端点
- config.py 已含所有必要配置项（包括 advisory/image/retention 相关配置）
- 已有的服务层模式：函数式风格（模块级函数，接收 db: Session 参数）、API 端点统一使用 Depends(deps.verify_api_key) 认证和 Depends(get_db) 注入会话
