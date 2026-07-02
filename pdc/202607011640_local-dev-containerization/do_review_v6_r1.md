# 执行审查报告（v6 r1）

## 审查结果
REJECTED

## 发现

### 1. [一般] `get_disease_stats` 分组聚合实现存在显著性能缺陷

**问题描述**  
`server/app/services/disease_service.py` 中 `get_disease_stats()` 函数的 `by_crop`、`by_severity`、`by_disease` 三种分组统计使用了低效的 ID 子查询模式：

```python
# 当前实现：先 materialize 所有记录，再通过 id.in_(...) 做分组
.filter(DiseaseRecord.id.in_([r.id for r in query.all()]))
```

具体流程：
1. `query.all()` 将所有匹配行（含全部字段）加载到 Python 内存中
2. 提取 ID 列表后，再发起三次独立的 GROUP BY 查询，各带一个 `IN (...)` 条件

**为什么是问题**
- 与任务描述不符。任务要求 "使用 `db.query(func.count(...)).group_by(...)` 分组聚合"，当前实现不是直接对查询条件分组，而是绕道先物化全量 ID 再 IN 查询。
- 在生产环境（1 vCPU / 1 GB RAM）下，当 `disease_records` 表数据量较大时，`query.all()` 会将大量记录加载到内存中，额外消耗本已有限的 RAM。三次 `IN (...)` 查询在大数据集下也会显著变慢。
- 已有 `sensor_service.py` 作为参考模式，其同类分组查询直接对查询条件分组，未使用此模式；当前实现偏离了服务层已建立的模式。

**期望的修正方向**  
直接将时间范围过滤条件应用到每个聚合查询中，避免先物化 ID。例如：

```python
filters = []
if start:
    filters.append(DiseaseRecord.timestamp >= start)
if end:
    filters.append(DiseaseRecord.timestamp <= end)

crop_counts = dict(
    db.query(DiseaseRecord.crop_type, func.count(DiseaseRecord.id))
    .filter(*filters)
    .group_by(DiseaseRecord.crop_type)
    .all()
) if total_detections > 0 else {}
```

severity 和 disease 的分组统计同理。这样无需物化中间结果，直接利用数据库的分组聚合能力，且与任务描述一致。

## 其他说明

除上述问题外，其余产出在功能正确性、任务覆盖度、代码风格一致性方面均符合要求：
- `DeviceRead` Schema 字段完整，`model_config` 配置正确
- `get_disease_records` 多条件筛选和分页逻辑正确
- `get_heatmap_data` 返回结构符合规范
- `create_command` 设备在线检查、IoTDA 调用、日志记录链路完整，离线/失败处理正确
- `get_command_logs` 筛选和分页逻辑正确
- 三个 API 路由文件（disease/device/command）端点定义、参数约束、响应格式、认证依赖均正确
- `schemas/__init__.py` 和 `router.py` 修改正确，导入链完整
- 12 条路由完整注册，无遗漏
