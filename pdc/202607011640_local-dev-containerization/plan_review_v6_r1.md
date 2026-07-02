# 计划审查报告（v6 r1）

## 审查结果
APPROVED

## 发现

### **[轻微] 1. send_command 接口签名未精确描述**

计划中和任务文件中调用 `iotda_client.send_command(device_id, command)` 时仅传递两个位置参数，但 `iotda_client.send_command` 的实际签名为 `send_command(device_id: str, command: str, paras: dict[str, Any] | None = None)`，包含第三个可选参数 `paras`。虽然 `paras` 有默认值 None，不传入不会影响功能，但计划层对依赖接口的描述不够精确。建议在计划中注明该参数的存在与用途，以便后续 `paras` 传递控制参数（如命令参数）时不影响实现。

### **[轻微] 2. 设备查询的边界情况处理未约定**

`command_service.create_command` 中从 Device 模型按 `device_id` 查询设备记录后检查 `online` 状态。当设备记录不存在时（查询返回 None），直接访问 `.online` 会触发 AttributeError。该场景可通过 `if not device or not device.online` 合并处理。此外，当 IoTDA 客户端 `send_command()` 调用抛出异常时（如网络不可达），事务回滚可能导致控制日志丢失。建议在计划中补充这两类边界场景的约定处理方式。

### **[轻微] 3. 计划/R5 与任务文件/v6 的版本号不一致**

`plan.md` 中 T6 标记为 `R5 NEW`，但对应任务文件为 `task_v6.md`，版本号存在偏移。虽不影响任务内容正确性，但建议统一编号以避免后续轮次的混淆。

## 修改要求
无需修改，以上均为轻微改进建议，不影响计划的正确性和可行性。
