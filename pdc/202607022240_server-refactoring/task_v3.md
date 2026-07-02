# 任务指令（v3）

## 动作
NEW

## 任务描述
在实体层（`app/models/`）重构 SQLAlchemy Column 类型批注，消除 Mypy 报告的 Column 赋值类型冲突。具体包括：

1. **修改 `server/app/models/control.py`** — 在 `Device` 类中对 `last_seen` 和 `online` 字段添加 `Mapped[...]` 类型批注：
   - `from sqlalchemy.orm import Mapped` 导入
   - `last_seen: Mapped[datetime] = Column(DateTime)`
   - `online: Mapped[bool] = Column(Boolean, default=False)`

2. **修改 `server/app/models/disease.py`** — 在 `DiseaseRecord` 类中对 `image_path` 字段添加 `Mapped[...]` 类型批注：
   - `from sqlalchemy.orm import Mapped` 导入
   - `image_path: Mapped[str] = Column(String(512))`
   - 或 `image_path: Mapped[Optional[str]] = Column(String(512))`（如果该字段可为空）

3. **验证**：
   - `python -m mypy server/app/services/sensor_service.py server/app/api/v1/image.py` — 零 Column 相关错误
   - `python -m mypy server/app/ --ignore-missing-imports` — 检查是否引入了新的 mypy 错误
   - `pytest server/tests/ -x -q` — 全部测试通过

## 选择理由
T2（P2 iotda.py None 安全修复）已 PASSED。P3 是重构计划中定义的下一阶段，修复 mypy 在 `sensor_service.py:85-86` 和 `image.py:144` 报告的 3 处 Column 赋值类型冲突错误。这些错误的根因在模型层的类型定义不完整，通过在模型层添加 `Mapped[...]` 类型批注即可解除，无需修改服务层代码。

## 任务上下文
当前 mypy 错误（P3 范围）：
```
server\app\services\sensor_service.py:85: error: Incompatible types in assignment (expression has type "datetime", variable has type "Column[datetime]")
server\app\services\sensor_service.py:86: error: Incompatible types in assignment (expression has type "bool", variable has type "Column[bool]")
server\app\api\v1\image.py:144: error: Incompatible types in assignment (expression has type "str", variable has type "Column[str]")
```

涉及的模型字段：
- `Device.last_seen`（`server/app/models/control.py:43`）：`last_seen = Column(DateTime)`
- `Device.online`（`server/app/models/control.py:44`）：`online = Column(Boolean, default=False)`
- `DiseaseRecord.image_path`（`server/app/models/disease.py:32`）：`image_path = Column(String(512))`

参照文档 `docs/3_server-refactoring-plan.md#31-sqlalchemy-属性赋值类型冲突` 方案 B（Mapped/mapped_column），使用 `Mapped[...]` 类型批注叠加在现有 `Column(...)` 上，保持运行时行为不变。

## 已有产出上下文
- P1 完成：Ruff 零警告
- P2 完成：iotda.py zero mypy errors, 全部测试通过
- 当前 mypy 总计 13 处错误分布在 6 个文件中
