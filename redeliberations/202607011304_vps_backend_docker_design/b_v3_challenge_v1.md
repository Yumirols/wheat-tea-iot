CHALLENGED:E:\dev\wheat-tea-iot\redeliberations\202607011304_vps_backend_docker_design\b_v3_challenge_v1.md

## 质询项

### CH1 — N1 缺乏对 Docker Compose v2 profile 行为的关键证据支撑

**所在位置**：报告 §二、N1（一般），关于 §4.4.2 Docker 测试用例 #1 的 `--profile production` 遗漏判断。

**质询理由**：

审查报告断言「不带 `--profile production` 参数的 `docker compose up -d api` 命令在当前 Docker Compose v2 语义下**不会启动**具有 `production` profile 的 `api` 服务」，并将整组 Docker 测试的级联失效建立在这一断言之上。然而，该断言**缺少以下任一形式的支撑证据**：

1. **未引用 Docker Compose 官方文档或规范版本号**：报告仅以「当前 Docker Compose v2 语义」概括，未给出具体版本号（如 v2.23.0+ / v2.0–v2.22.x）、也未指向 Docker Compose specification 或上游 changelog 中关于 `profiles` 与显式命名服务交互行为的条款。Docker Compose v2 在此行为上存在版本间的差异——部分版本中显式指定服务名会绕过 profile 过滤，部分版本则不会——不指定版本的断言无法被验证。

2. **未提供实测结果**：报告未提及在实际环境中搭建测试用例验证该行为，也未说明测试通过的 Docker Compose 版本号。

3. **未检查被审查文档中的版本约束**：设计文档 `a_v3_copy_from_v2.md` 中可能已指定 Docker Compose 版本或运行环境。报告未说明是否确认过该版本信息。

**影响**：若该断言在目标运行环境下不成立，则 N1 为**假阳性**，其后续的「5 个测试用例级联失败」分析及整组修复建议均失去基础。在此情况下，Docker 测试部分的主要新增质量问题消失，审查报告的覆盖完整性将受影响。

**判定依据**：违反质量质询「证据充分性」维度的「质量问题的判定是否有充分证据支撑」「关键判断是否经过实际内容确认」两项要求。

---

### CH2 — N2 的「修复建议」可行性与文档上下文未验证

**所在位置**：报告 §二、N2（轻微），关于 §5.4.5 env.py 使用 `set_main_option` 的修复建议。

**质询理由**：

报告建议将 `config.set_main_option("sqlalchemy.url", database_url)` 替换为 `config.set_section_option("alembic", "sqlalchemy.url", database_url)`。但报告**未验证被审查文档中 `env.py` 的 Alembic 配置上下文**：

1. 若 `env.py` 中的 `config` 对象并非标准 `alembic.context` 中获取，而是通过自定义方式构造的，则 `set_section_option` 的调用方式可能需要调整。
2. 报告未说明是否已确认 `alembic` section 在被审查文档中确实存在且命名正确。

该问题虽属轻微，但修复建议的可靠性仍依赖上下文确认。此情况削弱了建议的「可行」判定。

**判定依据**：违反质量质询「逻辑完整性」维度的「改进建议是否与问题一致且可行」。

---

## 总结

审查报告在**前轮 6 项问题修复验证**方面证据充分、引用明确，结论可信。但**2 项新增质量问题**均存在不同程度的证据支撑不足：

| 问题 | 原定严重度 | 质询重点 | 质询结论 |
|------|-----------|---------|---------|
| N1 (profile 遗漏) | M2 | Docker Compose v2 行为断言缺少版本引用/实测验证 | 证据不足，判定存疑 |
| N2 (deprecated API) | L1 | 修复建议未验证被审查文档中的上下文 | 建议可靠性待确认 |

其中 N1 的问题性质更为关键——若该断言不成立，则审查报告的主要新增发现将被推翻。建议在下一轮迭代中补充 Docker Compose 版本约束说明或实测验证，以确认 N1 是否为真实问题。
