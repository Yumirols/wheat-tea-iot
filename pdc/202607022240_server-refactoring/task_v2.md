# 任务指令（v2）

## 动作
NEW

## 任务描述
修复 `app/api/v1/iotda.py` 中 3 处 Mypy union-attr 错误（行 123、200、281）：`dict[str, Any] | None` 类型的变量直接调用 `.get()` 时，Mypy 检测出未处理 `None` 分支。

具体步骤：
1. 读取 `app/api/v1/iotda.py`，定位 L123、L200、L281 三处 `payload.get("notify_data").get("body")` 风格的调用
2. 对每处添加安全类型守卫判断或使用默认值空字典：
   ```python
   # 方式一（推荐）：守卫判断
   notify_data = payload.get("notify_data")
   if notify_data is not None:
       body = notify_data.get("body")
   else:
       body = None

   # 方式二：默认值空字典（适用于链式调用简单的情形）
   body = (payload.get("notify_data") or {}).get("body")
   ```
3. 不改变业务逻辑，仅添加类型安全守卫
4. 验证：
   - `python -m mypy app/api/v1/iotda.py` 该文件零错误
   - `pytest server/tests/ -x` 全部通过

预期产出：
- 修改后的 `app/api/v1/iotda.py`，3 处 None 安全守卫添加完毕
- `python -m mypy app/api/v1/iotda.py` 零错误
- `pytest server/tests/ -x` 全部通过

## 选择理由
P1（Ruff 清理）已完成并 PASSED。P2 是下一个步骤，修复 `iotda.py` 中 3 处 mypy 报错，低风险、范围明确。完成后可使 Mypy 在该文件上零错误，并向 P3/P4 推进。

## 任务上下文
Mypy 检查 `app/api/v1/iotda.py` 当前输出：
```
app\api\v1\iotda.py:123: error: Item "None" of "dict[str, Any] | None" has no attribute "get"  [union-attr]
app\api\v1\iotda.py:200: error: Item "None" of "dict[str, Any] | None" has no attribute "get"  [union-attr]
app\api\v1\iotda.py:281: error: Item "None" of "dict[str, Any] | None" has no attribute "get"  [union-attr]
```

所有 3 处错误模式相同：从 IoTDA 回调 JSON payload 中通过 `.get("notify_data")` 获取数据后，返回值被推导为 `dict | None`，然后直接链式调用 `.get("body")`，Mypy 认为可能在 None 上调用 `.get()`。

参考修复模式（来自重构方案文档）：
```python
# 安全方式
notify_data = payload.get("notify_data")
if notify_data is not None:
    body = notify_data.get("body")
else:
    body = None
```

## 已有产出上下文
- P1 完成：Ruff 零警告，测试全部通过
- 当前工作目录 `E:\dev\wheat-tea-iot\pdc\202607022240_server-refactoring`
- Ruff 状态：`All checks passed!`
- 测试状态：37 passed, 38 skipped, 0 failures
