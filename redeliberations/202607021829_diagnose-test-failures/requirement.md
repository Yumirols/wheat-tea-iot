# 问题定位需求

## 问题描述

定位 FarmEye Guard 项目中以下两类测试失败的根因，要求给出具体的代码位置和证据链：

### 问题1：数据库集成测试 38 ERROR at setup

执行 `pytest tests/integration/ --run-integration -v` 后，38 个测试用例全部在 session-scoped fixture `test_engine` 的 `Base.metadata.create_all(bind=engine)` 阶段报错，未进入任何测试逻辑。

测试报告初步分析认为：SQLAlchemy ORM 模型中使用 `server_default="CURRENT_TIMESTAMP"` 字符串作为默认值，导致 PostgreSQL 报 `InvalidDatetimeFormat` 错误。

需要验证：
- 哪些模型文件/字段存在此问题
- `server_default` 的字符串值被 SQLAlchemy 如何渲染
- 是否所有受影响的位置都被正确识别

### 问题2：端到端联调测试 步骤6-7 FAIL

执行 `python tests/integration_run.py` 后：
- 步骤6 `POST /api/v1/command/send` 返回 `status=offline (code=1003)`
- 步骤7 因步骤6失败跳过

测试报告初步分析认为：设备 `farmeye_guard_ws63` 在步骤2自动注册时 `online` 默认值为 `false`，导致步骤6下发控制指令前检查设备在线状态时拒绝下发。

需要验证：
- 设备注册时 `online` 字段默认值的确认为 `false` 的代码位置
- 控制指令下发前检查设备在线状态的逻辑代码
- 是否存在其他可能影响设备在线状态的因素

## 参考文件

- 测试报告：`E:\dev\wheat-tea-iot\pdc\202607021829_run-tests-and-report\test_report.md`
- 项目根目录：`E:\dev\wheat-tea-iot\server`
- 集成测试输出：`E:\dev\wheat-tea-iot\pdc\202607021829_run-tests-and-report\it_output.txt`
- 端到端测试输出：`E:\dev\wheat-tea-iot\pdc\202607021829_run-tests-and-report\e2e_output.txt`
