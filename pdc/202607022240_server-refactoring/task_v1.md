# 任务指令（v1）

## 动作
NEW

## 任务描述
清理 server/ 目录中所有的 Ruff 代码规范警告。

具体步骤：
1. 运行 `ruff check server/ --fix` 自动修复 F401（未使用导入）和 F541（冗余 f-string 前缀）
2. 手动清理剩余的 5 处 F841（已赋值但未使用的本地变量）：
   - `server/tests/test_iotda_webhook.py:138` — `mock_db_session` 变量赋值后未使用
   - `server/tests/test_iotda_webhook.py:142` — `original_add` 变量赋值后未使用
   - `server/tests/integration_run.py:271` — `timestamp` 变量赋值后未使用
   - `server/tests/integration_run.py:318` — `timestamp` 变量赋值后未使用
3. 验证：运行 `ruff check server/` 应输出零警告

预期产出：
- 修改后的源码文件（自动修复 + 手动删除无用变量）
- `ruff check server/` 输出零警告

## 选择理由
Ruff 修复是无风险的第一步（自动修复为主，手动删除为辅），能快速消除 CI 中的第一道失败门禁。先处理 Ruff 再处理 Mypy，避免同时处理两个检查器的噪音干扰。

## 任务上下文
```
Ruff 当前报告统计:
  18  F401  unused-import (自动修复)
  16  F541  f-string-missing-placeholders (自动修复)
   5  F841  unused-variable (需手动)
---
  39  total (34 auto-fixable)
```

需手动处理的 5 处 F841：
- `test_iotda_webhook.py:138`: `mock_db_session = None` 仅通过局部引用获取，可直接删除该行
- `test_iotda_webhook.py:142`: `original_add = iotda_module.DiseaseRecord` 用于 mock 上下文但后续未使用，可删除
- `integration_run.py:271`: `timestamp = time.strftime(...)` 在定义 payload 之前赋值但未使用，删除该行
- `integration_run.py:318`: 同上，删除 `timestamp` 赋值行

## 已有产出上下文
无。这是重构工作的第一个子任务。
