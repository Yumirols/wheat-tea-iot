# 执行报告（v7）

## 概述

实现了防治建议（Advisory）联动分析决策引擎及其 API 端点、图片上传管理 API 端点、以及数据保留定时任务。共创建 4 个新文件，修改 2 个已有文件。

## 产出清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 新建 | `server/app/services/advisory_service.py` | 联动分析决策引擎，包含 get_advisory / evaluate_linkage / generate_advisory 三个核心函数 |
| 新建 | `server/app/api/v1/advisory.py` | 防治建议 API 端点（GET /api/v1/advisory），含 Pydantic Schema 就地定义 |
| 新建 | `server/app/api/v1/image.py` | 图片上传与获取 API 端点（POST /api/v1/image/upload, GET /api/v1/image/{image_id}），含 Pydantic Schema 就地定义 |
| 新建 | `server/app/services/data_retention.py` | 数据保留定时任务（cleanup_expired_data 同步函数） |
| 修改 | `server/app/api/router.py` | 注册 advisory 和 image 子路由（include_router），顺序放在 command 之后 |
| 修改 | `server/app/schemas/__init__.py` | 添加新 Schema 导出：LatestDetection, CurrentEnv, EnvDiseaseLinkage, AdvisoryAction, AdvisoryResponseData, ImageUploadResponse |

## 执行过程

### 1. advisory_service.py — 联动分析决策引擎

实现了三个核心函数：

**get_advisory()**：根据时间窗口查询最新的病虫害检测记录和环境传感器数据，依次调用 evaluate_linkage 和 generate_advisory。时间窗口计算支持两种方式：直接传入 start/end，或通过 window_minutes 计算（默认 60 分钟）。窗口内无检测记录时所有字段返回 None。同时将联动分析结果（linkage_risk_level, linkage_detail）持久化回写 disease_records 表。

**evaluate_linkage()**：根据病虫害类型选择相关的环境因子进行评估：
- rust（锈病）：湿度 > 85%、温度 15-25℃
- powdery_mildew（白粉病）：湿度 50%-80%
- anthracnose（茶炭疽病）：湿度 > 80%、温度 20-30℃
- leafhopper（茶小绿叶蝉）：温度 20-30℃

根据匹配条件数量（0/1/2+）确定风险等级 low/medium/high，生成中文推荐建议。通过 DISEASE_CONFIG 字典集中管理各病虫害类型的配置参数，便于扩展。

**generate_advisory()**：基于设计文档的决策规则矩阵（12 条规则）：
- severity_code=1：一律 manual_inspect，给出监测建议
- severity_code=2：检查环境触发条件，触发则给出具体药剂建议（rust→三唑酮, powdery_mildew→嘧菌酯, anthracnose→苯醚甲环唑, leafhopper→吡虫啉），否则 manual_inspect
- severity_code=3：auto_action_triggered=True, auto_action="spray ON"

### 2. advisory.py — 防治建议 API 端点

- **GET /api/v1/advisory**：支持 device_id、start、end、window_minutes 查询参数
- 使用 Depends(deps.verify_api_key) 认证，Depends(get_db) 注入会话
- Pydantic Schema（LatestDetection, CurrentEnv, EnvDiseaseLinkage, AdvisoryAction, AdvisoryResponseData）在文件中就地定义
- 无检测记录时返回 code=0 的完整空结构（data 内各字段为 null）

### 3. image.py — 图片上传与获取 API 端点

- **POST /api/v1/image/upload**：multipart/form-data 上传，验证文件类型（仅 jpg/png）、大小限制 10MB
  - 生成 image_id 格式：img_{yyyyMMdd}_{HHmmss}_{3位随机}
  - 按日期组织存储：{IMAGE_STORAGE_PATH}/YYYY/MM/DD/{image_id}.{ext}
  - 可选关联 disease_record_id，更新对应记录的 image_path
  - 错误处理：文件类型不支持→422 code=1004，文件过大→422 code=1005，disease_record 不存在→404 code=1001
- **GET /api/v1/image/{image_id}**：返回图片二进制流，Content-Type 根据文件扩展名自动判断
  - 使用内存 dict 缓存 image_id→绝对路径映射，服务重启后首次访问降级至目录扫描
  - 路径遍历安全防护（检查 ../、..\\ 等字符）
  - 图片不存在→404 code=1002
- Pydantic Schema（ImageUploadResponse）在文件中就地定义
- 使用 Depends(deps.verify_api_key) 认证，upload 端点额外使用 Depends(get_db)

### 4. data_retention.py — 数据保留定时任务

实现 cleanup_expired_data() 同步函数：
- 步骤 1：聚合 DATA_RETENTION_SENSOR_DAYS（默认 30）天前的 sensor_snapshot 数据到 sensor_daily_aggregation
- 步骤 2：删除已聚合的 sensor_snapshot 原始明细
- 步骤 3：删除 DATA_RETENTION_CONTROL_DAYS（默认 90）天前的 control_logs 数据
- 事务性：全部成功则 commit，异常则 rollback
- 日志记录各步骤清理行数和最终状态
- 使用 SessionLocal 直接创建会话（独立于 FastAPI 请求上下文），定义为同步函数

### 5. router.py 修改

在 api_router 中注册 advisory 和 image 子路由，顺序放在 command 之后。

### 6. schemas/__init__.py 修改

从 endpoint 模块导入新 Schema 类并加入 __all__ 列表。

### 关键设计决策

1. **Service 层返回 dict 而非 Pydantic 对象**：与现有 command_service.py 模式一致，advisory_service 返回简单 dict，API 层直接序列化。避免了 Pydantic model 在 service 层引入的复杂类型依赖。
2. **配置集中管理**：病虫害配置（DISEASE_CONFIG）采用字典数据结构，以 disease_type 为键，统一管理名称映射、各等级描述、触发条件和药剂建议。新增病虫害类型只需添加一条字典条目。
3. **Schema 就地定义**：Advisory 和 Image 的 Pydantic Schema 定义在 API 端点文件中（而非单独 schema 文件），与现有项目模式一致。schemas/__init__.py 从 API 模块导入并重新导出。
4. **data_retention 同步设计**：定义为同步函数配合 ThreadPoolExecutor 运行，采用原生的 SQLAlchemy SessionLocal 而非依赖 FastAPI 注入，确保在 APScheduler 中运行时不会阻塞事件循环。

## 偏差说明

无
