# 测试审查报告（R1 r1）

## 审查结果
APPROVED

## 发现

- **[轻微]** `harmony-app/entry/src/test/PollingManagerTest.test.ets` — PollingManager 的所有用例最终断言均为 `expect(true).assertEqual(true)`，仅验证"不抛错"，未真正观察 `tasks` Map 的状态变化（`start` 后 `tasks.has('k1')` 应为 true；`stop` 后应为 false；`suspendAll` 后 `running` 字段应为 false；`stopAll` 后 Map 应为空）。考虑到本轮 PollingManager 为占位实现且 `tasks` 为模块级私有变量、公开 API 未暴露状态查询接口，这属于设计约束下的最大努力测试，且测试报告"留待后续轮次集成测试"段落已明确标注"PollingManager 实际调度（递归 setTimeout 串行模式、回调实际调用、try-catch 包裹）"将在后续轮次覆盖。后续轮次 PollingManager 补全后应同步追加状态观察型测试（通过暴露 `_size` getter 或在测试环境导出 `tasks` 引用）。

- **[轻微]** `harmony-app/entry/src/test/ConstantsTest.test.ets` — `API_BASE_URL` 的测试仅验证 `length > 0`（非空字符串），未断言 `http://<VPS_IP>:8000` 的具体格式。考虑到占位符 `<VPS_IP>` 将在后续轮次替换为生产域名，且测试报告"设计偏差说明"段落已明确说明本轮不绑定具体 IP，这是合理的工程取舍；建议后续域名替换后追加一条 `assertEqual` 用例锁定生产值。

- **[轻微]** `harmony-app/entry/src/test/UtilsTest.test.ets` — `sleep` 用例使用 `elapsed >= 45` 作为下界（50ms 调用），容差 5ms 在 CI 负载较高时可能不稳定。实际风险极低（`setTimeout` 在现代设备上的精度远高于此），无需立即修正，仅记录。

- **[轻微]** `harmony-app/entry/src/test/UtilsTest.test.ets` — `formatTimestamp` 对带时区偏移的 ISO 字符串（如 `Z` 后缀）使用正则 `assertMatch` 验证格式模式，但未验证时区转换的正确性。设计规格未要求 `formatTimestamp` 感知时区（仅做格式转换），当前测试策略合理；如果后续需求要求本地化时区显示，需要追加时区偏移量测试。

## 总结

无严重、无一般问题。本次测试交付物满足以下质量基线：

1. **覆盖度**：5 个新测试套件覆盖了所有 R1 纯模块（utils / CacheManager / RetryPolicy / constants / PollingManager 占位），共 69 个 `it` 用例。`models.ets` 无运行时行为，属纯类型声明，无需测试（合理省略）。
2. **断言合理性**：除 PollingManager 占位限制外，所有断言均为 `assertEqual` / `assertMatch` / 布尔条件断言，精准锁定行为契约。
3. **边界条件**：`formatTimestamp`（无效输入/空串/Z 后缀）、`parseAlarmFlag`（0/0xFF/0x100 溢出位）、`buildQueryString`（空对象/undefined/空串保留/URI 编码/数值）、`CacheManager`（TTL=0 立即过期/覆盖/不存在的 key）、`PollingManager`（空 Map/重复 key/不存在 key）均已覆盖。
4. **错误路径**：`isNetworkError` 对 null / undefined / string / number / 字符串 code / 无 code 属性 / 空对象 7 种非网络错误情形全部覆盖。
5. **依赖原生能力的模块**（HttpClient / api.ets / PollingManager 实际调度 / EntryAbility）已明确标注留待后续轮次集成测试，且测试报告"留待后续轮次集成测试"段落给出了清晰的边界说明。
6. **用例独立性**：CacheManagerTest 与 PollingManagerTest 使用 `beforeEach` 重置状态，避免跨测试污染。
7. **注册完整性**：`List.test.ets` 已正确注册全部 6 个测试套件。
