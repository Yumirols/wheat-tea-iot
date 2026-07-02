# 迭代 2 修正指令

## 依据

本指令基于组件B对组件A上一轮产出 `a_v1_diag_v1.md` 的质量审查报告（`b_v1_diag_v1.md`）及其质询确认（`b_v1_challenge_v1.md`，结论：LOCATED）编制。

## 总体要求

对 `a_v1_diag_v1.md` 中**问题2（设备在线状态）**部分进行修正。问题1（ORM DDL）的诊断已被组件B确认为准确、完整、可操作，无需修改。

以下按优先级逐项列出需修正的内容：

---

### 修正项1（严重）：修正问题2根因归因，区分两条独立执行路径

**问题**：原报告将根因归为"设备 `farmeye_guard_ws63` 在自动注册时 `online` 被设置为 `False`"，但 E2E 场景中该设备由 `server\init\02_seed_data.sql:7-8` 预植入：

```sql
VALUES ('farmeye_guard_ws63', 'FarmEye Guard WS63 #1', 'A1:B2:C3:D4:E5:F6', FALSE)
```

Step 2 调用 `ensure_device_exists()` 时设备已存在，代码走 `else` 分支（仅更新 `last_seen`），不触及 `online` 字段。因此"自动注册时设为 False"的表述与 E2E 实际执行路径不一致。

**要求**：修正根因陈述，明确区分两条独立路径：
- **路径A（E2E 场景）**：seed data 预植 `online=FALSE` → `ensure_device_exists()` 未更新 `online` → 命令下发被拒
- **路径B（集成测试场景，自动注册新设备）**：`ensure_device_exists()` 新建设备时硬编码 `online=False`

两条路径各自独立导致同样的 `online=False` 结果，根因分析应覆盖两者。

---

### 修正项2（严重）：扩大修复范围，覆盖 E2E 故障路径

**问题**：原报告"修复者须知"仅指向 `sensor_service.py:78`（新建设备分支），但 E2E 场景下该行不会执行（设备已存在时走 `else` 分支）。即使将第78行改为 `online=True`，对 E2E 场景无影响。

**要求**：
- 修复须知必须明确覆盖 `ensure_device_exists()` 的**两个分支**（新建和已存在）均应设置 `online=True`
- 明确说明是否需要同步修改 `02_seed_data.sql` 中 `online` 的预设值
- 最终推荐的修复方案应确保两条路径均被覆盖

---

### 修正项3（中等）：补充 `02_seed_data.sql` 为 `online=FALSE` 设定点

**问题**：原报告声称"遍历所有代码，`online` 字段仅在三处被写入"，遗漏了 `server\init\02_seed_data.sql:7-8`。该文件是唯一在数据行层面预置 `farmeye_guard_ws63` 设备 `online=FALSE` 的地方，正是 E2E 故障的直接数据来源。

**要求**：补充 `02_seed_data.sql` 为第4处 `online=FALSE` 设定点，并在根因分析中基于此修正对 E2E 执行路径的判断。

---

### 修正项4（轻微）：精确措辞，区分"数据写入"与"定义层默认值"

**问题**：原报告将 `control.py:44`（Python 侧 ORM 默认值）和 `01_create_tables.sql:88`（DDL 列默认约束）列为"写入"，实际的数据行级 `online` 写入只有 `sensor_service.py:78` 和 `02_seed_data.sql:8` 两处。措辞不精确。

**要求**：将"写入"改为"设定"，或区分"数据层写入"与"定义层默认值"。

---

### 修正项5（轻微）：明确修复方案推荐导向

**问题**：原报告列出方案A/B/C但未给出推荐选择。

**要求**：
- 明确方案C不应入选（E2E 测试无额外的设备上线步骤 API，seed data 已预植离线，方案C需要新增 API 端点 + 修改测试脚本）
- 基于诊断证据，明确推荐方案或其变体，并说明推荐理由
- 补充方案B 的代码修改位置建议（`ensure_device_exists()` 两分支均需设置 `online=True`，可在哪个函数/阶段实现 `online=True` 的更新）

---

## 输出要求

基于以上修正项，重新生成 `a_v2_diag_v2.md`，包含完整的问题1和问题2诊断内容。问题1部分可复用 `a_v1_diag_v1.md` 原文（无需修改），问题2部分按上述修正项重写。
