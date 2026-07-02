# FarmEye Guard Server — 静态检查与代码重构方案

> **文档版本**: v1.0
> **编写依据**: Ruff (39 处警告/错误) 与 MyPy (16 处类型错误) 静态分析报告
> **目标**: 彻底清零代码质量警示，使 CI 管道能够在不设置 `continue-on-error` 的情况下成功运行

---

## 1. 概述

FarmEye Guard 后端（`server`）已通过全部功能性测试（单元测试、集成测试、E2E 联调）。为了提升代码库的健壮性、可读性并强化 CI 门禁，我们需要针对 **Ruff（代码规范检测）** 和 **Mypy（静态类型检查）** 报告的存量问题制定代码重构方案。

---

## 2. Ruff 规范重构方案

Ruff 主要检测出代码风格及无用变量等问题，共 **39 处**，均可在不改变业务逻辑的前提下快速清理。

### 2.1 冗余的 f-string 前缀 (F541)
* **问题描述**：字符串字面量前加了 `f` 前缀，但字符串内不包含任何花括号 `{}` 占位符。
* **主要分布**：`server/tests/integration_run.py` 中的 `print()` 调用。
* **重构示例**：
  ```diff
  - print(f"[FAIL] advisory is null/empty")
  + print("[FAIL] advisory is null/empty")
  ```
* **解决办法**：使用编辑器全局搜索正则 `f"[^\{\n]*"` 并移除 `f`，或者直接运行 Ruff 自动修复：
  ```bash
  ruff check server/ --fix
  ```

### 2.2 已赋值但未使用的本地变量 (F841)
* **问题描述**：在函数内部定义并赋值了变量，但该变量在后续逻辑中未被读取。
* **主要分布**：
  * `tests/integration_run.py:271` & `318` 的 `timestamp`
  * `tests/test_iotda_webhook.py:138` 的 `mock_db_session`
  * `tests/test_iotda_webhook.py:142` 的 `original_add`
* **重构示例**：
  ```diff
  - timestamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
  - payload = { ... }
  + payload = { ... } # 直接移除无用变量 timestamp
  ```
* **解决办法**：手动删除或注释掉这些无用变量。

---

## 3. Mypy 类型重构方案

Mypy 报告的 **16 处** 类型错误集中在 SQLAlchemy 模型属性赋值、可选类型（Optional）未解包判断，以及 SQLAlchemy 2.0 API 类型推导上。

### 3.1 SQLAlchemy 属性赋值类型冲突
* **问题描述**：Mypy 静态分析器将模型中的字段识别为 `Column[Type]`，因而在给其赋值 Python 标准类型（如 `datetime` 或 `bool`）时报错。
* **主要分布**：
  * `app/services/sensor_service.py:86` (`device.last_seen = datetime.utcnow()`)
  * `app/services/sensor_service.py:87` (`device.online = True`)
  * `app/api/v1/image.py:144` (`record.image_path = ...`)
* **解决办法**：
  * **方案 A（类型注解覆盖）**：在定义 ORM 模型类属性时，明确其类型注解（Type Annotation），例如在 `app/models/device.py` 中：
    ```python
    # 显式声明 Python 类型，使 mypy 得以识别
    last_seen: datetime = Column(DateTime)
    online: bool = Column(Boolean, default=False)
    ```
  * **方案 B（使用 Mapped/mapped_column，推荐）**：将模型升级为 SQLAlchemy 2.0 声明风格，完全兼容 Mypy：
    ```python
    from sqlalchemy.orm import Mapped, mapped_column
    
    last_seen: Mapped[datetime] = mapped_column(DateTime)
    online: Mapped[bool] = mapped_column(Boolean, default=False)
    ```

### 3.2 可空字典与可选类型的未安全解包
* **问题描述**：从 API 返回或 JSON 中获取的变量被推导为 `dict | None`，直接调用 `.get()` 会导致 mypy 报错。
* **主要分布**：`app/api/v1/iotda.py:123`, `200`, `281`
* **重构示例**：
  ```python
  # 错误：Item "None" of "dict[str, Any] | None" has no attribute "get"
  body = payload.get("notify_data").get("body")
  ```
* **正确做法**：进行安全类型守卫判断或使用默认值空字典：
  ```python
  notify_data = payload.get("notify_data")
  if notify_data is not None:
      body = notify_data.get("body")
  else:
      body = None
  
  # 或者：
  body = (payload.get("notify_data") or {}).get("body")
  ```

### 3.3 字典查询 Key 的类型不匹配
* **问题描述**：使用 SQLAlchemy Column 对象直接去 `dict.get()` 获取内容，导致类型重载失效。
* **主要分布**：`app/services/advisory_service.py:271` & `356`
* **重构示例**：
  ```python
  # 错误：advisory.get(DiseaseRecord.crop_type) - 传入的是 Column，并非 str
  advisory = crop_advisories.get(detection.crop_type)
  ```
* **正确做法**：确保在字典查询时，查询 Key 为具体的 Python 值（如字符串），而不是数据库字段表达式：
  ```python
  # 确保 detection 实例已被加载，传入其对应属性的值字符串
  advisory = crop_advisories.get(str(detection.crop_type))
  ```

### 3.4 SQLAlchemy 2.0 结果集的 rowcount 属性推导
* **问题描述**：`Result[Any]` 静态声明中没有 `rowcount` 属性，因而 mypy 无法识别。
* **主要分布**：`app/services/data_retention.py:75`, `91`, `108`
* **重构示例**：
  ```python
  # 错误：result = db.execute(...); print(result.rowcount)
  result = db.execute(delete(SensorSnapshot).where(...))
  ```
* **正确做法**：在执行非查询（UPDATE/DELETE）操作时，显式将返回对象声明为 `CursorResult`，从而安全获取 `rowcount`：
  ```python
  from sqlalchemy import CursorResult
  
  result: CursorResult = db.execute(delete(SensorSnapshot).where(...))
  deleted_rows = result.rowcount
  ```

### 3.5 字典类型批注缺失与 Row 的兼容
* **问题描述**：`list[Row]` 无法直接转换到 generic dict。
* **主要分布**：`app/services/disease_service.py:103` & `104`
* **重构示例**：
  ```python
  # 错误写法
  crop_counts = dict(db.execute(select(DiseaseRecord.crop_type, func.count(...))).all())
  ```
* **正确做法**：显式添加字典类型声明，并将结果转换为符合 `dict()` 构造函数要求的元组迭代器：
  ```python
  rows = db.execute(select(DiseaseRecord.crop_type, func.count(...))).all()
  crop_counts: dict[str, int] = {row.crop_type: row[1] for row in rows}
  ```

---

## 4. 重构工作计划

| 阶段 | 任务描述 | 预计工时 | 风险等级 | 验证手段 |
| :--- | :--- | :--- | :--- | :--- |
| **P1** | 清理 Ruff 所有警告，配置全局 `ruff check --fix`。 | 0.5h | 无风险 | `ruff check server/` |
| **P2** | 修复 `iotda.py` 及 API 层面的 `None` 安全守护，避免 `AttributeError`。 | 1.0h | 低风险 | 运行 `pytest tests/` |
| **P3** | 在 `app/models/` 实体层重构 SQLAlchemy Column 类型批注或使用 mapped_column，修复 Mypy 的类型推导报错。 | 2.0h | 中风险（涉及实体层） | 运行 `pytest tests/integration/` |
| **P4** | 修复 `advisory_service.py` 字典 key 的 Column 传参错误，优化数据保留逻辑的 `CursorResult` 类型映射。 | 1.5h | 低风险 | 运行全部测试 |
