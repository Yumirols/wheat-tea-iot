# 迭代 3 指令：修正诊断报告中的可操作性缺口

## 背景

上一轮（迭代 2）组件 B 质量审查报告（`b_v2_diag_v1.md`）对诊断报告 `a_v2_diag_v1.md` 进行了可操作性评估，发现 **3 项问题**（F1-F3）。组件 B 质询报告（`b_v2_challenge_v1.md`）确认全部 3 项问题证据充分、判断准确。

## 需要修正的问题

### F1 [事实错误] `test_online_default_false` 测试预期方向错误

**位置**：`a_v2_diag_v1.md` 第 250 行的验收建议

**问题**：原文写"该测试预期 `online` 为 `True`"，但实际该测试（`server\tests\integration\test_db_crud.py:236-242`）的断言是 `assert device.online is False`，测试验证的是 Python 模型层面的 `default=False`，与 `ensure_device_exists` 的业务逻辑无关。

**修正要求**：
1. 纠正预期方向描述，改为"该测试验证 Python 模型的 `default=False`，与 `ensure_device_exists` 业务逻辑独立"
2. 修复后该测试仍应通过（`default=False` 保持不变）
3. 建议新增一个集成测试，验证在 `ensure_device_exists` 调用后设备 `online=True`

### F2 [可操作性缺口] 问题1 修复指令缺少 `text` 导入说明

**位置**：`a_v2_diag_v1.md` 第 207 行的修复者须知段落

**问题**：原文给出了 9 处 `server_default="CURRENT_TIMESTAMP"` 改为 `server_default=text("CURRENT_TIMESTAMP")` 的修改说明，但三个模型文件（`sensor.py`、`disease.py`、`control.py`）的 `from sqlalchemy import ...` 行均未导入 `text`。仅替换字段定义而不添加 import 会导致 `NameError: name 'text' is not defined`。

**修正要求**：
1. 在修复说明中增加导入 `text` 的步骤
2. 明确说明在每个模型文件的 `from sqlalchemy import ...` 行追加 `text`

### F3 [可操作性缺口] 路径A/路径B 与方案A/B/C 命名体系缺少映射

**位置**：`a_v2_diag_v1.md` 第 231-235 行的方案推荐段落

**问题**：故障分析部分使用"路径A/路径B"（故障路径分类），方案推荐部分使用"方案A/方案B/方案C"（方案编号），两套编号切换时无显式映射关系。快速阅读时可能混淆。

**修正要求**：
1. 在方案讨论开头建立两套编号的映射关系
2. 例如明确标注：方案A（仅修 if 分支）、方案B（修两分支）、方案C（新增上线 API）

## 产出要求

基于 `a_v2_diag_v1.md` 生成修正后的 V3 版本，需满足：

1. 保留 V2 中所有正确的核心诊断结论（问题1：ORM `server_default` 语法缺陷；问题2：设备在线状态检查逻辑缺陷 — 两条路径分析）
2. 修复上述 F1、F2、F3 三项问题
3. 修复后整体可操作性达到 B+ 或以上
4. 写入文件：`{workdir}/a_v3_diag_v1.md`
