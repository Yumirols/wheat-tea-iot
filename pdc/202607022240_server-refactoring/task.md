# FarmEye Guard Server — 静态检查与代码重构

## 目标

对 `server/` 目录进行治理重构，彻底清零 Ruff 和 Mypy 报告的代码质量警示，使 CI 管道能够在不设置 `continue-on-error` 的情况下成功运行。

## 任务来源

文档：`docs/3_server-refactoring-plan.md`

## 四个重构阶段

### P1: 清理 Ruff 所有警告
- 运行 `ruff check server/ --fix` 自动修复冗余 f-string 前缀 (F541)
- 手动清理已赋值但未使用的本地变量 (F841)
- 验证：`ruff check server/` 零警告

### P2: 修复 iotda.py 及 API 层面的 None 安全守护
- 修复 `app/api/v1/iotda.py` 中可空字典/可选类型的未安全解包问题（行 123, 200, 281）
- 加入安全类型守卫判断或使用默认值空字典
- 验证：`pytest tests/` 全部通过

### P3: 在 app/models/ 实体层重构 SQLAlchemy Column 类型批注
- 修复 SQLAlchemy 属性赋值类型冲突（如 `last_seen`, `online`, `image_path`）
- 使用 `Mapped/mapped_column` 或类型注解覆盖
- 涉及文件：`app/models/device.py`, `app/api/v1/image.py`, `app/services/sensor_service.py`
- 验证：`pytest tests/integration/` 全部通过

### P4: 修复 advisory_service.py 字典 key 及 CursorResult 类型映射
- 修复 `app/services/advisory_service.py:271 & 356` 字典 key 的 Column 传参错误
- 修复 `app/services/data_retention.py:75,91,108` 的 CursorResult 类型映射
- 修复 `app/services/disease_service.py:103 & 104` 的 Row 转 dict 兼容
- 验证：全部测试通过

## 约束
- 不改变业务逻辑
- 每轮完成后确认该轮次目标问题已被清理、测试依然通过
- 遵循 PDC 循环：每轮实现一个子任务
