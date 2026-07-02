# 执行报告（v3）

## 概述
启动完整 Docker 容器组并运行端到端联调脚本（integration_run.py）。5/7 步通过，2 步因设备 offline 状态失败。

## 产出清单
| 操作 | 文件路径 | 说明 |
|------|---------|------|
| 启动容器 | `docker compose --profile dev up -d` | 完整 Docker 组已运行 |
| 新建 | `pdc/202607021829_run-tests-and-report/e2e_output.txt` | 脚本完整输出 |

## 执行过程
1. 停止并重启 Docker 容器组（解决 8000 端口冲突）
2. 执行 `python tests/integration_run.py`
3. 输出保存到 e2e_output.txt

## 测试结果

| 步骤 | 用例 | 结果 | 说明 |
|------|------|------|------|
| 1/7 | 健康检查 GET /api/v1/health | PASS | status=healthy, db_connected=True |
| 2/7 | 上报环境数据 POST properties/report | PASS | snapshot_id=11 |
| 3/7 | 校验最新快照 GET sensor/latest | PASS | temperature=28.5, humidity=75.0 |
| 4/7 | 上报 AI 重度病害 POST ai/report | PASS | disease_record_id=3 |
| 5/7 | 查询防治建议 GET advisory | PASS | auto_action=spray ON, risk_level=low |
| 6/7 | 模拟下发控制指令 POST command/send | FAIL | status=offline, code=1003 |
| 7/7 | 控制状态闭环校验 | FAIL | 步骤 6 失败导致跳过 |

**汇总**：5 PASS / 2 FAIL

## 失败分析
步骤 6 返回 `status=offline`，原因：
- 设备表中无 `online=True` 的设备记录（设备 `farmeye_guard_ws63` 未注册或未在线）
- 集成测试已在上一步自动注册设备，但注册时 `online` 默认为 `false`
- 需要手动在设备表中设置 `online=True`，或修改脚本使设备前置在线

## 备注
- 与集成测试（R2）不同，E2E 测试中前 5 步成功。因为 Docker 容器中的 PostgreSQL 使用的是已有数据库 schema（来自 init SQL 脚本而非 ORM `create_all()`），规避了 `server_default` 语法问题。
- 退出码：1

## 偏差说明
未修改任何源代码文件。仅复制 .env.prod.example 到 .env.prod（必需的环境配置，不影响测试逻辑）。
