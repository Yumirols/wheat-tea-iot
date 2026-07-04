# 修复报告（R2 f1）

## 错误摘要

- `entryability/EntryAbility.ets` 存在 7 处 TS1185: Merge conflict marker encountered（行 43, 44, 46, 52, 55, 59）
- 未解决的 git merge conflict 标记（`<<<<<<< Updated upstream` / `=======` / `>>>>>>> Stashed changes`）导致 `PollingManager.resumeAll()` 和 `PollingManager.suspendAll()` 调用被冲突标记包围，tsc 无法解析

## 修复清单

| 文件路径 | 修改类型 | 说明 |
|---------|---------|------|
| `harmony-app/entry/src/main/ets/entryability/EntryAbility.ets` | 修复编译错误 | 移除两处 git merge conflict 标记（`onForeground` 和 `onBackground` 方法体），保留正确的 `PollingManager.resumeAll()` 和 `PollingManager.suspendAll()` 调用 |

## 编译验证

- 修复后 tsc strict 模式检查：**0 errors，pass**
- 共检查 15 个源文件（common 6 + services 8 + entryability 1），无 TS1185 错误
- 测试文件 tsc 检查：**exit 0, pass**（不受影响）
