# 任务计划

任务描述：修复 FarmEye Guard 测试失败问题（ORM DDL 生成 Bug + 设备注册业务逻辑缺陷）
工作目录：E:\dev\wheat-tea-iot\pdc\202607022049_fix-test-failures

---

## R1 NEW 修复 ORM DDL 生成 Bug [ID: T1]
任务：修改 3 个 ORM 模型文件（sensor.py, disease.py, control.py），将 `server_default="CURRENT_TIMESTAMP"` 替换为 `server_default=text("CURRENT_TIMESTAMP")`，并在对应 import 行追加 `text`。共涉及 3 个文件、10 处 `server_default` 字段定义和 3 处 import 修改。
选择理由：这是数据库集成测试 38 ERROR at setup 的根本原因——SQLAlchemy 将字符串字面量作为 `server_default` 时会在 DDL 中生成带单引号的 `DEFAULT 'CURRENT_TIMESTAMP'`，导致数据库拒绝执行。使用 `text()` 包裹可确保生成正确的 `DEFAULT CURRENT_TIMESTAMP`。模型层的修正是最基础的一步，应先完成。
上下文：
- sensor.py:8 导入追加 `text`；line 21/36/74 三处 `server_default` 需修改
- disease.py:6 导入追加 `text`；line 18/35 两处 `server_default` 需修改
- control.py:8 导入追加 `text`；line 21/29/42/46 四处 `server_default` 需修改

---

## R2 RETRY 修复 ORM DDL 生成 Bug 及设备注册缺陷 [ID: T1]
原因：初审 REJECTED — 范围缺少问题2（设备注册缺陷），`server_default` 计数应为9处而非10处，缺少验证环节
修正方向：
1. **合并问题2**：将 `sensor_service.py` 中 `ensure_device_exists()` 的 online 相关修正纳入本轮，与问题1一并修复
2. **修正计数**：`server_default="CURRENT_TIMESTAMP"` 实际共9处（sensor.py:3 + disease.py:2 + control.py:4），import 修改3处
3. **补充验证**：修改后运行 Python 语法检查和相关测试确认修改正确
选择理由：两个问题均为测试失败根因（问题1导致集成测试38 ERROR，问题2导致E2E 步骤6-7 FAIL），修改量均较小（问题1: 9处 server_default + 3处 import；问题2: 1个文件3处小修改），合并一轮处理可避免碎片化
