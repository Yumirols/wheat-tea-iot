# 执行报告（v1）

## 概述

完成全量测试验证并生成测试报告。实际执行了单元测试（37/37 通过）、集成测试（38/38 通过）和端到端联调（7/7 通过），基于真实运行结果汇总为测试报告。

## 产出清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 修改 | E:\dev\wheat-tea-iot\pdc\202607021200_full-testing\test_report.md | 全量测试报告，基于实际运行数据 |
| 修改 | E:\dev\wheat-tea-iot\pdc\202607021200_full-testing\do_v1.md | 本执行报告 |

## 执行过程

### 1. 环境确认

- 确认 Docker PostgreSQL 16 运行正常（farmeye-db, Up 3 hours healthy）
- 确认 Docker API 容器运行正常（farmeye-api-dev, Up 3 hours）
- 确认 Python 3.11.4 及所有依赖安装完成
- 确认测试数据库 farmeye_test 可用

### 2. 实际测试执行（禁止凭假设产出）

**单元测试**：`python -m pytest tests/ -v --tb=short`
- 37 passed, 38 skipped, 5 warnings
- 执行时间 0.25s
- 所有 8 个单元测试文件全部通过

**集成测试**：`python -m pytest tests/integration/ -v --tb=short --run-integration`
- 38 passed, 6 warnings（多出 1 个 SAWarning: transaction already deassociated from connection）
- 执行时间 4.83s
- 所有 3 个集成测试文件全部通过

**端到端联调**：`python tests/integration_run.py`
- 7/7 全部通过，退出码 0
- 验证 Webhook -> 快照 -> AI -> Advisory -> Command -> 闭环全链路

### 3. 报告生成

基于实际运行结果生成测试报告，包含：
- 测试环境信息（Python/OS/依赖/Docker）
- 各模块通过统计
- 逐文件/逐类测试结果明细
- 已知警告汇总
- 已修复问题清单
- 改进建议

### 4. 关键发现

- 集成测试在本次执行中产生了 1 个 SAWarning（`transaction already deassociated from connection`），上一轮报告中未记录，已补充
- 操作系统实际为 Windows 11 24H2（build 26100），但 `platform.system()` 返回 "Windows 10" 是 Python 的兼容性行为，报告中已注明
- `avg_light` 列已正确从 `Numeric(5,1)` 改为 `Integer`（代码中确认）

## 偏差说明

无
