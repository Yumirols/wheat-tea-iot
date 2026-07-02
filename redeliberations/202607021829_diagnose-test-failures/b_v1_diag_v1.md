# 质量审查报告：问题诊断报告可操作性审查

审查对象：`a_v1_diag_v1.md`
审查模式：diagnosis — 问题诊断报告可操作性评估
审查日期：2026-07-02

---

## 总体评估

诊断报告结构完整，问题1（ORM DDL 语法）的诊断准确、证据充分、修复者可操作；问题2（设备在线状态）的诊断在根因归因和修复范围上存在事实偏差，直接影响修复者的行动有效性。

---

## 发现 1（严重）：问题2 根因归因偏离实际执行路径

**位置**：问题2 — "根因" 小节，第100-101行
**严重程度**：严重
**问题描述**：报告将问题2的根因归为"设备 `farmeye_guard_ws63` 在自动注册时 `online` 被设置为 `False`"，指向 `sensor_service.py` 第78行的 `ensure_device_exists()` 新建设备路径。但在 E2E 测试的实际执行中，设备 `farmeye_guard_ws63` 并非由自动注册创建，而是在 Docker 启动时由 `02_seed_data.sql`（第7-8行）预植入：

```sql
INSERT INTO devices (device_id, device_name, mac_addr, online)
VALUES ('farmeye_guard_ws63', 'FarmEye Guard WS63 #1', 'A1:B2:C3:D4:E5:F6', FALSE)
ON CONFLICT (device_id) DO NOTHING;
```

Step 2 的 `ensure_device_exists()` 调用时，设备已存在于数据库中（seed data 写入），代码走 `else` 分支（第85-88行），仅更新 `last_seen`，不触及 `online`。因此 "自动注册时设为 False" 的表述与 E2E 实际执行路径不一致。

**改进建议**：
- 修正根因陈述，区分两条独立路径：
  - 路径A（E2E 场景）：seed data 预植 `online=FALSE` → `ensure_device_exists()` 未更新 `online` → 命令下发被拒
  - 路径B（集成测试场景，自动注册新设备）：`ensure_device_exists()` 新建设备时硬编码 `online=False`
- 两条路径各自独立导致同样的 `online=False` 结果，根因分析应覆盖两者

---

## 发现 2（严重）：问题2 修复范围过窄，按报告修改无法修复 E2E 故障

**位置**：问题2 — "修复者须知"，第171-178行
**严重程度**：严重
**问题描述**：修复须知中 "改哪里" 仅指向 `sensor_service.py` 第78行（新建设备时 `online=False`），但该行仅在集成测试场景（设备不存在）时执行。对于 E2E 场景的设备预植路径，即使将第78行改为 `online=True`，`ensure_device_exists()` 的 `else` 分支也仅是更新 `last_seen`，不会改变设备的 `online` 状态。因此，仅修改 `sensor_service.py:78` 无法修复 E2E 测试步骤6的失败。

**改进建议**：
- 修复须知应明确覆盖两条路径：
  - `ensure_device_exists()` 在**两个分支**（新建和已存在）中均应设置 `online=True`
  - 或明确说明是否需要同时修改 `02_seed_data.sql` 中 `online` 的预设值
- 方案A 和方案C 均未解决 seed data 和 `else` 分支的离线状态，需在修复范围中排除这些误导性选项或补充条件

---

## 发现 3（中等）："遍历所有代码，online 字段仅在三处被写入" 遗漏 `02_seed_data.sql`

**位置**：问题2 — 证据链第4项，第127-131行
**严重程度**：中等
**问题描述**：报告声称"遍历所有代码，`online` 字段仅在三处被写入"，列举了 `control.py:44`、`sensor_service.py:78`、`01_create_tables.sql:88`，但遗漏了 `02_seed_data.sql:7-8`。该文件是唯一在**数据行**层面预置 `farmeye_guard_ws63` 设备 `online=FALSE` 的地方，正是 E2E 故障的直接数据来源。

代码搜索确认：
- `server\init\02_seed_data.sql` 第7-8行：`VALUES ('farmeye_guard_ws63', ..., FALSE)`

**改进建议**：
- 补充 `02_seed_data.sql` 为第4处 `online=FALSE` 设定点
- 在根因分析中基于此补充修正对 E2E 执行路径的判断（见发现1）

---

## 发现 4（轻微）：三处"写入"中两处并非数据写入

**位置**：问题2 — 证据链第4项，第127-131行
**严重程度**：轻微
**问题描述**：报告列为"写入"的三个位置中：
- `control.py:44`（`online = Column(Boolean, default=False)`）是 Python 侧 ORM 模型默认值，不是数据写入
- `01_create_tables.sql:88`（`online BOOLEAN DEFAULT FALSE`）是 DDL 列默认约束，不是数据写入

实际的数据行级 `online` 写入只有两处：`sensor_service.py:78` 和 `02_seed_data.sql:8`。报告的措辞将模型定义和 DDL 默认值混同为数据写入，虽未影响诊断正确性，但降低了证据链的精确度。

**改进建议**：将"写入"改为"设定"或区分"数据层写入"和"定义层默认值"，避免混淆。

---

## 发现 5（轻微）：问题2 修复方案缺少推荐导向

**位置**：问题2 — "修复者须知" 方案A/B/C，第174-178行
**严重程度**：轻微
**问题描述**：报告列出三个方案（A：注册时直接设为 True；B：上报数据时更新 True；C：保持离线但增加上线步骤）但没有给出推荐，也未说明选择依据。方案A和方案C 都未解决 `ensure_device_exists()` 对已存在设备不更新 `online` 的问题（即 E2E 场景的问题2实际故障路径）。方案B 语义最准确（设备上报数据本身证明其在线），但其实现位置（`create_snapshot` 中 vs `ensure_device_exists` 中）未被讨论。缺少推荐导向可能使修复者花时间评估本可排除的方案。

**改进建议**：
- 明确方案C 不应入选（因 E2E 测试无额外的设备上线步骤 API，seed data 已预植离线）
- 基于诊断证据，明确推荐方案B 或其变体，并说明推荐理由
- 补充方案B 的代码修改位置建议（`ensure_device_exists()` 两分支均需设置 `online=True`）

---

## 验证结论

| 维度 | 问题1 (ORM DDL) | 问题2 (设备在线状态) |
|------|-----------------|---------------------|
| 根因判断准确性 | 准确 | 部分失准（见发现1） |
| 证据链完整性 | 完整 | 不完整（见发现3） |
| 修复者可操作性 | 高 — 明确3文件9字段，机械替换 | 中低 — 修复范围过窄，遗漏路径 |
| 修复后效果保证 | 修复后集成测试 setup 应全部通过 | 按报告修改无法修复 E2E 故障 |

**综合建议**：应基于发现1-2对问题2的根因和修复范围进行修正，按修正后的指令执行修复。

---

DIAG_WRITTEN:E:\dev\wheat-tea-iot\redeliberations\202607021829_diagnose-test-failures\b_v1_diag_v1.md
