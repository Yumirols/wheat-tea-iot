# 迭代指令：第4轮诊断 v4

## 前轮回顾

第3轮诊断报告 `a_v3_diag_v1.md` 已在问题定位准确性和主要修复路径的具体性上达到较高水平。组件B审查报告 `b_v3_diag_v2.md` 确认了所有关键声明的准确性，发现3个可操作性问题（F-01中、F-02低、F-03低）。质询报告 `b_v3_challenge_v2.md` 为自引定位，无新增质询。

第3轮迭代产出的5项改进（路径A/B区分、修复范围扩展、text导入补充、方案-路径映射、test预期纠正）已全部到位。

## 本轮需改进项

### 1. 替代方案补全先决条件说明（对应 F-01）

在方案推荐部分提出替代方案（在 `create_snapshot()` 中、`ensure_device_exists()` 调用之后写入 `online=True`）时，补充说明：`create_snapshot()` 当前第33行未捕获 `ensure_device_exists()` 的返回值，修复者若选择此路径需先将第33行改为 `device = ensure_device_exists(db, device_id, properties.get("mac_addr"))`，再设置 `device.online = True`。

### 2. 将 `ensure_device_exists()` 的 docstring 更新纳入修复范围（对应 F-02）

`ensure_device_exists()` 的 docstring 当前记载 `online=False`（新建设备时），修复方案要求改为 `online=True` 后，docstring 需同步更新。在修复者须知中补充此项。

### 3. 调优 `command_service.py` 在线检查行号精度（对应 F-03）

将 `command_service.py:36-40` 调整为 `command_service.py:38-40`，第36行是设备查询而非在线检查逻辑。

## 输出要求

基于 `a_v3_diag_v1.md` 修正上述3项后，生成 `a_v4_diag_v1.md`。保持原报告的完整结构和已有内容不动，仅修正上述3项。
