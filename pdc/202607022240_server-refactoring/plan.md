# 任务计划

任务描述：对 server/ 目录进行治理重构，彻底清零 Ruff 和 Mypy 报告的代码质量警示，使 CI 管道能够在不设置 continue-on-error 的情况下成功运行。
工作目录：E:\dev\wheat-tea-iot\pdc\202607022240_server-refactoring

---

## R1 NEW 清理 Ruff 所有警告 [ID: T1]

---

## R2 PASSED 清理 Ruff 所有警告 [ID: T1]
结果：Ruff 自动修复 34 处（F401+F541）+ 手动修复 5 处（F841），`ruff check server/` 零警告，37 passed, 38 skipped, 0 failures。
检查：PASSED — 所有检查项通过。

## R2 NEW 修复 iotda.py 及 API 层面 None 安全守护 [ID: T2]
任务：修复 `app/api/v1/iotda.py` 中 L123/L200/L281 的 `dict[str, Any] | None` 未安全解包问题，加入安全类型守卫或默认值空字典。验证 Mypy 在 iotda.py 上零错误，且 `pytest tests/` 全部通过。

选择理由：P1 已完成。P2 是下一个自然步骤，低风险，修复后清除 3 处 mypy 报错，使该文件通过类型检查。

---

## R3 PASSED 修复 iotda.py 及 API 层面 None 安全守护 [ID: T2]
结果：使用 `(header or {}).get("device_id")` 默认值空字典模式，修复 iotda.py L123/L200/L281 三处 Mypy union-attr 错误。iotda.py 零 mypy 错误，pytest 37 passed, 38 skipped, 0 failures。
检查：PASSED — L123/L200/L281 修改正确，未引入额外变更，Mypy 零错误，全部测试通过。

## R3 NEW 实体层 SQLAlchemy Column 类型批注重构 [ID: T3]
任务：在 `app/models/control.py(Device)` 和 `app/models/disease.py(DiseaseRecord)` 中，对 `last_seen`、`online`、`image_path` 等被服务层赋值的 Column 字段添加 `Mapped` 类型批注，消除 `sensor_service.py:85-86` 和 `image.py:144` 的 Column 赋值类型冲突错误。验证相关文件 Mypy 零错误且全部测试通过。
选择理由：T2 已 PASSED。P3 是下一自然阶段，修复 3 处 mypy Column 赋值冲突错误。
上下文：涉及模型层（control.py, disease.py）的 Column 定义添加 `Mapped[...]` 类型批注，不改变实际运行时行为。服务层的赋值代码无需修改，mypy 将自动正确推导赋值类型。

---

## R4 PASSED 实体层 SQLAlchemy Column 类型批注重构 [ID: T3]
结果：在 control.py 中用 Mapped[datetime]/Mapped[bool] 注解 last_seen/online，在 disease.py 中用 Mapped[str] 注解 image_path，均使用 mapped_column() 替代 Column()。3 处 Column 赋值类型冲突清零，全量 mypy 10 处错误均为 P4 范围，未引入新错误。pytest 37 passed, 38 skipped, 0 failed。
检查：PASSED — 修改正确，Mypy 目标文件零错误，未引入新错误，全部测试通过。

## R4 NEW 修复剩余 Mypy 类型错误（P4 收官） [ID: T4]
任务：清零全部剩余 10 处 mypy 错误，涉及 4 个文件：
1. `disease.py` — 为剩余未被 Mapped 注解的字段（crop_type, disease_type, severity_code, linkage_detail 等）添加 Mapped[...] 批注，消除 advisory_service.py 中 4 处 Column 传参错误（L252/L271/L304/L356）
2. `data_retention.py` — 为 3 处 db.execute() 结果添加 CursorResult 类型注解，解除 rowcount 属性推导错误
3. `disease_service.py` — 修复 crop_counts 类型注解与 Row 转 dict 兼容问题
4. `sensor.py` — 修复 data 变量跨分支类型不一致

验证：`mypy server/app/ --ignore-missing-imports` 零错误，`pytest server/tests/ -x -q` 全部通过。

选择理由：T3 已 PASSED。P4 是重构计划的收官阶段，清零 all 剩余 mypy 错误后 CI 管道可在无 continue-on-error 下成功运行。

---

## R5 PASSED 修复剩余 Mypy 类型错误（P4 收官） [ID: T4]
结果：清零全部 10 处 mypy 错误，涉及 4 个文件：disease.py 补全 8 个字段 Mapped 注解、data_retention.py 添加 3 处 CursorResult 注解（含 cast）、disease_service.py 重构 crop_counts 类型、sensor.py 修复 data 变量 Union 类型。最终验证：mypy 零错误、ruff 零警告、pytest 37 passed, 38 skipped, 0 failures。
检查：PASSED — 所有 8 项检查均通过，全部 10 处 mypy 错误已清零，未引入新错误，测试全部通过。
