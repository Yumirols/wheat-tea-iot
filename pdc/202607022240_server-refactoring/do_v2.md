# 执行报告（v2）

## 概述
对 `app/api/v1/iotda.py` 中 3 处 Mypy `union-attr` 错误进行 None 安全修复。在 `handle_properties_report`、`handle_ai_report`、`handle_command_response` 三个端点中，`_parse_notify_data()` 返回的 `header` 变量类型为 `dict[str, Any] | None`，直接调用 `.get()` 时 Mypy 报错。使用 `(header or {}).get("device_id")` 默认值空字典模式修复，不改变业务逻辑。

## 产出清单
| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 修改 | `E:\dev\wheat-tea-iot\server\app\api\v1\iotda.py` | 将 L123、L200、L281 三处的 `header.get("device_id")` 改为 `(header or {}).get("device_id")` |

## 执行过程
1. **阅读任务文件**：确认 P2 目标是修复 iotda.py 中 3 处 mypy union-attr 错误。
2. **确认错误位置**：运行 `python -m mypy app/api/v1/iotda.py`，确认三处错误均在 `header.get("device_id")` 上，`header` 因函数返回值类型 `dict[str, Any] | None` 被 Mypy 标记。
3. **选择修复方式**：采用默认值空字典模式 `(header or {}).get(...)`，原因：
   - `_parse_notify_data` 在 `notify_data` 非 None 时，`header` 永远是 `dict[str, Any]`（函数内部由 `notify_data.get("header", {})` 赋值），None 仅当初始 `payload.get("notify_data")` 为 None 时返回。代码已有 `if not notify_data: raise` 守卫，理论上 `header` 不会为 None。
   - 守卫判断方式（`if header is None: raise`）等价但增加了一个不会被执行到的分支，引入额外复杂度。
   - 默认值空字典方式，若 `header` 为 None 时 `.get("device_id")` 返回 None，会被既有 `if not device_id:` 守卫捕获并抛出 422，行为一致。
4. **执行修改**：使用 `replace_all` 一次修改全部 3 处。
5. **验证**：
   - `python -m mypy app/api/v1/iotda.py` — 该文件零错误（仅剩 `sensor_service.py` 2 个 P3 范围的错误）。
   - `pytest server/tests/ -x` — 37 passed, 38 skipped, 0 failures。

## 偏差说明
无
