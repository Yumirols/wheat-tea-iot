# 再审议迭代历史

## 迭代 1

### 问题1：问题2根因归因偏离实际执行路径

- **问题描述**：诊断报告将设备离线根因归为"自动注册时 `online` 被设置为 `False`"，但E2E场景中设备由seed data预植，`ensure_device_exists()` 走else分支仅更新 `last_seen`，不涉及 `online` 设定。
- **所在位置**：`a_v1_diag_v1.md`，问题2 — "根因"小节
- **严重程度**：严重
- **改进建议**：修正根因陈述，区分两条独立路径：路径A（E2E场景：seed data预植 `online=FALSE` → `ensure_device_exists()` 未更新 `online`）和路径B（集成测试场景：自动注册新设备时硬编码 `online=False`）。

### 问题2：问题2修复范围过窄，无法修复E2E故障

- **问题描述**：修复须知仅指向 `sensor_service.py` 第78行（新建设备分支），但E2E场景下该行不会执行。仅修改第78行无法修复E2E测试步骤6的失败。
- **所在位置**：`a_v1_diag_v1.md`，问题2 — "修复者须知"
- **严重程度**：严重
- **改进建议**：修复范围应覆盖 `ensure_device_exists()` 的两个分支（新建和已存在）均设置 `online=True`，并说明是否需要同步修改 `02_seed_data.sql` 中 `online` 的预设值。

### 问题3：遗漏 `02_seed_data.sql` 中 `online=FALSE` 的设定点

- **问题描述**：诊断报告声称"online 字段仅在三处被写入"，遗漏了 `02_seed_data.sql:7-8`。该文件是E2E故障中设备离线状态的直接数据来源。
- **所在位置**：`a_v1_diag_v1.md`，问题2 — 证据链第4项
- **严重程度**：一般
- **改进建议**：补充 `02_seed_data.sql` 为第4处设定点，并基于此修正对E2E执行路径的判断。

## 迭代 2

### 问题1：test_online_default_false 测试预期方向描述错误

- **问题描述**：原始诊断报告验收建议中将 `test_online_default_false` 测试的预期方向错误地描述为 `True`，实际该测试断言 `online` 为 `False`
- **所在位置**：`a_v2_diag_v1.md` 第250行
- **严重程度**：一般
- **改进建议**：纠正为"该测试验证 Python 模型的 `default=False`，与 `ensure_device_exists` 业务逻辑独立。修复后该测试仍应通过（`default=False` 保持不变），但需新增一个集成测试验证在 `ensure_device_exists` 调用后设备 `online=True`"

### 问题2：问题1修复指令遗漏 text 导入说明

- **问题描述**：原始诊断报告问题1的修复指令缺少 `text` 的导入说明，三个模型文件（`sensor.py`, `disease.py`, `control.py`）的 import 语句均未包含 `text`
- **所在位置**：`a_v2_diag_v1.md` 第207行（修复者须知段落）
- **严重程度**：一般
- **改进建议**：在修改说明中增加一行："同时，在三个模型文件的 `from sqlalchemy import ...` 行追加 `text`（例如 `from sqlalchemy import ..., text`）"

### 问题3：故障路径与方案编号体系间缺少映射关系

- **问题描述**：原始诊断报告中"路径A/路径B"（故障路径分类）与"方案A/方案B/方案C"（方案编号）两套编号体系切换时缺少显式映射关系
- **所在位置**：`a_v2_diag_v1.md` 第231-235行（方案推荐段落）
- **严重程度**：轻微
- **改进建议**：在方案讨论开头建立映射关系，例如"方案A（仅修 if 分支）、方案B（修两分支）、方案C（新增上线 API）"

## 迭代 3

### 问题1：替代方案缺少 `ensure_device_exists()` 返回值捕获的先决条件

- **问题描述**：诊断报告中替代方案（在 `create_snapshot()` 第33行 `ensure_device_exists()` 之后写入 `online=True`）未提及 `create_snapshot()` 当前未捕获 `ensure_device_exists()` 的返回值，修复者若选择此替代方案会遇到引用错误。
- **所在位置**：`a_v3_diag_v1.md` 方案推荐部分
- **严重程度**：一般
- **改进建议**：在替代方案中补充先决条件说明：需先将 `create_snapshot()` 第33行改为 `device = ensure_device_exists(db, device_id, properties.get("mac_addr"))`，再设置 `device.online = True`。
