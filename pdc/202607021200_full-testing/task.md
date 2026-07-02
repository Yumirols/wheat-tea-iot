# 全量测试任务

完成 E:\dev\wheat-tea-iot\server 的全量测试，包括：

## 1. 单元测试

运行 server/tests/ 下所有 test_*.py 文件：
- test_health.py
- test_iotda_webhook.py
- test_sensor.py
- test_disease.py
- test_command.py
- test_advisory.py
- test_image.py
- test_device.py

确保所有单测通过。

## 2. 集成测试

运行 server/tests/integration/ 下所有测试：
- test_db_ddl.py — DDL 与索引验证
- test_db_crud.py — 基本 CRUD 与数据保留清理验证
- test_api_integration.py — API 集成测试

需要数据库连接，使用 --run-integration 选项。

## 3. 端到端联调

运行 server/tests/integration_run.py 端到端集成联调脚本。

## 4. 测试报告

产出测试报告，包含：
- 测试环境信息（Python版本、操作系统、依赖版本）
- 各测试模块的通过/失败统计
- 失败用例的详细分析
- 数据库集成测试结果
- 端到端联调结果

## 参考文档

E:\dev\wheat-tea-iot\docs\2_vps-deployment.md（第4章测试方案）

## 注意事项

- 如果数据库未运行，需要先启动 Docker 数据库容器或使用 SQLite 内存数据库进行测试
- 测试在 Windows 环境下运行
- 工作目录：E:\dev\wheat-tea-iot\server
