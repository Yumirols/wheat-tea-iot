# 执行报告（v2）

## 概述
启动 PostgreSQL 容器并执行集成测试。所有 38 个测试均在 `test_engine` fixture setup 阶段 ERROR，根因是 ORM 模型的 `server_default="CURRENT_TIMESTAMP"` 语法错误。

## 产出清单
| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 启动容器 | `docker compose --profile dev up -d db` | farmeye-db 已运行 |
| 新建 | `pdc/202607021829_run-tests-and-report/it_output.txt` | pytest 完整输出 |

## 执行过程
1. 启动 PostgreSQL 容器（docker compose --profile dev up -d db），容器已运行且 healthcheck 通过
2. 执行集成测试：`pytest tests/integration/ --run-integration -v`
3. 所有 38 个测试均在 session 级 fixture `test_engine` 的 `Base.metadata.create_all(bind=engine)` 阶段 ERROR

## 测试结果
- 总计：38 条
- 通过：0
- 错误：38（全部 ERROR at setup）
- 失败：0
- 耗时：0.53s

## 根因分析
全部 38 个测试以同一错误失败：
```
psycopg2.errors.InvalidDatetimeFormat: invalid input syntax for type timestamp: "CURRENT_TIMESTAMP"
LINE 6:  timestamp TIMESTAMP WITHOUT TIME ZONE DEFAULT 'CURRENT_TIMESTAMP' NOT NULL,
```

**原因**：SQLAlchemy ORM 模型使用 `server_default="CURRENT_TIMESTAMP"`（字符串），导致 DDL 生成 `DEFAULT 'CURRENT_TIMESTAMP'`（带引号的字符串），而 PostgreSQL 期望的是函数调用 `DEFAULT CURRENT_TIMESTAMP`（无引号）。

**影响范围**：9 处 `server_default`，分布在 `sensor.py`、`disease.py`、`control.py` 三个模型文件，涵盖 `timestamp`、`created_at`、`registered_at` 列。

**修正方案**：将 `server_default="CURRENT_TIMESTAMP"` 替换为 `server_default=text("CURRENT_TIMESTAMP")`（需添加 `from sqlalchemy import text` 导入）。

## 偏差说明
源代码存在 bug（`server_default` 字符串语法），导致集成测试无法通过。按约束不修改源代码，仅记录问题。
