# 任务指令（v4）

## 动作
NEW

## 任务描述

清零所有剩余 Mypy 类型错误（共 10 处，涉及 4 个文件），完成 P4 收官阶段重构。

具体要求：

### 1. `server/app/models/disease.py` — 为剩余字段补全 Mapped 注解

当前 `DiseaseRecord` 模型中仅 `image_path` 有 `Mapped[str]` 注解。以下字段同样被服务层代码作为 Python 属性访问（赋值或读取），但缺少 `Mapped[...]` 注解，导致 Mypy 将它们的类型错误推导为 `Column[...]`：

- `crop_type = Column(String(32), nullable=False)`
- `disease_type = Column(String(64), nullable=False)`
- `confidence = Column(Numeric(4, 3))`
- `severity = Column(String(16), nullable=False)`
- `severity_code = Column(SmallInteger, nullable=False)`
- `linkage_risk_level = Column(String(16))`
- `linkage_detail = Column(String(512))`
- `action_taken = Column(String(128))`

对上述字段添加 `Mapped[...]` 类型批注，并使用 `mapped_column(...)` 替代 `Column(...)`，方法同 P3 (T3) 对 `image_path` 的处理。注意 `from sqlalchemy.orm import Mapped, mapped_column` 已在 P3 时添加，无需重复。

此修改将自动消除 `advisory_service.py` 中的 4 处 mypy 错误（L252/L271/L304/L356），因为这些错误的根因是 `detection.disease_type` 等属性被推导为 `Column[str]` 而非 `str`。

### 2. `server/app/services/data_retention.py` — 添加 CursorResult 类型注解

3 处 `db.execute()` 返回结果的 `.rowcount` 调用（L75/L91/L108）被 Mypy 报错，因为 `Result[Any]` 没有 `rowcount` 属性。

修复方式：
- 在导入中新增 `from sqlalchemy import CursorResult`
- 对三处 `db.execute()` 结果添加 `: CursorResult` 类型注解：
  ```python
  result_agg: CursorResult = db.execute(...)
  result_delete_sensor: CursorResult = db.execute(...)
  result_delete_control: CursorResult = db.execute(...)
  ```

注意：`data_retention.py` 中所有 `db.execute()` 传入的都是 `text(...)` SQL 表达式，执行后返回 `CursorResult`，有 `.rowcount` 属性。添加注解仅用于满足 Mypy 类型推导，不影响运行时行为。

### 3. `server/app/services/disease_service.py` — 修复 crop_counts 类型（L103-L104）

当前代码：
```python
crop_counts = dict(
    db.query(
        DiseaseRecord.crop_type,
        func.count(DiseaseRecord.id),
    )
    .filter(*filters)
    .group_by(DiseaseRecord.crop_type)
    .all()
)
```

Mypy 报两个错误：
- L103: Need type annotation for "crop_counts"
- L104: `list[Row[tuple[str, int]]]` incompatible with `dict()`

修复方式：改用显式字典推导式并添加类型注解：
```python
rows = (
    db.query(
        DiseaseRecord.crop_type,
        func.count(DiseaseRecord.id),
    )
    .filter(*filters)
    .group_by(DiseaseRecord.crop_type)
    .all()
)
crop_counts: dict[str, int] = {row.crop_type: row[1] for row in rows}
```

注意检查后续代码对 `crop_counts.get(disease_type)` 的调用是否兼容新的 `dict[str, int]` 类型。

### 4. `server/app/api/v1/sensor.py` — 修复 data 变量类型（L45）

当前代码：
```python
if device_id:
    data = (
        SensorSnapshotRead.model_validate(snapshots[0]).model_dump()
        if snapshots
        else None
    )
else:
    data = [
        SensorSnapshotRead.model_validate(s).model_dump()
        for s in snapshots
    ]
```

Mypy 错误：`Incompatible types in assignment (expression has type "list[dict[str, Any]]", variable has type "dict[str, Any] | None")`

修复方式：为 `data` 变量添加覆盖两种分支的类型注解：
```python
data: dict[str, Any] | list[dict[str, Any]] | None
```
或使用：
```python
data: Any
```
（根据团队风格偏好选择。推荐使用前者，类型更精确。）

同时需要补全 `Any` 的导入（如果文件中尚未导入 `typing.Any`）。

### 5. 最终验证

确保以下命令均成功：
- `python -m mypy server/app/ --ignore-missing-imports` — **零错误**
- `python -m ruff check server/` — **零警告**
- `pytest server/tests/ -x -q` — **全部通过**

## 选择理由

T3（P3 实体层 Column 类型批注重构）已 PASSED。P4 是重构计划的收官阶段，清零所有剩余 mypy 错误后，整个 `server/` 目录即可在无 `continue-on-error` 的情况下通过 CI 管道，任务目标全部达成。所有 10 处错误均为简单类型注解添加或重构，不涉及业务逻辑变更。

## 任务上下文

### 当前 mypy 错误清单（10 处，P4 范围）

```
server\app\services\data_retention.py:75: error: "Result[Any]" has no attribute "rowcount"  [attr-defined]
server\app\services\data_retention.py:91: error: "Result[Any]" has no attribute "rowcount"  [attr-defined]
server\app\services\data_retention.py:108: error: "Result[Any]" has no attribute "rowcount"  [attr-defined]
server\app\services\disease_service.py:103: error: Need type annotation for "crop_counts"
server\app\services\disease_service.py:104: error: Argument 1 to "dict" has incompatible type "list[Row[tuple[str, int]]]"; expected "Iterable[tuple[Never, Never]]"
server\app\services\advisory_service.py:252: error: Incompatible types in assignment (expression has type "str", variable has type "Column[str]")
server\app\services\advisory_service.py:271: error: No overload variant of "get" of "dict" matches argument type "Column[str]"
server\app\services\advisory_service.py:304: error: Argument 1 to "_build_recommendation" has incompatible type "Column[str]"; expected "str"
server\app\services\advisory_service.py:356: error: No overload variant of "get" of "dict" matches argument type "Column[str]"
server\app\api\v1\sensor.py:45: error: Incompatible types in assignment (expression has type "list[dict[str, Any]]", variable has type "dict[str, Any] | None")
```

### 根因分析

| 文件 | 错误数 | 根因 | 修复方式 |
|------|--------|------|----------|
| advisory_service.py | 4 | disease.py 缺少 Mapped 注解 | 补全 disease.py 字段注解 |
| data_retention.py | 3 | CursorResult 缺少类型注解 | 添加 CursorResult 注解 |
| disease_service.py | 2 | dict 缺少类型注解 + Row 不兼容 | dict comprehension + 类型注解 |
| sensor.py | 1 | 变量跨分支类型不一致 | 添加 Union 类型注解 |

### advisory_service.py 错误根因详解

`advisory_service.py` 中 L268 定义了 `disease_type = detection.disease_type`。由于 `disease.py` 中 `disease_type` 标注为 `Column(String(64))` 而非 `Mapped[str]`，Mypy 将 `detection.disease_type` 推导为 `Column[str]` 类型。导致：

- L271: `DISEASE_CONFIG.get(disease_type)` — `dict.get()` 的 key 被推导为 `Column[str]` 而非 `str`
- L304: `_build_recommendation(disease_type, ...)` — 传参类型 `Column[str]` 不匹配 `str`
- L356: 同上 L271 的 `get()` 问题
- L252: `latest_detection.linkage_detail = str(linkage)` — 赋值 `str` 给 `Column[str]` 不兼容

**关键结论**：修复 `disease.py` 中这些字段的 `Mapped[...]` 注解后，advisory_service.py 的 4 处错误将自动消失，无需修改 advisory_service.py 本身。

### 涉及的模型字段（disease.py）

```python
crop_type: Mapped[str] = mapped_column(String(32), nullable=False)
disease_type: Mapped[str] = mapped_column(String(64), nullable=False)
confidence: Mapped[Optional[Decimal]] = mapped_column(Numeric(4, 3))  # 注意可为空
severity: Mapped[str] = mapped_column(String(16), nullable=False)
severity_code: Mapped[int] = mapped_column(SmallInteger, nullable=False)
linkage_risk_level: Mapped[Optional[str]] = mapped_column(String(16))
linkage_detail: Mapped[Optional[str]] = mapped_column(String(512))
action_taken: Mapped[Optional[str]] = mapped_column(String(128))
```

### data_retention.py 涉及的代码行

```python
# L72-L77
result_agg = db.execute(text(...))  # → result_agg: CursorResult
logger.info("...", result_agg.rowcount, ...)

# L80-L93
result_delete_sensor = db.execute(text(...))  # → result_delete_sensor: CursorResult
logger.info("...", result_delete_sensor.rowcount, ...)

# L97-L110
result_delete_control = db.execute(text(...))  # → result_delete_control: CursorResult
logger.info("...", result_delete_control.rowcount, ...)
```

## 已有产出上下文

- **P1 (T1) PASSED**: Ruff zero warnings — 34 处自动修复 + 5 处手动修复，`ruff check server/` 零警告
- **P2 (T2) PASSED**: iotda.py None safety — 3 处 Mypy union-attr 修复，iotda.py 零 mypy 错误
- **P3 (T3) PASSED**: SQLAlchemy Column type annotations — control.py (last_seen, online) 和 disease.py (image_path) 添加 Mapped 注解
- **当前 mypy 状态**: 10 处剩余错误，全部属于 P4 范围
- **当前 Ruff 状态**: 零警告
- **当前测试状态**: 37 passed, 38 skipped, 0 failed
