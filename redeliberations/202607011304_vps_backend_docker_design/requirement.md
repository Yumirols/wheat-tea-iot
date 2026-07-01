# VPS 后端开发与容器化详细设计和测试方案

## 背景

基于系统架构文档 (E:\dev\wheat-tea-iot\docs\system_architecture.md) 中定义的 FarmEye Guard v1.0 系统，设计一份面向 VPS 部署的"本地后端开发与容器化详细设计和测试方案"。

## VPS 规格

- **服务商**：Digital Ocean
- **地域**：新加坡
- **操作系统**：Ubuntu 25.04
- **配置**：Intel / 1 vCPU / 1 GB RAM / 35 GB Disk

## 任务要求

请根据系统架构文档（docs/system_architecture.md）中定义的以下内容，设计详细方案：

### 1. Python API 后端 (FastAPI)

架构文档 §2.4、§4、§5.1 定义了 Python API 后台的完整接口规范和工程结构。需包含：

- 本地开发环境配置方案（Python 虚拟环境、依赖管理、环境变量模板）
- Dockerfile 设计（基于 Ubuntu 25.04 VPS 架构，多阶段构建）
- docker-compose.yml 设计（API + KingbaseES 编排）
- 生产/开发配置分离策略
- 健康检查配置

### 2. 金仓数据库 (KingbaseES)

架构文档 §2.5 定义了数据库表结构和部署环境。需包含：

- KingbaseES Docker 镜像适配方案（针对 VPS 的 1GB RAM 约束）
- 数据库初始化脚本（建表 DDL 和种子数据）
- 数据持久化与备份策略
- 数据保留与清理策略（30 天 sensor_snapshot、90 天 control_logs）

### 3. VPS 部署方案

需包含：

- VPS 初始化配置（安全组、防火墙配置 Docker 安装）
- Docker Compose 部署流程
- Nginx 反向代理配置（可选，架构文档 §5.1 提及）
- 日志收集与管理方案
- 容器资源限制配置（适配 1GB RAM）
- 启动与停止脚本

### 4. 测试方案

需包含：

- 单元测试框架与组织（基于架构文档 §5.1 的 tests/ 目录结构）
- API 接口测试（含各个接口的测试用例如 manual/integration）
- 数据库集成测试（DDL 验证、CRUD 操作）
- Docker 容器测试（启动、健康检查、容器间通信）
- 端到端测试（模拟 IoTDA Webhook → API → DB 全链路）
- 性能与压力测试方案（适配 1 vCPU / 1GB RAM 场景）

### 5. 开发工作流

需包含：

- 本地开发 → Docker 测试 → VPS 部署的 CI 流程
- 热重载开发配置
- 环境变量管理（dev/prod 分离）
- 数据迁移策略

## 产出物要求

- 方案应包含完整的配置文件示例（Dockerfile、docker-compose.yml、nginx.conf、环境变量模板等）
- 测试方案应列出具体的测试用例名称和预期结果
- 所有配置和脚本应能直接在 Digital Ocean 的 Ubuntu 25.04 VPS 上运行
- 考虑 1GB RAM 资源约束下的性能优化建议
