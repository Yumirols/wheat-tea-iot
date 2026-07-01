# 质询：b_v1_diag_v2.md

**审查维度**: 证据充分性 / 逻辑完整性 / 覆盖完备性

**待审查报告**: b_v1_diag_v2.md（审查 a_v1_output_v6.md 的质量报告 v2 版）

---

## 一、证据充分性审查

### H1（缺失 .dockerignore）
- 源文档 §1.4 Dockerfile prod stage 使用 `COPY . .`（行 271），§6.1 文件清单无 `.dockerignore`，项目仓库中确无该文件。证据充分。
- **判定**: LOCATED

### H2（psycopg2-binary 生产不推荐）
- 源文档 §1.2.1 requirements.txt 行 104 确实为 `psycopg2-binary~=2.9.0`。v2 版改进建议已补充 `build-essential`、`python3-dev`、`libpq-dev` 三项编译依赖（见 §六 质询响应 行 190-205），修正了 v1 版仅列 `libpq-dev` 的缺陷。证据充分，建议完整可执行。
- **判定**: LOCATED

### H3（Alembic/Init SQL 调和缺口）
- 源文档 §2.2.1 init DDL 通过 `/docker-entrypoint-initdb.d/` 自动执行（docker-compose.yml 行 344），§5.4 entrypoint.sh 行 2131 调用 `alembic upgrade head`。两套机制并存且无调和策略说明。证据充分。
- **判定**: LOCATED

### M1（异步清理函数阻塞事件循环）
- 源文档 §2.4 行 790 定义 `async def cleanup_expired_data()`，但内部使用同步 `SessionLocal()`（行 797）、`db.execute()`（行 807）、`db.commit()`（行 842），无任何 `await` 调用。证据充分。
- **判定**: LOCATED

### M2（测试用例 #40 自相矛盾）
- 源文档 §4.2.6 行 1711 预期结果为 `"200，status=degraded, HTTP 503"`，200 与 503 确实矛盾。证据直接明确。
- **判定**: LOCATED

### M3（Nginx 缺少 SSL/TLS）
- 源文档 §1.5.2 docker-compose.prod.yml 行 452 映射 `"443:443"`，§3.1.1 UFW 行 1016 开放 443/tcp，但 §3.3.1 nginx 配置行 1158 仅 `listen 80`。证据充分。
- **判定**: LOCATED

### M4（--compatibility 依赖风险）
- 源文档 §3.2.2 行 1113、§3.6.1 行 1324、§5.1.3 行 1916 均使用 `--compatibility`。§3.5 含说明但无验证步骤。证据充分。
- **判定**: LOCATED

### L1-L4（低优问题）
- L1: §2.1.2 内存表 "OS + 缓存" 行 564 未计入 dockerd 开销。证据充分。
- L2: §1.3.2 行 202-204 定义 HOST/PORT/WORKERS，但 §1.4 Dockerfile CMD 行 282 硬编码。证据充分。
- L3: §4.3.1 行 1730 连接串硬编码在文档注释中。证据充分。
- L4: §2.3.2 backup.sh 行 748 直接 `docker exec` 无容器状态检查。证据充分。
- **判定**: LOCATED（四项均成立）

---

## 二、逻辑完整性审查

1. **内部一致性**: 报告各问题独立，无相互矛盾。改进建议与对应问题的因果关系一致。
2. **建议可行性**: H2 的 v2 修正（三项编译依赖 + 镜像体积说明）已在 §六 质询响应 中完成完整论证，从 v1 的不可执行改进为可执行。其余建议（创建 .dockerignore、alembic stamp head 调和策略、Nginx SSL 配置补充等）均为业界实践，可直接照做。
3. **严重程度分层**: H1-H3 为"高危"、M1-M4 为"中"、L1-L4 为"低"，区分合理。H3 被列为最优先处理事项（"首次 docker compose up 时就会暴露"）的优先级判断正确。
4. **最终结论合理**: "有条件通过 — 必须在修正 H1、H2、H3 三项高危问题后进入编码阶段" 与报告本身的分析一致。

**判定**: 逻辑完整，无矛盾。

---

## 三、覆盖完备性审查

### 3.1 任务要求审查维度覆盖

任务描述要求的五个维度：

| 任务要求 | 报告覆盖章节 | 评价 |
|---------|-----------|------|
| 1. Python API (FastAPI) 容器化 | H1（Dockerfile 安全性）、H2（依赖正确性）、M1（异步正确性）、L2（配置一致性） | 覆盖 |
| 2. 数据库适配与初始化 | H3（Schema 调和策略）、M1（数据清理）、L4（备份健壮性） | 覆盖 |
| 3. VPS 部署方案 | M3（HTTPS 缺失）、M4（--compatibility 风险）、L1（内存预算） | 覆盖 |
| 4. 测试方案 | M2（测试用例矛盾）、L3（测试配置硬编码） | 覆盖 |
| 5. 开发工作流 | H3（映射部署流程）、M4（映射验证步骤） | 覆盖 |

无遗漏维度。

### 3.2 额外可能质量问题检查

在审查过程逐项核对源文档后，未发现审查报告遗漏的重大质量问题：

- **KingbaseES 切换方案**: 虽然设计文档以 PostgreSQL 为主线，但 §2.5 提供了完整切换方案和决策理由。审查报告未将其列为问题，判断合理。
- **entrypoint.sh 无重试逻辑**: 属于 H3 调和策略的子问题，报告中 H3 第 3 条建议已覆盖。
- **Dockerfile CMD 中 `--limit-max-requests 10000`**: 单 worker 场景下达到上限会重启，但作为 v1.0 初始版本此参数设定可接受，未列为问题判断合理。
- **conftest.py 占位 fixture**: 设计文档的预期模式，非质量问题。

**判定**: 覆盖完备，无遗漏。

---

## 四、结论

经对源设计文档 `a_v1_output_v6.md` 逐条证据核实，并对报告各章节进行逻辑性和覆盖完整性检查：

- **证据充分性**: 全部 11 项问题均有源文档的直接行级引用，证据确凿。
- **逻辑完整性**: 内部无矛盾，改进建议可行，严重程度分层合理。
- **覆盖完备性**: 任务要求的五个维度均已覆盖，未发现遗漏的重大质量问题。
- **关键修正确认**: H2 的编译依赖缺项已在 v2 版 §六 质询响应 中完成修正，v2 建议（`build-essential` + `python3-dev` + `libpq-dev`）完整可执行。

**LOCATED**: b_v1_diag_v2.md 中全部质量问题已被准确识别，证据充分，逻辑自洽，建议可执行。

LOCATED:E:\dev\wheat-tea-iot\redeliberations\202607011304_vps_backend_docker_design\b_v1_challenge_v2.md
